# 控制台 API

控制台首页聚合数据：积分余额、今日消耗、最近交易流水。将消费与充值合并为统一的「最近交易」列表。

## 接口总览

| 方法 | 路径 | 认证 | 说明 |
| --- | --- | --- | --- |
| GET | `/console/dashboard` | Bearer | 控制台首页聚合数据 |

## 控制台首页

```
GET /api/v1/console/dashboard
```

**认证：** Bearer

**说明：** 为前端 DashboardIndex 页面提供一揽子数据。数据来源：`point_accounts`（余额）+ `api_logs`（消费）+ `point_transactions`（充值流水）。

**响应示例：**

```json
{
  "status_code": 200,
  "data": {
    "balance": 500,
    "frozen_amount": 0,
    "today_consumption": 25,
    "recent_transactions": [
      {
        "id": "txn-uuid-1",
        "time": "2026-07-15T13:00:00",
        "type": "充值",
        "amount": 500,
        "status": "success"
      },
      {
        "id": "log-uuid-1",
        "time": "2026-07-15T12:00:34",
        "type": "AB001",
        "amount": -5,
        "status": "success"
      }
    ]
  }
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `balance` | int | 积分余额（来自 `point_accounts`） |
| `frozen_amount` | int | 冻结金额，当前固定为 `0`（占位） |
| `today_consumption` | int | 今日消耗积分（仅今日 `success` 的 api_log） |
| `recent_transactions` | array | 最近交易流水（最多 5 条） |

### recent_transactions 字段

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | string | 交易 ID |
| `time` | string | 时间（ISO） |
| `type` | string | 类型：`充值`（正数）/ 能力 ID 或 `AI 调用`（负数） |
| `amount` | int | **带符号**：消费为负，充值为正 |
| `status` | string | `success` / `failed` |

## 数据合并逻辑

::: details 最近交易合并算法
`recent_transactions` 将两类数据合并后按时间倒序取前 5 条：

1. **消费记录（负数）**：从 `api_logs` 取当前用户最近 20 条，截取前 5 条，`amount = -(points_cost)`，`type` 取 `ability`（无则为 `AI 调用`）。
2. **充值流水（正数）**：从 `point_transactions` 取当前用户 `type="recharge"` 的最近 5 条，`amount = txn.amount`（正数），`type` 固定为 `充值`。
3. 合并后按 `time` 倒序排序，取前 5 条返回。

::: tip 统一最近交易
控制台将「消费」与「充值」合并为统一的 `recent_transactions` 列表，前端通过 `amount` 正负即可区分收支，无需分别请求两个接口。
:::

::: warning 今日消耗仅统计成功调用
`today_consumption` 只累加今日 `status="success"` 的 `api_logs.points_cost`，失败的调用不计入消耗。
:::

## 数据来源

| 数据 | 来源 |
| --- | --- |
| 余额 `balance` | `point_accounts.points` |
| 今日消耗 | `api_logs`（今日 + success） |
| 消费流水 | `api_logs`（前 5 条） |
| 充值流水 | `point_transactions`（`type="recharge"`，前 5 条） |

## curl 示例

```bash
curl http://localhost:8081/api/v1/console/dashboard \
  -H "Authorization: Bearer eyJ..."
```

## 相关文档

- [用量分析 API](./analytics) — 更详细的图表与排行
- [消费记录 API](./consume) — 消费明细
- [积分 API](./points) — 余额与流水
- [充值 API](./recharge) — 充值订单
- [API 概览](./overview)
