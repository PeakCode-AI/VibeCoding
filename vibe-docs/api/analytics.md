# 用量分析 API

控制台用量分析数据：总调用数、今日 / 本月消耗、余额、图表数据、业务类型分布与调用排行。所有数据来源于 `api_logs` 表。

## 接口总览

| 方法 | 路径 | 认证 | 说明 |
| --- | --- | --- | --- |
| GET | `/analytics/usage` | Bearer | 用量分析聚合数据 |

## 用量分析

```
GET /api/v1/analytics/usage?range=7d
```

**认证：** Bearer

**查询参数：**

| 参数 | 别名 | 默认 | 说明 |
| --- | --- | --- | --- |
| `range` | `period` | `7d` | 统计窗口：`today` / `7d` / `30d` |

::: tip 查询参数别名
后端用 `Query(..., alias="range")`，前端可用 `?range=7d` 或 `?period=7d` 两种写法。
:::

**响应示例：**

```json
{
  "status_code": 200,
  "data": {
    "stats": {
      "total_calls": 120,
      "total_calls_trend": 0,
      "today_consumption": 25,
      "today_trend": 0,
      "month_consumption": 480,
      "month_trend": 0,
      "balance": 500
    },
    "chartData": [
      { "label": "07-09", "value": 8 },
      { "label": "07-10", "value": 12 }
    ],
    "businessTypes": [
      { "name": "AB001", "value": 300, "percentage": 62.5, "color": "#6366f1" },
      { "name": "AB003", "value": 180, "percentage": 37.5, "color": "#ec4899" }
    ],
    "ranking": [
      { "rank": 1, "name": "AB001", "code": "AB001", "calls": 60, "percentage": 50.0 }
    ]
  }
}
```

### stats 字段

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `total_calls` | int | 累计调用次数（`api_logs` 全量） |
| `total_calls_trend` | int | 趋势值，当前固定为 `0`（占位） |
| `today_consumption` | int | 今日消耗积分（仅今日 `success` 调用） |
| `today_trend` | int | 今日趋势，固定 `0` |
| `month_consumption` | int | 本月消耗积分 |
| `month_trend` | int | 本月趋势，固定 `0` |
| `balance` | int | 积分余额（来自 `point_accounts`） |

### chartData 字段

图表分桶规则：

| range | 分桶方式 | 数量 |
| --- | --- | --- |
| `today` | 按小时（0、4、8、12、16、20、24 点） | 6 个 |
| `7d` | 按天，最近 7 天 | 7 个 |
| `30d` | 按天，最近 30 天 | 30 个 |

- `today`：`label` 形如 `08:00`。
- `7d` / `30d`：`label` 形如 `07-15`（去掉年份）。

### businessTypes 字段

业务类型分布，**按消耗积分**聚合（`ability` 维度），按 value 降序：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `name` | string | 能力标识（`api_logs.ability`） |
| `value` | int | 该能力累计消耗积分 |
| `percentage` | float | 占比（保留 1 位小数） |
| `color` | string | 前端配色（循环取自 6 色板） |

色板：`#6366f1`、`#ec4899`、`#f59e0b`、`#10b981`、`#0ea5e9`、`#8b5cf6`。

::: tip 业务类型示例
典型业务类型：**AI 对话 / 图像 / 语音 / 文本**（具体取值取决于 `api_logs.ability` 字段，种子数据中为 `AI 对话`、`文本生成`、`图像生成` 等）。
:::

### ranking 字段

调用排行，**按调用次数**聚合（`ability` 维度），取前 5：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `rank` | int | 排名（1-5） |
| `name` | string | 能力标识 |
| `code` | string | 大写化的能力码（空格转下划线） |
| `calls` | int | 调用次数 |
| `percentage` | float | 占总调用次数的比例 |

## 数据来源

::: info 数据来源
所有统计来自 `api_logs` 表（对话等 AI 调用每次都会写入一条日志）。`balance` 来自独立的 `point_accounts` 积分账户。
:::

## curl 示例

```bash
# 最近 7 天用量
curl "http://localhost:8081/api/v1/analytics/usage?range=7d" \
  -H "Authorization: Bearer eyJ..."

# 今日用量
curl "http://localhost:8081/api/v1/analytics/usage?range=today" \
  -H "Authorization: Bearer eyJ..."

# 最近 30 天
curl "http://localhost:8081/api/v1/analytics/usage?range=30d" \
  -H "Authorization: Bearer eyJ..."
```

## 相关文档

- [控制台 API](./console) — 首页聚合数据
- [消费记录 API](./consume) — 明细列表
- [积分 API](./points) — 余额查询
- [API 概览](./overview)
