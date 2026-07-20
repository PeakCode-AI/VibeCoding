# AI 能力 API

AI 能力（abilities）的查询。每个能力对应一种 AI 服务，带积分定价 `point_price`。对话扣费时按 `ability_id` 查表得到单价。

## 接口总览

| 方法 | 路径 | 认证 | 说明 |
| --- | --- | --- | --- |
| GET | `/ability` | 公开 | 列出启用中的能力 |
| GET | `/ability/{ability_id}` | 公开 | 查询单个能力 |

## 能力分类

| 分类 | 含义 |
| --- | --- |
| `nlp` | 自然语言（对话 / 文本生成） |
| `multimodal` | 多模态 |
| `voice` | 语音（合成 / 识别） |
| `vision` | 视觉（图像生成 / OCR） |

## 定价机制

::: info 单价来源
每个能力在 `abilities` 表中有 `point_price` 字段（整数积分）。对话扣费时调用 `_resolve_ability_price(ability_id)`：

1. 查 `abilities` 表，命中且 `status="up"` 则用表中的 `ability_id` 与 `point_price`。
2. 未命中则回退到默认值 `AB001` / 单价 5（保证对话链路始终可用）。
:::

详见 [对话 API](./chat) 的扣费逻辑。

## 默认种子能力

`abilities` 表为空时，`init_data.py` 会灌入以下 6 条默认能力：

| ability_id | 名称 | 分类 | 单价（积分） |
| --- | --- | --- | --- |
| `AB001` | AI 对话 | nlp | 5 |
| `AB002` | 文本生成 | nlp | 8 |
| `AB003` | 图像生成 | vision | 20 |
| `AB004` | 语音合成 | voice | 10 |
| `AB005` | 语音识别 | voice | 6 |
| `AB006` | OCR 识别 | vision | 12 |

所有种子能力初始 `status="up"`、`call_count=0`。

## 列出启用中的能力

```
GET /api/v1/ability
```

**认证：** 公开

**说明：** 只返回 `status="up"` 的能力。

**响应示例：**

```json
{
  "status_code": 200,
  "data": [
    {
      "id": "uuid-1",
      "ability_id": "AB001",
      "name": "AI 对话",
      "category": "nlp",
      "point_price": 5,
      "status": "up",
      "call_count": 0,
      "created_at": "2026-01-01T00:00:00"
    },
    {
      "id": "uuid-2",
      "ability_id": "AB003",
      "name": "图像生成",
      "category": "vision",
      "point_price": 20,
      "status": "up",
      "call_count": 0,
      "created_at": "2026-01-01T00:00:00"
    }
  ]
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `ability_id` | string | 业务能力 ID（如 `AB001`） |
| `name` | string | 能力名称 |
| `category` | string | 分类：`nlp` / `multimodal` / `voice` / `vision` |
| `point_price` | int | 单次调用积分单价 |
| `status` | string | `up`（启用）/ `down`（停用） |
| `call_count` | int | 累计调用次数 |

## 查询单个能力

```
GET /api/v1/ability/{ability_id}
```

**认证：** 公开

**路径参数：**

| 参数 | 说明 |
| --- | --- |
| `ability_id` | 能力 ID，可传主键 `id` 或业务 `ability_id`（如 `AB001`） |

**说明：** 先按主键 `id` 查，未命中再按 `ability_id` 查。

**响应示例：**

```json
{
  "status_code": 200,
  "data": {
    "id": "uuid-1",
    "ability_id": "AB001",
    "name": "AI 对话",
    "category": "nlp",
    "point_price": 5,
    "status": "up",
    "call_count": 0,
    "created_at": "2026-01-01T00:00:00"
  }
}
```

**错误：**

| status_code | 说明 |
| --- | --- |
| 404 | 能力不存在 |

## curl 示例

```bash
# 列出所有启用能力
curl http://localhost:8081/api/v1/ability

# 查询单个能力
curl http://localhost:8081/api/v1/ability/AB001
```

## 相关文档

- [对话 API](./chat) — 按能力单价扣费
- [积分 API](./points) — 积分余额与扣减
- [用量分析 API](./analytics) — 按能力维度的统计
- [API 概览](./overview)
