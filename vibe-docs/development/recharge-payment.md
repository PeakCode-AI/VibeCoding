# 充值与支付

VibeBase 的充值闭环由五个端点构成：套餐查询、下单、模拟回调、网关异步通知、记录查询。本页覆盖套餐设计、订单流转、两个回调端点的差异、HMAC-SHA256 验签、幂等设计与状态映射。源码在 `api/v1/recharge.py`。

## 充值套餐

套餐是**硬编码**在 `api/v1/recharge.py` 的 `PACKAGES` 常量（共 5 个），由 `GET /recharge/packages` 公开返回：

| 套餐 id | 名称 | 价格（元） | 积分 | 标记 |
| --- | --- | --- | --- | --- |
| `pkg_basic_month` | 基础版月卡 | 99.0 | 1000 | |
| `pkg_pro_month` | 专业版月卡 | 299.0 | 3500 | **popular** |
| `pkg_enterprise_year` | 企业版年卡 | 5988.0 | 80000 | |
| `pkg_basic_quarter` | 基础版季卡 | 268.0 | 3000 | |
| `pkg_pro_quarter` | 专业版季卡 | 798.0 | 9000 | |

每个套餐对象结构：

```python
{
  "id": "pkg_pro_month",
  "name": "专业版月卡",
  "price": 299.0,
  "points": 3500,
  "features": ["3500 积分", "月度订阅", "高级模型", "优先响应"],
  "popular": True
}
```

::: tip 为什么硬编码
套餐数量少且变动频率低，硬编码便于版本管理与审查。若需运营动态调整，可迁移到数据库表（如复用 `system_config` 或新建 `packages` 表）。
:::

## 端点总览

| 端点 | 方法 | 认证 | 用途 |
| --- | --- | --- | --- |
| `/recharge/packages` | GET | 公开 | 列出 5 个套餐 |
| `/recharge/order` | POST | Bearer | 创建订单（status=pending） |
| `/recharge/callback` | POST | Bearer | **模拟**支付回调（开发自测） |
| `/recharge/notify` | POST | 白名单 + HMAC 验签 | **真实**支付网关异步通知 |
| `/recharge/records` | GET | Bearer | 分页查询我的订单 |

## 订单创建流程

`POST /recharge/order` 创建一笔 pending 订单，需登录态：

```python
@router.post("/recharge/order")
async def create_order(data: OrderCreate, user: UserTable = Depends(UserService.get_current_user)):
    pkg = next((p for p in PACKAGES if p["id"] == data.package_id), None)
    if not pkg:
        raise HTTPException(status_code=400, detail="套餐不存在")
    if data.payment_method not in ("wechat", "alipay", "bank"):
        raise HTTPException(status_code=400, detail="不支持的支付方式")

    order_no = "RC" + datetime.now().strftime("%Y%m%d%H%M%S") + secrets.token_hex(2)
    # 写入 recharge_orders (status="pending")
    ...
    return resp_200({"order_id", "order_no", "amount", "points", "status", "pay_method"})
```

### 订单号格式

```
RC + 20260715 + 143025 + a1b2      → RC20260715143025a1b2
└┬┘   └──┬──┘   └──┬─┘ └──┬──┘
 固定   日期       时间   4 位随机 hex
前缀
```

::: info 为什么 RC 前缀
`recharge_orders.order_no` 以 `RC` 开头（ReCharge），与 `tickets.ticket_no`（`TK`）、`api_logs.log_id`（`LOG`）、`abilities.ability_id`（`AB`）、`announcements.announce_id`（`ANN`）、`admin_users.admin_id`（`A`）形成统一的业务编号前缀体系，便于一眼识别来源。
:::

### 请求体

```python
class OrderCreate(BaseModel):
    package_id: str               # 如 "pkg_pro_month"
    payment_method: str = "wechat"  # wechat / alipay / bank
```

## 两个回调端点的差异

VibeBase 提供**两个**回调入口，分别用于开发自测与真实网关对接：

| 维度 | `/recharge/callback` | `/recharge/notify` |
| --- | --- | --- |
| 用途 | **模拟**支付回调 | **真实**支付网关异步通知 |
| 认证 | Bearer（登录用户） | 白名单 + **HMAC-SHA256 签名** |
| 传参 | `{"order_id": "..."}`（订单主键） | `order_no / amount / status / sign` |
| 定位订单 | `session.get(RechargeOrder, order_id)`（按主键） | `select(...).where(order_no=...)`（按订单号） |
| 适用场景 | 前端开发联调、Mock 支付 | 对接微信/支付宝等真实网关 |

::: warning 不要在生产用 callback
`/recharge/callback` 仅校验登录态，不验签，任何登录用户都能「确认」自己的订单。**仅用于开发自测**。生产环境必须用 `/recharge/notify`，靠 HMAC 签名校验来源。
:::

### 模拟回调 `/recharge/callback`

```python
@router.post("/recharge/callback")
async def pay_callback(data: CallbackRequest, user = Depends(UserService.get_current_user)):
    order_id = data.order_id
    with Session(engine) as session:
        order = session.get(RechargeOrder, order_id)
        if not order or order.user_id != user.user_id:
            return resp_404("订单不存在")
        if order.status == "completed":           # 幂等
            return resp_200({"status": "completed", "points": order.points})

        credit_args = (order.user_id, order.points, order.id, order.plan)  # 先取值
        order.status = "completed"
        session.commit()

    _credit_order(*credit_args)                   # 独立事务加积分
    return resp_200({"status": "completed", "credited_points": credit_args[1]})
```

### 真实网关通知 `/recharge/notify`

```python
@router.post("/recharge/notify")
async def pay_notify(order_no=Body(...), amount=Body(...), status=Body(...), sign=Body(...)):
    if not _verify_notify_sign(order_no, amount, status, sign):
        logger.warning(f"支付回调验签失败: order_no={order_no}")
        raise HTTPException(status_code=403, detail="签名校验失败")

    if status not in ("success", "completed", "SUCCESS"):
        return resp_200({"status": "ignored", "reason": f"非成功状态: {status}"})

    # 按订单号查 → 幂等校验 → 标记完成 → 加积分
    ...
```

## HMAC-SHA256 签名

`/recharge/notify` 用共享密钥 `PAYMENT_NOTIFY_SECRET` 做 HMAC-SHA256 验签，签名串的拼接格式是**固定且必须精确**的：

### 签名串格式

```text
amount={amount}&order_no={order_no}&status={status}
```

### 验签实现

```python
def _verify_notify_sign(order_no: str, amount: str, status: str, sign: str) -> bool:
    secret = os.getenv("PAYMENT_NOTIFY_SECRET", "")
    if not secret:
        return False                                          # 未配置密钥 → 拒绝
    raw = f"amount={amount}&order_no={order_no}&status={status}"
    expected = hmac.new(secret.encode(), raw.encode(), hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, sign or "")         # 常量时间比较，防时序攻击
```

### 验签要点

| 要点 | 说明 |
| --- | --- |
| 密钥来源 | `.env` 的 `PAYMENT_NOTIFY_SECRET` |
| 未配置密钥 | **直接返回 False（拒绝匿名回调）**，必须显式配置才启用 |
| 签名串拼接顺序 | `amount` → `order_no` → `status`，用 `&` 连接，`=` 分隔 |
| 比较方式 | `hmac.compare_digest`（常量时间，防时序攻击） |
| 不匹配 | 返回 **HTTP 403**「签名校验失败」 |

::: danger 签名串顺序不可错
网关端拼签名串时必须严格按 `amount={}&order_no={}&status={}` 顺序，否则验签必失败。对接微信/支付宝官方网关时，需把 `_verify_notify_sign` 替换为官方的 RSA / 证书验签实现。
:::

## 幂等设计

两个回调都做了幂等处理，保证「同一笔订单无论回调多少次，只加一次积分」：

```python
if order.status == "completed":
    # 幂等：已完成的订单不重复加积分，直接返回当前状态
    return resp_200({"status": "completed", "points": order.points})
```

::: tip 为什么必须幂等
支付网关会重试异步通知（网络抖动、对端超时），若不加幂等，重试 N 次就会加 N 倍积分。以 `status == "completed"` 作为幂等键，重复回调直接短路返回。
:::

## 状态流转与映射

`recharge_orders.status` 的流转：

```text
            下单
             │
             ▼
         ┌────────┐  回调验签通过    ┌───────────┐
         │pending │ ──────────────► │ completed │
         └────┬───┘                  └─────┬─────┘
              │                            │
              │ 退款                       │ 退款
              ▼                            ▼
         ┌──────────┐                ┌──────────┐
         │refunded  │                │ refunded │
         └──────────┘                └──────────┘
              │                            │
              │ 取消                       │ 取消
              ▼                            ▼
         ┌──────────┐                ┌──────────┐
         │cancelled │                │cancelled │
         └──────────┘                └──────────┘
```

| 内部 status | 含义 |
| --- | --- |
| `pending` | 待支付（下单后初始状态） |
| `completed` | 已支付（回调验签通过后） |
| `refunded` | 已退款 |
| `cancelled` | 已取消 |

### 对外状态映射

`/recharge/records` 把内部 status 映射为前端/对端友好的状态（`_STATUS_MAP`）：

| 内部 status | 对外 status |
| --- | --- |
| `completed` | `success` |
| `pending` | `pending` |
| `refunded` | `failed` |
| `cancelled` | `failed` |

```python
_STATUS_MAP = {
    "completed": "success",
    "pending": "pending",
    "refunded": "failed",
    "cancelled": "failed",
}
```

## 加积分：_credit_order

订单标记完成后，调 `_credit_order` 给用户积分账户加积分（详见 [积分系统](./points-system)）：

```python
def _credit_order(user_id, points, order_id, plan):
    add_points(
        user_id=user_id, amount=points, type_="recharge",
        source_type="recharge_order", source_id=order_id,
        remark=f"充值套餐: {plan}",
    )
```

::: info 独立事务
订单状态更新（标记 completed）与加积分是**两个独立事务**：先 commit 订单，再调 `add_points`。`_credit_order` 入参传的是已从 ORM 取出的原始值（`credit_args` 元组），避免 Session 关闭后访问 detached 对象属性。
:::

## 如何对接真实支付网关

::: details 对接步骤

**第一步：配置密钥**

在 `.env` 配置：

```bash
PAYMENT_NOTIFY_SECRET=你的共享密钥
```

::: warning 不配置则拒绝
`PAYMENT_NOTIFY_SECRET` 为空时，`_verify_notify_sign` 直接返回 False，`/recharge/notify` 会拒绝所有回调。必须显式配置才启用真实支付。
:::

**第二步：在网关配置回调地址**

把 `https://你的域名/api/v1/recharge/notify` 配置为支付网关的异步通知 URL。确认 `/api/v1/recharge/notify` 在 `whitelist_paths` 中（默认已包含，无需 JWT 鉴权，靠签名校验来源）。

**第三步：让网关按签名格式回调**

要求网关在支付成功后，按以下格式 POST 到 `/recharge/notify`：

```json
{
  "order_no": "RC20260715143025a1b2",
  "amount": "299.00",
  "status": "success",
  "sign": "<HMAC-SHA256 of 'amount=299.00&order_no=RC...&status=success'>"
}
```

**第四步（推荐）：替换为官方验签**

对接微信/支付宝官方网关时，把 `_verify_notify_sign` 替换为对应的 RSA / 证书验签实现（官方 SDK 提供）。当前 HMAC 实现适合自建网关或第三方聚合支付。

:::

## 订单记录查询

`GET /recharge/records` 分页返回当前用户的订单，字段映射：

```python
{
  "id": r.id,
  "transaction_no": r.order_no,            # 对外叫 transaction_no
  "user_id": r.user_id,
  "username": r.username,
  "recharge_time": r.created_at.isoformat(),
  "points": r.points,
  "balance_after": 0,                      # 兼容字段，实际余额查 points
  "status": _STATUS_MAP.get(r.status, r.status)  # 映射后的对外状态
}
```

请求参数：`page`（页码，默认 1）、`limit`（每页条数，默认 20）。

## 排障

| 症状 | 排查 |
| --- | --- |
| `/recharge/notify` 403 签名校验失败 | `PAYMENT_NOTIFY_SECRET` 未配置 / 网关拼签名串顺序错 |
| 充值完成但积分没到账 | 检查 `_credit_order` 是否调用、`add_points` 事务是否提交 |
| 重复回调加了多倍积分 | 检查 `if order.status == "completed"` 幂等判断是否被改动 |
| 模拟回调 404 订单不存在 | `order_id` 应为订单主键（`id`），不是 `order_no` |
| `order_no` 查不到订单 | `/recharge/notify` 用 `order_no` 查，`/recharge/callback` 用主键 `id` 查，别混淆 |

## 接下来

- [积分系统](./points-system) — `add_points` 的完整实现
- [配置 · 支付配置](../configuration/payment) — `PAYMENT_NOTIFY_SECRET` 等配置
- [数据模型](./data-models) — `recharge_orders` 完整字段
- [功能指南 · 充值套餐](../guide/recharge) — 用户侧充值功能
