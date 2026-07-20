# 工单 API

C 端用户提交的工单（Ticket）。工单由用户在 C 端提交，由 VibeAdmin 后台运营 / 客服处理。

## 接口总览

| 方法 | 路径 | 认证 | 说明 |
| --- | --- | --- | --- |
| GET | `/tickets` | Bearer | 当前用户的工单列表 |
| POST | `/tickets` | Bearer | 提交工单 |
| GET | `/tickets/{ticket_id}` | Bearer | 工单详情（仅本人） |

## 工单编号格式

工单号 `ticket_no` 生成规则：

```
TK + 时间戳(%Y%m%d%H%M%S) + 4 字符 hex
```

示例：`TK20260715120034a1b2`。

## 状态与优先级

| 状态 | 含义 |
| --- | --- |
| `pending` | 待处理 |
| `processing` | 处理中 |
| `resolved` | 已解决 |
| `closed` | 已关闭 |

| 优先级 | 含义 |
| --- | --- |
| `high` | 高 |
| `medium` | 中（默认） |
| `low` | 低 |

::: info 处理流程
C 端用户提交工单（`pending`）→ VibeAdmin 后台接单处理（`processing`）→ 解决（`resolved`）→ 关闭（`closed`）。状态流转由 VibeAdmin 后台操作，C 端仅提交与查看。
:::

## 工单列表

```
GET /api/v1/tickets
```

**认证：** Bearer

**说明：** 返回**当前用户**提交的工单，按创建时间倒序。

**响应示例：**

```json
{
  "status_code": 200,
  "data": [
    {
      "id": "ticket-uuid-1",
      "ticket_no": "TK20260715120034a1b2",
      "title": "积分未到账",
      "content": "我充值了 99 元，但是积分没有到账。",
      "status": "processing",
      "priority": "high",
      "created_at": "2026-07-15T12:00:34",
      "updated_at": "2026-07-15T13:00:00"
    }
  ]
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `ticket_no` | string | 工单号 |
| `title` | string | 标题 |
| `content` | string | 正文 |
| `status` | string | 状态 |
| `priority` | string | 优先级 |
| `created_at` / `updated_at` | string | 创建 / 更新时间 |

## 提交工单

```
POST /api/v1/tickets
```

**认证：** Bearer

**请求体：**

```json
{
  "title": "积分未到账",
  "content": "我充值了 99 元，但是积分没有到账，请帮我查一下。",
  "priority": "high"
}
```

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `title` | string | ✅ | 标题 |
| `content` | string | ✅ | 正文 |
| `priority` | string | ❌ | 优先级，默认 `medium`，可选 `high` / `medium` / `low` |

**响应示例：**

```json
{
  "status_code": 200,
  "data": {
    "id": "ticket-uuid-2",
    "ticket_no": "TK20260715120034c3d4",
    "status": "pending",
    "created_at": "2026-07-15T12:00:34"
  }
}
```

::: tip 新工单状态
提交后工单状态固定为 `pending`，与传入的 `priority` 无关。
:::

**错误：**

| status_code | 说明 |
| --- | --- |
| 400 | 优先级取值: high/medium/low |

## 工单详情

```
GET /api/v1/tickets/{ticket_id}
```

**认证：** Bearer

**路径参数：**

| 参数 | 说明 |
| --- | --- |
| `ticket_id` | 工单主键 ID |

**说明：** 仅返回**属于当前用户**的工单。若工单不存在或不属于当前用户，统一返回 404（避免枚举他人工单）。

**响应示例：**

```json
{
  "status_code": 200,
  "data": {
    "id": "ticket-uuid-1",
    "ticket_no": "TK20260715120034a1b2",
    "title": "积分未到账",
    "content": "我充值了 99 元，但是积分没有到账。",
    "status": "processing",
    "priority": "high",
    "created_at": "2026-07-15T12:00:34",
    "updated_at": "2026-07-15T13:00:00"
  }
}
```

**错误：** 404 工单不存在（含非本人工单）。

## curl 示例

```bash
# 我的工单列表
curl http://localhost:8081/api/v1/tickets \
  -H "Authorization: Bearer eyJ..."

# 提交工单
curl -X POST http://localhost:8081/api/v1/tickets \
  -H "Authorization: Bearer eyJ..." \
  -H "Content-Type: application/json" \
  -d '{
    "title": "积分未到账",
    "content": "我充值了 99 元，但是积分没有到账。",
    "priority": "high"
  }'

# 工单详情
curl http://localhost:8081/api/v1/tickets/ticket-uuid-1 \
  -H "Authorization: Bearer eyJ..."
```

## 相关文档

- [反馈 API](./feedback) — 轻量意见反馈
- [充值 API](./recharge) — 充值订单
- [API 概览](./overview)
- [错误码](./error-codes)
