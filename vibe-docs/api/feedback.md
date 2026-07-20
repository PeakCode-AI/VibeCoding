# 反馈 API

用户提交意见反馈。反馈由 C 端用户通过富文本编辑器提交，由 VibeAdmin 后台处理。

## 接口总览

| 方法 | 路径 | 认证 | 说明 |
| --- | --- | --- | --- |
| POST | `/feedback` | Bearer | 提交反馈 |

::: info 前端编辑器
前端反馈输入框基于 **Tiptap 富文本编辑器**实现，支持格式化文本。提交的 `content` 可包含富文本内容，后端原样存储，由 VibeAdmin 后台查阅与处理。
:::

## 提交反馈

```
POST /api/v1/feedback
```

**认证：** Bearer

**请求体：**

```json
{
  "content": "对话功能非常好用，希望支持更多模型！",
  "contact": "demo@example.com"
}
```

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `content` | string | ✅ | 反馈内容（支持富文本） |
| `contact` | string | ❌ | 联系方式（邮箱 / 手机号等），默认空字符串 |

**响应示例：**

```json
{
  "status_code": 200,
  "data": {
    "id": "feedback-uuid"
  }
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | string | 新建的反馈 ID |

::: tip 反馈状态
新建反馈的状态默认为 `pending`（待处理）。VibeAdmin 后台运营 / 客服角色可将其标记为 `handled` 等状态。C 端目前仅提供提交入口，不提供列表查询。
:::

## 处理流程

```
用户提交（pending）→ VibeAdmin 后台处理（handled）
```

反馈数据存储在 `feedbacks` 表，与 VibeAdmin 后台共享。C 端用户提交后，由 VibeAdmin 的运营 / 客服在后台查看并跟进。

## curl 示例

```bash
curl -X POST http://localhost:8081/api/v1/feedback \
  -H "Authorization: Bearer eyJ..." \
  -H "Content-Type: application/json" \
  -d '{
    "content": "对话功能非常好用，希望支持更多模型！",
    "contact": "demo@example.com"
  }'
```

## 相关文档

- [工单 API](./ticket) — 需要跟进的问题工单
- [公告 API](./announcement) — 平台公告
- [API 概览](./overview)
- [错误码](./error-codes)
