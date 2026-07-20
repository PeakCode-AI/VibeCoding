# 对话 API

AI 对话、对话会话管理、消息历史相关接口。涵盖 `/api/v1/chat`、`/api/v1/dialog`、`/api/v1/message`、`/api/v1/history` 前缀。

## 接口总览

| 方法 | 路径 | 认证 | 说明 |
| --- | --- | --- | --- |
| POST | `/chat` | Bearer | **SSE 流式对话**（核心） |
| POST | `/upload` | Bearer | 文件上传 |
| GET | `/dialog/list` | Bearer | 对话列表 |
| POST | `/dialog` | Bearer | 创建对话 |
| DELETE | `/dialog` | Bearer | 删除对话（级联删消息） |
| POST | `/dialog/status` | Bearer | 收藏 / 重要标记 |
| GET | `/message/list/{dialog_id}` | Bearer | 对话消息列表 |
| GET | `/history` | Bearer | 对话历史 |
| POST | `/message/like` | — | 点赞 |
| POST | `/message/down` | — | 反对 |

## 流式对话（核心）

```
POST /api/v1/chat
```

**认证：** Bearer

**请求体 `ConversationReq`：**

```json
{
  "user_input": "你好，请介绍一下自己",
  "dialog_id": "dialog-abc-123",
  "file_url": "",
  "open_search": false,
  "open_reasoning": false,
  "open_research": false,
  "llm_id": ""
}
```

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `user_input` | string | ✅ | 用户输入，前端上限 4000 字符 |
| `dialog_id` | string | ✅ | 对话 ID（需先创建对话） |
| `file_url` | string | ❌ | 附件 URL（图像理解） |
| `open_search` | bool | ❌ | 联网搜索 |
| `open_reasoning` | bool | ❌ | 深度思考 |
| `open_research` | bool | ❌ | 深度研究 |
| `llm_id` | string | ❌ | 指定模型 |

**响应：** `text/event-stream`（SSE 流），**不走** `UnifiedResponseModel`。

### SSE 协议

每条消息格式：`data: {json}\n\n`

后端会依次推送以下事件类型：

| 事件 type | data 字段 | 说明 |
| --- | --- | --- |
| `llm_start` | `{message}` | 模型开始响应 |
| `response_chunk` | `{chunk, accumulated}` | **逐字流式内容**，`chunk` 是本次增量，`accumulated` 是累计全文 |
| `llm_end` | `{message, usage, model}` | 响应结束，含 token 用量与模型名 |
| `error` | `{message}` | 错误（如模型调用失败） |

流以 `data: [DONE]\n\n` 结束。

::: details 完整 SSE 流示例
```text
data: {"type":"llm_start","data":{"message":"模型响应中..."}}

data: {"type":"response_chunk","data":{"chunk":"你","accumulated":"你"}}

data: {"type":"response_chunk","data":{"chunk":"好","accumulated":"你好"}}

data: {"type":"response_chunk","data":{"chunk":"！","accumulated":"你好！"}}

data: {"type":"llm_end","data":{"message":"完成","usage":{"prompt_tokens":10,"completion_tokens":3},"model":"qwen-plus"}}

data: [DONE]
```
:::

### 前端额外事件

前端基于增强体验，还会处理以下事件类型（部分由 Agent 模式产生）：

| 事件 | 说明 |
| --- | --- |
| `thinking_start` | 开始思考 |
| `search_start` / `search_results` / `search_end` | 联网搜索流程 |
| `tool_call` / `tool_result` | 工具调用 |
| `reasoning_chunk` | 推理过程流式输出 |
| `points_deducted` | 积分已扣除 |
| `points_insufficient` | 积分不足 |
| `points_warning` | 积分预警 |
| `user_clarification_request` | Agent 请求补充澄清 |
| `plan_ready` | 研究计划就绪待确认 |
| `research_plan` / `sources_update` | 研究计划 / 来源更新 |

### 对话处理流程

```
1. 解析能力定价（abilities 表，默认 AB001 / 5 积分）
2. 若 LLM 已配置 且 user_id 不在 ("1","dev_001") → consume_points
   ├─ 余额不足 → 返回 402 "积分余额不足"
   └─ 扣费失败 → fail-open（不扣费，继续对话）
3. 加载最近 10 条历史消息作为上下文
4. 流式调用 LLM（OpenAI 兼容协议）
   ├─ 已配置 → 逐字推送 response_chunk
   └─ 未配置/占位符 → 推送降级提示（不扣费）
5. 流结束：持久化用户消息 + AI 回复 + events 到 histories 表
6. 写入 api_logs（积分消耗 / 响应耗时 / 状态）
```

::: tip 优雅降级
当 `OPENAI_API_KEY` 为空或为占位符（`""`、`"your-api-key"`、`"sk-xxx"`、`"changeme"`、`"none"`、`"null"`）时，对话会返回降级提示且**不扣积分**。详见 [LLM 配置](../configuration/llm)。
:::

### curl 示例

```bash
curl -N http://localhost:8081/api/v1/chat \
  -H "Authorization: Bearer eyJ..." \
  -H "Content-Type: application/json" \
  -d '{"dialog_id":"test","user_input":"你好"}'
```

::: warning `-N` 必加
`curl` 默认会缓冲输出，加 `-N`（`--no-buffer`）才能实时看到 SSE 流。
:::

### 前端调用示例

```javascript
import { fetchEventSource } from '@microsoft/fetch-event-source'

fetchEventSource('/api/v1/chat', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({ dialog_id, user_input }),
  onmessage(ev) {
    const { type, data } = JSON.parse(ev.data)
    if (type === 'response_chunk') {
      // 追加 data.chunk 到界面
    } else if (type === 'llm_end') {
      // 结束
    }
  }
})
```

## 文件上传

```
POST /api/v1/upload
```

**认证：** Bearer

**请求：** `multipart/form-data`，字段 `file`

**响应：**

```json
{
  "status_code": 200,
  "data": {
    "filename": "photo.jpg",
    "size": 102400
  }
}
```

::: info 当前实现
上传的文件目前读入内存，**未持久化到 S3**。返回的 `filename` 可作为后续对话的 `file_url`（图像理解场景）。
:::

## 对话列表

```
GET /api/v1/dialog/list?page=1&limit=50&chat_name=关键字
```

**认证：** Bearer

**查询参数：**

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `page` | 1 | 页码 |
| `limit` | 50 | 每页条数 |
| `chat_name` | — | 按对话名模糊搜索 |

**响应（字段为 camelCase）：**

```json
{
  "status_code": 200,
  "data": [
    {
      "chatId": "dialog-abc",
      "chatName": "我的对话",
      "createTime": "2026-01-01T00:00:00",
      "updateTime": "2026-01-01T00:00:00",
      "agent_id": "",
      "user_id": "abc-123",
      "preview": "最近一条消息预览..."
    }
  ]
}
```

按更新时间倒序返回。

## 创建对话

```
POST /api/v1/dialog
```

**认证：** Bearer

**请求体：**

```json
{
  "name": "新的对话",
  "agent_id": "",
  "agent_type": "Agent"
}
```

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `name` | string | ✅ | 对话名 |
| `agent_id` | string | ❌ | 关联 Agent ID |
| `agent_type` | string | ❌ | `Agent`（默认）或 `MCPAgent` |

## 删除对话

```
DELETE /api/v1/dialog
```

**认证：** Bearer

**请求体：**

```json
{ "dialog_id": "dialog-abc" }
```

::: warning 级联删除
删除对话会**级联删除**该对话下的所有消息历史（`histories` 表）。管理员（user_id=1）可删除任意用户的对话。
:::

## 对话状态更新

```
POST /api/v1/dialog/status
```

**认证：** Bearer

**请求体：**

```json
{
  "dialog_id": "dialog-abc",
  "is_favorite": true,
  "is_important": false
}
```

切换收藏（star）/ 重要（flag）标记。

## 对话消息列表

```
GET /api/v1/message/list/{dialog_id}
```

**认证：** Bearer

**响应：** 返回该对话的全部消息，按时间正序。

## 对话历史

```
GET /api/v1/history?dialog_id=dialog-abc
```

**认证：** Bearer

与 `/message/list/{dialog_id}` 数据相同，按时间排序的历史消息。

## 消息点赞 / 反对

```
POST /api/v1/message/like
POST /api/v1/message/down
```

**请求体：**

```json
{
  "user_input": "用户的问题",
  "agent_output": "AI 的回答"
}
```

记录用户对 AI 回复的反馈，用于质量评估。

## 相关文档

- [开发指南 · 聊天与流式](../development/chat-streaming) — SSE 原理与流程
- [图像理解 API](./image) — 视觉问答
- [积分 API](./points) — 对话扣费机制
- [LLM 配置](../configuration/llm) — 模型与降级
