# 支付配置

VibeBase 的充值闭环由「下单 → 支付 → 回调入账」三步组成。本页讲解回调密钥、HMAC-SHA256 验签算法、两个回调端点的区别（模拟 vs 真实网关）、幂等性、订单状态流转，以及如何对接 **VibePay 支付中台**（免签约微信/支付宝收款）与官方微信/支付宝商户。

源码位置：`api/v1/recharge.py`。

## 推荐：对接 VibePay 支付中台

Vibe 体系已内置 **[VibePay](https://pay.vibeadmin.cn/)** 支付中台，专门解决「个人/小团队没有商户资质也能收款」的问题。它免签约、资金直达你的微信/支付宝账户，并通过安卓监控端自动监听收款通知、回调 VibeBase 完成积分入账。

```
VibeBase 下单充值
   │  POST /api/v1/recharge/order  →  拿到订单号
   ▼
调用 VibePay /createOrder（传 corporateId + appId + sign）
   │  VibePay 返回收款二维码 / 收银台链接
   ▼
用户微信/支付宝扫码付款
   │  安卓监控端监听通知栏 → 上报 VibePay
   ▼
VibePay 匹配订单 → 异步回调 VibeBase /api/v1/recharge/notify
   │  VibeBase 验签（HMAC-SHA256）→ 积分入账
```

对接要点：

- **VibePay 已部署**：[https://pay.vibeadmin.cn/](https://pay.vibeadmin.cn/)，自带管理后台与收银台，无需自建商户。
- **回调对接**：VibePay 回调 VibeBase 的 `/api/v1/recharge/notify`，复用本页的 HMAC-SHA256 验签与幂等入账逻辑。
- **多租户隔离**：VibePay 按 `corporateId` / `appId` 区分商户与应用，每商户独立密钥，安全不串台。
- **源码与文档**：`VibePay/vibePay/README.md`、多租户设计 `VibePay/vibePay/docs/multi-tenant-design.md`、安卓监控端 `VibePay/vibePay-App/`。

> 使用 VibePay，充值从「生成订单」升级为「用户付款、系统收钱、积分到账」的完整生意，无需营业执照、无需官方商户签约。

## 回调密钥

异步通知端点 `/api/v1/recharge/notify` 通过共享密钥校验来源：

```bash
# .env
PAYMENT_NOTIFY_SECRET=your-shared-secret-with-gateway
```

::: danger 必须显式配置
`PAYMENT_NOTIFY_SECRET` 为空时，`/notify` 端点会**拒绝所有回调**（返回 403）。这是一种安全默认——避免密钥未配置时任意人都能伪造充值入账。
:::

## HMAC-SHA256 验签算法

真实支付网关异步通知 `/api/v1/recharge/notify` 时，VibeBase 用 HMAC-SHA256 校验 `sign` 字段。

### 待签名字符串格式

```text
amount={amount}&order_no={order_no}&status={status}
```

字段按 **amount → order_no → status** 的固定顺序拼接，用 `&` 连接，**无空格、无换行**。

### 签名计算

```python
import hmac, hashlib

def _verify_notify_sign(order_no, amount, status, sign) -> bool:
    secret = os.getenv("PAYMENT_NOTIFY_SECRET", "")
    if not secret:
        return False
    raw = f"amount={amount}&order_no={order_no}&status={status}"
    expected = hmac.new(secret.encode(), raw.encode(), hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, sign or "")
```

关键点：

- 算法：**HMAC-SHA256**，输出 64 位十六进制小写字符串。
- 比较方式：`hmac.compare_digest`（**常量时间比较**，防时序攻击），不要用 `==`。
- 密钥缺失：直接返回 `False`（拒绝）。

::: warning 这是通用实现，非官方网关验签
微信 / 支付宝官方验签用的是 RSA + 证书，而不是共享密钥 HMAC。VibeBase 提供这个通用实现是为了**自测、自建网关对接**。对接官方网关时，请替换 `_verify_notify_sign` 为对应 SDK 的验签逻辑。详见文末「对接微信/支付宝」。
:::

### 验签示例

```python
import hmac, hashlib

secret = "your-shared-secret-with-gateway"
raw = "amount=99.00&order_no=RC20260715120000a1b2&status=success"
sign = hmac.new(secret.encode(), raw.encode(), hashlib.sha256).hexdigest()
# sign 形如: 3f9c...（64 字符）
```

## 两个回调端点

VibeBase 区分**模拟回调**（开发自测）与**真实网关异步通知**（生产对接）：

| 端点 | 鉴权 | 用途 | 失败响应 |
| --- | --- | --- | --- |
| `POST /api/v1/recharge/callback` | **Bearer Token**（需登录） | 模拟支付，同步入账 | 404 订单不存在 |
| `POST /api/v1/recharge/notify` | **HMAC 签名**（公网白名单） | 真实网关异步通知 | 403 验签失败 |

### 模拟回调 `/callback`

供前端在开发联调时调用，模拟「用户已完成支付」：

```json
// 请求体
{
  "order_id": "123"
}
```

- **必须登录**（走 `get_current_user` 依赖），且只能回调**属于自己的订单**。
- 找不到订单或非本人 → 404。
- 订单已完成 → 幂等返回 `{"status":"completed"}`，**不重复加积分**。
- 成功 → 标记订单 `completed`，给积分账户加积分并写流水。

### 真实网关通知 `/notify`

供支付网关在用户支付成功后**服务端到服务端**回调：

```json
// 请求体
{
  "order_no": "RC20260715120000a1b2",
  "amount": "99.00",
  "status": "success",
  "sign": "3f9c..."
}
```

- **无需登录**（在 `whitelist_paths` 中），完全靠签名校验来源。
- 验签失败 → **403**（注意：不是 401）。
- 非 `success` / `completed` / `SUCCESS` 状态 → 忽略，返回 `{"status":"ignored"}`。
- 订单已完成 → 幂等返回，不重复加积分。
- 成功 → 标记 `completed` + 加积分。

::: tip 为什么两个端点
- `/callback` 需要 Token，是因为它模拟的是「当前登录用户点了支付」，天然知道是谁。
- `/notify` 是公网回调，网关不知道用户 Token，只能靠订单号 + 签名定位入账对象。
:::

## 幂等性

两个端点都做了幂等处理：

```python
if order.status == "completed":
    return resp_200({"status": "completed", "points": order.points})
# 否则继续：标记完成 + 加积分
```

::: info 为什么必须幂等
支付网关在收到非 200 响应、或超时时会**重试通知**。如果入账不幂等，一次支付可能被记多次积分。VibeBase 通过「订单状态机 + 已完成判断」保证同一订单只入账一次。
:::

## 支付方式

| 值 | 说明 |
| --- | --- |
| `wechat` | 微信支付（默认） |
| `alipay` | 支付宝 |
| `bank` | 银行转账/网银 |

下单时传 `payment_method`，取值不在上述三者内 → 400 拒绝：

```python
if data.payment_method not in ("wechat", "alipay", "bank"):
    raise HTTPException(status_code=400, detail="不支持的支付方式")
```

::: warning 仅记录，未真实跳转
`payment_method` 只是记录在订单上，VibeBase 本身不集成真实支付 SDK。实际支付跳转/拉起由前端或网关完成。
:::

## 订单状态流转

```text
              create_order
                  │
                  ▼
              ┌────────┐  callback/notify
              │pending │ ─────────────────► ┌───────────┐
              └────────┘                     │ completed │
                  │                          └───────────┘
                  │ refund / cancel               │
                  ▼                               │ refund
              ┌───────────┐                       ▼
              │refunded / │                  ┌──────────┐
              │ cancelled │                  │ refunded │
              └───────────┘                  └──────────┘
```

| 内部状态 | 含义 |
| --- | --- |
| `pending` | 已下单待支付 |
| `completed` | 支付成功，已入账 |
| `refunded` | 已退款 |
| `cancelled` | 已取消 |

### 状态映射

返回给前端的展示状态（`_STATUS_MAP`）：

| 内部状态 | 展示状态 |
| --- | --- |
| `completed` | `success` |
| `pending` | `pending` |
| `refunded` | `failed` |
| `cancelled` | `failed` |

::: tip 内部状态 ≠ 前端展示
数据库存的是英文枚举（`completed` 等），给前端的列表接口会转成 `success` / `pending` / `failed` 三态展示。
:::

## 订单号格式

```python
order_no = "RC" + datetime.now().strftime("%Y%m%d%H%M%S") + secrets.token_hex(2)
```

| 段 | 示例 | 说明 |
| --- | --- | --- |
| 前缀 | `RC` | ReCharge 缩写，固定 |
| 时间戳 | `20260715120000` | `YYYYMMDDHHMMSS` |
| 随机后缀 | `a1b2` | 2 字节 hex（`secrets.token_hex(2)`，4 个字符） |

完整示例：`RC20260715120000a1b2`。

::: info 时间戳 + 随机后缀
时间戳保证人眼可读、可排序；4 位随机 hex 防止同一秒并发的订单号碰撞（1/65536 概率，配合数据库唯一约束兜底）。
:::

## 套餐与积分

```python
PACKAGES = [
    {"id": "pkg_basic_month",    "name": "基础版月卡", "price": 99.0,   "points": 1000,  ...},
    {"id": "pkg_pro_month",      "name": "专业版月卡", "price": 299.0,  "points": 3500,  ...},
    {"id": "pkg_enterprise_year","name": "企业版年卡", "price": 5988.0, "points": 80000, ...},
    {"id": "pkg_basic_quarter",  "name": "基础版季卡", "price": 268.0,  "points": 3000,  ...},
    {"id": "pkg_pro_quarter",    "name": "专业版季卡", "price": 798.0,  "points": 9000,  ...},
]
```

通过 `GET /api/v1/recharge/packages` 获取。下单时传 `package_id` 选套餐，回调成功后按套餐 `points` 入账。

## 对接微信/支付宝

VibeBase 的 `/notify` 端点默认是通用 HMAC 验签，**生产对接官方网关时需要替换**：

### 推荐做法

1. **保持端点不变**：仍由 `/api/v1/recharge/notify` 接收网关回调。
2. **替换验签逻辑**：把 `_verify_notify_sign` 改为对应 SDK 的官方验签：
   - 微信支付：用官方证书做 RSA-SHA256 验签，或用 `wechatpayv3` SDK。
   - 支付宝：用 `alipay-sdk` 的 `verify_notify` / RSA2 验签。
3. **统一入账**：验签通过后，调用与现在相同的「标记 completed + 加积分」流程。
4. **参数适配**：把微信/支付宝回调的字段名映射到 VibeBase 内部的 `order_no` / `amount` / `status`。

::: warning 微信回调的字段不同
微信支付 v3 的回调是加密的 JSON（`resource.ciphertext`），需要先用 APIv3 密钥解密再验签。直接套用 VibeBase 的 HMAC 格式不可行，必须替换验签实现。若使用 VibePay 支付中台，这笔适配已由 VibePay 完成，VibeBase 只需收它的统一回调即可。
:::

::: details 自建网关 / VibePay 的对接流程
如果你有一个自建的支付网关（聚合微信/支付宝），或直接使用 VibePay 支付中台，它对外暴露统一回调，那么：

1. 在网关与 VibeBase 之间共享 `PAYMENT_NOTIFY_SECRET`（VibePay 则在其后台配置回调地址指向 VibeBase）。
2. 网关/VibePay 收到官方回调、确认支付成功后，按 VibeBase 的格式拼接 `amount=&order_no=&status=` 并计算 HMAC-SHA256 作为 `sign`。
3. 网关/VibePay POST 到 `/api/v1/recharge/notify`，VibeBase 验签通过即入账。

这是最省改动的对接方式。VibePay 已内置该流程，开箱即用。
:::

## 排障

| 症状 | 排查 |
| --- | --- |
| `/notify` 一直返回 403 | `PAYMENT_NOTIFY_SECRET` 未配置 / 两端密钥不一致 / 签名字符串字段顺序错了 |
| `/notify` 返回 ignored | `status` 不是 `success`/`completed`/`SUCCESS`；检查网关传值 |
| `/callback` 返回 404 | 订单不存在，或订单不属于当前登录用户 |
| 重复入账 | 不应发生；两个端点都做了幂等。若发生，检查是否绕过了 status 判断 |
| 签名对不上 | 用 `hmac.new(secret, raw, sha256).hexdigest()` 离线算一遍，与 `sign` 比对；注意大小写、空格 |
| 订单号重复 | 极小概率（同一秒 + 相同随机后缀）；数据库 `order_no` 加唯一约束兜底 |
| 对接官方网关不工作 | 必须替换 `_verify_notify_sign` 为官方 RSA/证书验签，HMAC 仅适用于自建网关 |

::: tip 离线验证签名
拿到一次失败的 `/notify` 请求体（`order_no` / `amount` / `status` / `sign`），用 Python 复现验签：

```python
import hmac, hashlib
secret = "your-shared-secret"
raw = f"amount={amount}&order_no={order_no}&status={status}"
print(hmac.new(secret.encode(), raw.encode(), hashlib.sha256).hexdigest())
print(sign)
```
两者一致才是合法回调。
:::

## 相关文档

- [后端配置](./backend) — 白名单路径（`/notify` 在其中）
- [JWT 与认证密钥](./jwt) — `/callback` 需要 Bearer Token
- [数据库配置](./database) — `recharge_orders` 表
