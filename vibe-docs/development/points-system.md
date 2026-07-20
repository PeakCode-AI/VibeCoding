# 积分系统

VibeBase 的积分系统由两张表构成：**`point_accounts`（账户余额）** 与 **`point_transactions`（流水账本）**，所有变动都通过 `database/dao/point.py` 的 `add_points` / `consume_points` 完成，保证余额与流水在同一个事务内一致。本页覆盖表设计、事务性、扣费失败处理、特权账号与前端预检查。

![积分流转示意图](/diagrams/points-flow.svg)

## 两张表的关系

```text
┌─────────────────────────────┐         ┌──────────────────────────────────┐
│  point_accounts             │         │  point_transactions              │
│  （每用户一行，当前状态）     │ 1 ────△ │  （每次变动一行，审计账本）        │
│                             │         │                                  │
│  user_id (unique)           │         │  user_id                         │
│  points        当前余额      │         │  type   recharge/consume/refund/gift│
│  total_earned  累计获得      │         │  amount +增/-减                  │
│  total_consumed 累计消耗     │         │  balance_after 变动后余额         │
│                             │         │  ability / source_type / source_id│
│                             │         │  remark                          │
└─────────────────────────────┘         └──────────────────────────────────┘
```

| 表 | 角色 | 粒度 |
| --- | --- | --- |
| `point_accounts` | **当前余额快照**，每用户一行 | 1 行 / 用户 |
| `point_transactions` | **完整流水账本**，每次变动一行 | N 行 / 用户 |

::: tip 为什么分两张表
- `point_accounts` 让余额查询 O(1)（不用 `SUM(amount)`）
- `point_transactions` 提供完整审计：每次变动留痕、`balance_after` 记录变动后余额，可追溯任意时点状态
- 二者在同一事务内更新，保证一致性
:::

完整字段见 [数据模型](./data-models)。

## add_points：增加积分

`add_points` 用于充值/赠送/退款（金额必须为正），在同一事务内更新账户并写流水：

```python
def add_points(user_id, amount, type_="recharge", *, source_type=None,
               source_id=None, remark=None) -> tuple[PointAccount, PointTransaction]:
    if amount <= 0:
        raise ValueError("add_points amount must be positive")

    with Session(engine) as session:
        account = session.exec(select(PointAccount).where(...)).first()
        if account is None:
            # 首次访问自动建账户
            account = PointAccount(id=str(uuid4()), user_id=user_id, points=0, ...)
            session.add(account); session.flush()

        account.points += amount
        account.total_earned += amount          # 累计获得同步增加
        session.add(account)

        txn = PointTransaction(
            id=str(uuid4()), user_id=user_id, type=type_, amount=amount,
            balance_after=account.points,        # 变动后余额
            source_type=source_type, source_id=source_id, remark=remark,
        )
        session.add(txn)
        session.commit()
        return account, txn
```

调用场景：

| 场景 | type | amount | 来源 |
| --- | --- | --- | --- |
| 充值到账 | `recharge` | +points | `source_type="recharge_order"` |
| 运营赠送 | `gift` | +N | remark 说明 |
| 退款 | `refund` | +N | remark 说明 |

## consume_points：扣减积分

`consume_points` 用于消费（金额必须为正，余额不足抛 `ValueError`），在同一事务内扣减余额、累加消耗、写负数流水：

```python
def consume_points(user_id, amount, *, ability=None, source_type=None,
                   source_id=None, remark=None) -> tuple[PointAccount, PointTransaction]:
    if amount <= 0:
        raise ValueError("consume_points amount must be positive")

    with Session(engine) as session:
        account = session.exec(select(PointAccount).where(...)).first()
        if account is None or account.points < amount:
            raise ValueError("积分余额不足")          # ← 业务层捕获后转 402

        account.points -= amount
        account.total_consumed += amount            # 累计消耗同步增加
        session.add(account)

        txn = PointTransaction(
            id=str(uuid4()), user_id=user_id, type="consume",
            amount=-amount,                          # 负数表示消耗
            balance_after=account.points,
            ability=ability, source_type=source_type,
            source_id=source_id, remark=remark,
        )
        session.add(txn)
        session.commit()
        return account, txn
```

### 事务性设计要点

- **单事务**：账户更新与流水写入在**同一个 `Session` 的 `commit`** 内，要么全成功要么全回滚，永不出现「扣了余额没流水」或「有流水余额没变」
- **balance_after**：流水里记录变动后余额，便于审计/对账/回溯任意时点
- **amount 符号**：增加为正、消耗为负，`SUM(amount)` 即得净变动
- **type 区分**：`recharge`/`consume`/`refund`/`gift`，便于按类型统计

::: warning 不绕过 DAO
所有积分变动必须走 `add_points` / `consume_points`。直接改 `point_accounts.points` 会导致流水缺失、审计断裂。
:::

## 余额不足 → HTTP 402

`consume_points` 余额不足时抛 `ValueError("积分余额不足")`，业务层捕获后转成 HTTP 402：

```python
# api/v1/chat.py
try:
    consume_points(user_id, amount, ability=ability_id,
                   source_type="dialog", source_id=dialog_id, remark="AI 对话消费")
except ValueError:
    raise HTTPException(status_code=402, detail="积分余额不足，请充值后再试")
except Exception as e:
    logger.error(f"扣减积分失败: {e}")
    # 其他异常：降级为不扣费继续，fail open
```

::: danger 402 是积分系统的「标准余额不足码」
前端约定 **HTTP 402 = 积分不足**，会触发充值引导。后端任何积分相关扣减都应复用此模式：`except ValueError: raise HTTPException(402, ...)`。
:::

## 谁会跳过扣费

对话 `/chat` 的扣费有前置条件（详见 [聊天与流式](./chat-streaming#积分扣费规则)）：

```python
if is_llm_configured() and login_user.user_id and login_user.user_id not in ("1", "dev_001"):
    consume_points(...)
```

| 条件 | 是否扣费 |
| --- | --- |
| LLM 已配置 + 普通用户 | 扣费 |
| LLM 未配置（降级） | **不扣费** |
| `user_id == "1"`（白名单管理员） | **不扣费** |
| `user_id == "dev_001"`（dev-login） | **不扣费** |

::: info 为什么要豁免 "1" / "dev_001"
便于开发自测与运营预览——管理员和测试账号不消耗真实积分，避免「测试一轮扣光」的尴尬。生产环境的真实用户都会正常扣费。
:::

## 积分流：从充值到消费

```text
                ┌─────────────────────────┐
                │  充值到账（earn / +）     │
                │  add_points(recharge)   │
                │  source_type=           │
                │   "recharge_order"      │
                └────────────┬────────────┘
                             │
                             ▼
            ┌────────────────────────────────┐
            │   point_accounts.points ↑       │
            │   point_accounts.total_earned ↑ │
            └────────────────────────────────┘
                             │
                             ▼
                ┌─────────────────────────┐
                │  对话消费（consume / -）  │
                │  consume_points()        │
                │  ability="AB001"         │
                │  source_type="dialog"    │
                │  remark="AI 对话消费"     │
                └────────────┬────────────┘
                             │
                             ▼
            ┌────────────────────────────────┐
            │   point_accounts.points ↓        │
            │   point_accounts.total_consumed ↑│
            └────────────────────────────────┘
                             │
                             ▼
                ┌─────────────────────────┐
                │  写入 api_logs            │
                │  （points_cost / ability │
                │   / response_ms / status）│
                └─────────────────────────┘
```

### 充值 → 获得

充值套餐支付成功后，`_credit_order` 调 `add_points`：

```python
# api/v1/recharge.py
def _credit_order(user_id, points, order_id, plan):
    add_points(user_id=user_id, amount=points, type_="recharge",
               source_type="recharge_order", source_id=order_id,
               remark=f"充值套餐: {plan}")
```

### 对话 → 消费

对话开始前调 `consume_points`（如上），并在流结束后写 `api_logs` 供用量分析。

::: tip 流水可追溯
凭 `point_transactions.source_type` + `source_id` 即可定位积分变动的来源记录（`recharge_order.id` 或 `dialog_id`），形成完整证据链。
:::

## 前端预发送检查

为避免发送消息后才被 402 拒绝，前端在发送前估算 token 并调用检查接口：

```ts
// 前端估算：输入长度 × 2 作为预估 token 数
const estimatedTokens = userInput.length * 2
const resp = await checkPointsSufficientAPI(estimatedTokens)
// 后端 /points/check 返回：{ is_sufficient, token_count, remaining_points }
if (!resp.data.is_sufficient) {
  toast.warning('积分不足，请充值后再试')
  return  // 不发起对话请求
}
```

对应后端端点：

```python
# api/v1/points.py
@router.post("/points/check")
async def points_check(points: int = Body(...), user = Depends(...)):
    account = PointAccountDao.get_by_user(user.user_id)
    remaining = account.points if account else 0
    return resp_200({
        "is_sufficient": remaining >= points,
        "token_count": points,
        "remaining_points": int(remaining),
    })
```

::: warning 估算不精确
`输入长度 × 2` 只是粗略预估，不等于真实 token 用量。真实扣费仍以 `abilities.point_price`（默认 5 分/次）为准。预检查的目的是改善体验，不是精确计费。
:::

## 能力定价

每次对话扣的积分由 `abilities` 表的 `point_price` 决定，默认 `AB001` / 5 分：

```python
# api/v1/chat.py
DEFAULT_ABILITY_ID = "AB001"
DEFAULT_ABILITY_PRICE = 5

def _resolve_ability_price(ability_id):
    with Session(engine) as session:
        ability = session.exec(select(Ability).where(Ability.ability_id == ability_id)).first()
        if ability and ability.status == "up":
            return ability.ability_id, int(ability.point_price or 0)
    return DEFAULT_ABILITY_ID, DEFAULT_ABILITY_PRICE   # 查不到用默认值
```

运营可在 VibeAdmin 后台调整 `abilities.point_price` 实现差异化定价。详见 [数据模型 · abilities](./data-models#abilities-能力定价)。

## 积分概览与流水查询

| 端点 | 说明 |
| --- | --- |
| `GET /points/info` | 余额概览：`remaining_points`(=points) + `used_points`(=total_consumed) + `total_points` |
| `POST /points/transactions` | 分页流水：把 `point_transactions` 映射为 `{transaction_type: earn/spend, points_amount: abs(amount), balance_after, type, description}` |
| `POST /points/check` | 校验积分是否充足（前端预发送用） |
| `GET /points/records` | 兼容旧字段的消费记录（来自 `api_logs`） |

::: info total_points 怎么算
`total_points = remaining_points + used_points = points + total_consumed`。这表示「历史获得中扣掉已消耗后剩余」的视角，方便用户理解「我一共获得过多少、用了多少、还剩多少」。
:::

## 排障

| 症状 | 排查 |
| --- | --- |
| 对话返回 402 | 积分不足，充值或用 `dev_001` 测试 |
| 充值到账但余额没变 | 检查 `_credit_order` 是否调用、`add_points` 是否在同一事务 commit |
| 流水缺记录 | 是否绕过了 `add_points`/`consume_points` 直接改账户表 |
| `dev_001` 用户对话扣了费 | 检查 `user_id not in ("1", "dev_001")` 条件是否被改动 |
| 扣费成功但对话失败 | 当前实现不自动退款，记入 `api_logs`(status=failed)，需人工处理 |

## 接下来

- [聊天与流式](./chat-streaming) — 对话扣费的完整链路
- [充值与支付](./recharge-payment) — 充值如何转化为积分
- [数据模型](./data-models) — `point_accounts` / `point_transactions` 完整字段
- [功能指南 · 积分中心](../guide/points) — 用户侧积分功能
