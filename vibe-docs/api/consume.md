# 消费记录 API

用户 AI 调用的消费明细。数据来源于 `api_logs` 表，支持按用户名与业务类型过滤。

## 接口总览

| 方法 | 路径 | 认证 | 说明 |
| --- | --- | --- | --- |
| GET | `/consume/records` | Bearer | 消费记录列表（分页 + 过滤） |

## 消费记录

```
GET /api/v1/consume/records?username=&biz_type=&page=1&page_size=20
```

**认证：** Bearer

**查询参数：**

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `username` | `""` | 用户名模糊过滤（包含匹配） |
| `biz_type` | `""` | 业务类型过滤，`all` 或空表示不过滤 |
| `page` | 1 | 页码（≥1） |
| `page_size` | 20 | 每页条数（1-200） |

**响应示例：**

```json
{
  "status_code": 200,
  "data": {
    "records": [
      {
        "id": "log-uuid-1",
        "transaction_no": "LOG20260715120034a1b2c3",
        "username": "demo_user",
        "time": "2026-07-15 12:00:34",
        "type": "消费",
        "biz_type": "AB001",
        "amount": -5,
        "after_amount": 0,
        "status": "success"
      }
    ],
    "total": 1
  }
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | string | api_log 主键 |
| `transaction_no` | string | 交易号（取自 `log_id`，如 `LOG20260715120034a1b2c3`） |
| `username` | string | 调用者用户名 |
| `time` | string | 调用时间（`%Y-%m-%d %H:%M:%S`） |
| `type` | string | 固定为 `消费` |
| `biz_type` | string | 业务类型（取自 `ability`，如 `AB001`） |
| `amount` | int | **金额为负数**（消耗积分的负值） |
| `after_amount` | int | 变动后金额（当前固定 0，占位） |
| `status` | string | `success` / `failed` |

::: tip amount 为负数
消费记录的 `amount` 字段是**消耗积分的负值**（`-(points_cost)`），与「充值」的正数语义区分。例如消耗 5 积分显示为 `-5`。
:::

::: warning 内存过滤
后端先从 `api_logs` 取出当前用户全部记录，再在内存中按 `username`（包含匹配）与 `biz_type`（相等匹配，`all` 跳过）过滤，最后分页。数据量大时该实现存在性能上限。
:::

## 数据来源

::: info 数据来源
所有记录来自 `api_logs` 表（对话等 AI 调用每次都会写入一条日志）。`biz_type` 实际取自 `api_logs.ability`，对应 [AI 能力](./ability) 中的能力标识。仅返回当前登录用户的记录。
:::

## curl 示例

```bash
# 全部消费记录
curl "http://localhost:8081/api/v1/consume/records?page=1&page_size=20" \
  -H "Authorization: Bearer eyJ..."

# 按业务类型过滤
curl "http://localhost:8081/api/v1/consume/records?biz_type=AB001&page=1" \
  -H "Authorization: Bearer eyJ..."

# 按用户名模糊过滤
curl "http://localhost:8081/api/v1/consume/records?username=alice&page=1" \
  -H "Authorization: Bearer eyJ..."
```

## 相关文档

- [用量分析 API](./analytics) — 聚合统计
- [控制台 API](./console) — 首页聚合
- [AI 能力 API](./ability) — 能力与定价
- [积分 API](./points) — 积分流水
- [API 概览](./overview)
