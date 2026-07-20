# 积分 API

积分账户余额、流水、余额校验与消费明细查询。VibeBase 的对话扣费以积分为核心计量单位，所有积分变动都经过 `point_accounts` + `point_transactions` 双表保证一致性。

## 接口总览

| 方法 | 路径 | 认证 | 说明 |
| --- | --- | --- | --- |
| GET | `/points/info` | Bearer | 积分余额概览（首次访问自动建账户） |
| POST | `/points/transactions` | Bearer | 积分流水分页查询 |
| POST | `/points/check` | Bearer | 校验积分是否充足 |
| GET | `/points/records` | Bearer | 消费明细（来自 api_logs） |

## 积分体系概览

::: info 数据来源
- **余额**：独立积分账户表 `point_accounts`（每用户一行，字段 `points` 为当前可用余额）。
- **流水**：`point_transactions`，每次充值 / 消费 / 赠送都会写入一条，`amount` 为正表示增加、为负表示消耗，`balance_after` 记录变动后余额。
- **消费明细**：`api_logs`，每次 AI 调用都会留痕（能力、积分消耗、状态、耗时）。
:::

### 积分消耗顺序

积分按以下顺序消耗：

1. 每日积分
2. 会员积分
3. 积分包
4. 免费积分

::: tip 开发与测试账号免扣费
`user_id` 为 `1` 或 `dev_001` 的账号（管理员 / 开发账号）**不扣费**，便于开发测试。该判断位于对话扣费逻辑中，详见 [对话 API](./chat)。
:::

## 积分余额概览

```
GET /api/v1/points/info
```

**认证：** Bearer

**说明：** 返回当前用户的积分账户。**首次访问会自动创建账户行**（注册用户无流水时也能稳定返回 0 分结构）。

**响应示例：**

```json
{
  "status_code": 200,
  "data": {
    "id": "abc-123",
    "user_id": "abc-123",
    "total_points": 1000,
    "used_points": 500,
    "remaining_points": 500,
    "create_time": "2026-01-01T00:00:00",
    "update_time": "2026-01-01T12:00:00"
  }
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` / `user_id` | string | 用户 ID |
| `total_points` | int | 累计获得积分（remaining + used） |
| `used_points` | int | 累计已消耗积分 |
| `remaining_points` | int | 当前可用余额 |
| `create_time` / `update_time` | string | 账户创建 / 更新时间（ISO） |

## 积分流水分页

```
POST /api/v1/points/transactions
```

**认证：** Bearer

**请求体：**

```json
{
  "page": 1,
  "limit": 20
}
```

| 字段 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `page` | int | 1 | 页码（从 1 开始） |
| `limit` | int | 20 | 每页条数 |

**响应示例：**

```json
{
  "status_code": 200,
  "data": [
    {
      "id": "txn-001",
      "user_id": "abc-123",
      "transaction_type": "earn",
      "points_amount": 500,
      "balance_after": 1000,
      "type": "recharge",
      "description": "新用户注册赠送",
      "create_time": "2026-01-01T00:00:00"
    },
    {
      "id": "txn-002",
      "user_id": "abc-123",
      "transaction_type": "spend",
      "points_amount": 50,
      "balance_after": 950,
      "type": "consume",
      "description": "AI 对话消耗",
      "create_time": "2026-01-01T01:00:00"
    }
  ]
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `transaction_type` | string | `earn`（增加）/ `spend`（消耗），由 `amount` 正负推导 |
| `points_amount` | int | 本次变动积分绝对值 |
| `balance_after` | int | 变动后余额 |
| `type` | string | 业务类型：`recharge` / `consume` / `gift` 等 |
| `description` | string | 描述（取 `remark` → `ability` → `type` 优先级） |

## 校验积分是否充足

```
POST /api/v1/points/check
```

**认证：** Bearer

**请求体：**

```json
{
  "points": 10
}
```

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `points` | int | ✅ | 需要校验的积分数 |

**响应示例：**

```json
{
  "status_code": 200,
  "data": {
    "is_sufficient": true,
    "token_count": 10,
    "remaining_points": 500
  }
}
```

::: tip 用途
对话扣费前的预校验。实际扣费以 `consume_points` 为准，本接口只读不写。
:::

## 消费明细

```
GET /api/v1/points/records
```

**认证：** Bearer

**说明：** 兼容旧字段名的积分明细列表，数据来自 `api_logs`（每次 AI 调用记录）。

**响应示例：**

```json
{
  "status_code": 200,
  "data": [
    {
      "id": "log-001",
      "ability": "AB001",
      "points_cost": 5,
      "status": "success",
      "response_ms": 350,
      "called_at": "2026-01-01T12:00:00"
    }
  ]
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `ability` | string | AI 能力 ID（如 `AB001` AI 对话） |
| `points_cost` | int | 本次积分消耗 |
| `status` | string | 调用状态 `success` / `failed` |
| `response_ms` | int | 响应耗时（毫秒） |
| `called_at` | string | 调用时间 |

## curl 示例

```bash
# 积分概览
curl http://localhost:8081/api/v1/points/info \
  -H "Authorization: Bearer eyJ..."

# 校验积分
curl -X POST http://localhost:8081/api/v1/points/check \
  -H "Authorization: Bearer eyJ..." \
  -H "Content-Type: application/json" \
  -d '{"points": 10}'

# 积分流水分页
curl -X POST http://localhost:8081/api/v1/points/transactions \
  -H "Authorization: Bearer eyJ..." \
  -H "Content-Type: application/json" \
  -d '{"page": 1, "limit": 20}'
```

## 相关文档

- [充值 API](./recharge) — 充值套餐与订单
- [对话 API](./chat) — 对话扣费逻辑
- [用量分析 API](./analytics) — 调用统计
- [API 概览](./overview) — 通用约定
