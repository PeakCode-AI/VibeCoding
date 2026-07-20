# 充值 API

充值套餐、订单、支付回调与网关异步通知。套餐为后端硬编码，订单状态以 `pending → completed → refunded/cancelled` 流转，回调与通知均设计为幂等。

## 接口总览

| 方法 | 路径 | 认证 | 说明 |
| --- | --- | --- | --- |
| GET | `/recharge/packages` | 公开 | 充值套餐列表 |
| POST | `/recharge/order` | Bearer | 创建充值订单 |
| GET | `/recharge/records` | Bearer | 充值记录 |
| POST | `/recharge/callback` | Bearer | 模拟支付回调（开发自测） |
| POST | `/recharge/notify` | 公开（白名单 + 签名） | 支付网关异步通知 |

## 套餐

套餐在 `api/v1/recharge.py` 中以 `PACKAGES` 常量硬编码，共 5 个：

| 套餐 ID | 名称 | 价格 | 积分 | 标记 |
| --- | --- | --- | --- | --- |
| `pkg_basic_month` | 基础版月卡 | ¥99 | 1000 | — |
| `pkg_pro_month` | 专业版月卡 | ¥299 | 3500 | **热门** |
| `pkg_enterprise_year` | 企业版年卡 | ¥5988 | 80000 | — |
| `pkg_basic_quarter` | 基础版季卡 | ¥268 | 3000 | — |
| `pkg_pro_quarter` | 专业版季卡 | ¥798 | 9000 | — |

## 套餐列表

```
GET /api/v1/recharge/packages
```

**认证：** 公开

**响应示例：**

```json
{
  "status_code": 200,
  "data": [
    {
      "id": "pkg_basic_month",
      "name": "基础版月卡",
      "price": 99.0,
      "points": 1000,
      "features": ["1000 积分", "月度订阅", "基础模型"],
      "popular": false
    },
    {
      "id": "pkg_pro_month",
      "name": "专业版月卡",
      "price": 299.0,
      "points": 3500,
      "features": ["3500 积分", "月度订阅", "高级模型", "优先响应"],
      "popular": true
    }
  ]
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | string | 套餐 ID（创建订单时使用） |
| `price` | float | 价格（元） |
| `points` | int | 套餐积分 |
| `features` | string[] | 特性描述 |
| `popular` | bool | 是否热门标记 |

## 创建订单

```
POST /api/v1/recharge/order
```

**认证：** Bearer

**请求体：**

```json
{
  "package_id": "pkg_pro_month",
  "payment_method": "wechat"
}
```

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `package_id` | string | ✅ | 套餐 ID |
| `payment_method` | string | ❌ | 支付方式，默认 `wechat`；可选 `wechat` / `alipay` / `bank` |

**响应示例：**

```json
{
  "status_code": 200,
  "data": {
    "order_id": "order-uuid",
    "order_no": "RC20260715120034a1b2",
    "amount": 299.0,
    "points": 3500,
    "status": "pending",
    "pay_method": "wechat"
  }
}
```

::: details 订单号格式
`RC` + 时间戳（`%Y%m%d%H%M%S`）+ 2 字节 hex 随机串。例如：`RC20260715120034a1b2`。
:::

**错误：**

| status_code | 说明 |
| --- | --- |
| 400 | 套餐不存在 / 不支持的支付方式 |

## 充值记录

```
GET /api/v1/recharge/records?page=1&limit=20
```

**认证：** Bearer

**查询参数：**

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `page` | 1 | 页码 |
| `limit` | 20 | 每页条数 |

**响应示例：**

```json
{
  "status_code": 200,
  "data": {
    "records": [
      {
        "id": "order-uuid",
        "transaction_no": "RC20260715120034a1b2",
        "user_id": "abc-123",
        "username": "demo_user",
        "recharge_time": "2026-07-15T12:00:34",
        "points": 3500,
        "balance_after": 0,
        "status": "success"
      }
    ],
    "total": 1
  }
}
```

::: tip 状态映射
订单原始 `status` 通过 `_STATUS_MAP` 映射为前端友好值：
- `completed` → `success`
- `pending` → `pending`
- `refunded` / `cancelled` → `failed`
:::

## 模拟支付回调

```
POST /api/v1/recharge/callback
```

**认证：** Bearer

**说明：** 前端开发模拟支付回调。请求体为 JSON 对象。将订单标记为 `completed` 并为积分账户加积分。**幂等**：订单已完成则直接返回，不重复加积分。

**请求体：**

```json
{
  "order_id": "order-uuid"
}
```

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `order_id` | string | ✅ | 订单 ID |

**响应示例：**

```json
{
  "status_code": 200,
  "data": {
    "status": "completed",
    "credited_points": 3500,
    "points": 3500
  }
}
```

::: warning 仅订单所有者可回调
若订单的 `user_id` 与当前登录用户不一致，返回 404「订单不存在」。
:::

## 支付网关异步通知

```
POST /api/v1/recharge/notify
```

**认证：** 公开（白名单 + HMAC 签名校验）

**说明：** 对接真实微信 / 支付宝网关时，将本端点 URL 配置为回调地址。无需登录，**靠 HMAC-SHA256 签名校验来源**。

**请求体：**

```json
{
  "order_no": "RC20260715120034a1b2",
  "amount": "299.00",
  "status": "success",
  "sign": "hmac-sha256-hex-string"
}
```

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `order_no` | string | ✅ | 订单号 |
| `amount` | string | ✅ | 金额（字符串） |
| `status` | string | ✅ | 网关状态：`success` / `completed` / `SUCCESS` |
| `sign` | string | ✅ | HMAC-SHA256 签名 |

::: details 签名算法
使用环境变量 `PAYMENT_NOTIFY_SECRET` 作为共享密钥，对原始字符串 `amount={amount}&order_no={order_no}&status={status}` 做 HMAC-SHA256，再与传入的 `sign` 用 `hmac.compare_digest` 常量时间比较。

```python
raw = f"amount={amount}&order_no={order_no}&status={status}"
expected = hmac.new(secret.encode(), raw.encode(), hashlib.sha256).hexdigest()
```

- **未配置 `PAYMENT_NOTIFY_SECRET`**：直接拒绝（返回 False），需显式配置后才启用。
- **签名不匹配**：返回 `403 签名校验失败`。
- **幂等**：订单已完成则直接返回 `completed`，不重复加积分。
- 接收非成功状态（不是 `success` / `completed` / `SUCCESS`）时返回 `ignored`，不加积分。
:::

::: danger 生产对接提示
对接官方网关（微信 / 支付宝）时，请将 `_verify_notify_sign` 替换为对应的 RSA / 证书验签实现，并在 `.env` 配置 `PAYMENT_NOTIFY_SECRET`。
:::

## 订单状态流

```
pending（创建）→ completed（回调/通知成功）→ refunded / cancelled
```

| 原始状态 | 含义 |
| --- | --- |
| `pending` | 待支付 |
| `completed` | 已完成（已加积分） |
| `refunded` | 已退款 |
| `cancelled` | 已取消 |

## 幂等设计

`callback` 与 `notify` 都在加积分前检查 `order.status == "completed"`，已完成则直接返回，**避免重复加积分**。加积分操作走独立事务（`add_points` 同时更新 `point_accounts` 与 `point_transactions`），保证账户与流水一致。

## curl 示例

```bash
# 创建订单
curl -X POST http://localhost:8081/api/v1/recharge/order \
  -H "Authorization: Bearer eyJ..." \
  -H "Content-Type: application/json" \
  -d '{"package_id": "pkg_pro_month", "payment_method": "wechat"}'

# 模拟支付回调
curl -X POST http://localhost:8081/api/v1/recharge/callback \
  -H "Authorization: Bearer eyJ..." \
  -H "Content-Type: application/json" \
  -d '{"order_id": "order-uuid"}'

# 充值记录
curl "http://localhost:8081/api/v1/recharge/records?page=1&limit=20" \
  -H "Authorization: Bearer eyJ..."
```

## 相关文档

- [积分 API](./points) — 积分余额与流水
- [API 概览](./overview) — 白名单与认证
- [错误码](./error-codes)
