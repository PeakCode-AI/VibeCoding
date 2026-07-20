# 聊天与流式

对话是 VibeBase 的核心功能，也是唯一不走 `UnifiedResponseModel` 的接口。`POST /api/v1/chat` 返回 `text/event-stream` 的 SSE 流，逐字推送 LLM 回复。本页覆盖 SSE 协议、事件类型、完整链路、扣费规则与优雅降级。源码在 `api/v1/chat.py` 与 `api/services/chat.py`。

![对话流式响应流程](/diagrams/chat-flow.svg)

## SSE 协议

对话接口返回 `StreamingResponse(generate(), media_type="text/event-stream")`，遵循 SSE（Server-Sent Events）协议：

- 每个事件是 `data: {json}\n\n` 一行
- JSON 结构统一为 `{"type": "<事件类型>", "data": {...}}`
- 流末尾由前端检测 `[DONE]` 终止（VitePress 前端约定）

```http
POST /api/v1/chat HTTP/1.1
Authorization: Bearer <access_token>
Content-Type: application/json

{"dialog_id": "...", "user_input": "你好"}

HTTP/1.1 200 OK
Content-Type: text/event-stream

data: {"type": "llm_start", "data": {"message": "模型响应中..."}}

data: {"type": "response_chunk", "data": {"chunk": "你", "accumulated": "你"}}

data: {"type": "response_chunk", "data": {"chunk": "好", "accumulated": "你好"}}

data: {"type": "llm_end", "data": {"message": "模型响应完成", "usage": {...}, "model": "qwen-plus"}}

data: [DONE]
```

::: info 为什么用 SSE 而非 WebSocket
- 对话只需服务端→客户端单向流，SSE 足够
- 走标准 HTTP，天然过 Nginx / CDN，无需协议升级
- 浏览器原生支持 EventSource 的自动重连
:::

## 事件类型

### 后端核心事件（`api/services/chat.py` 实际产生）

后端 `StreamingAgent` 只产生以下 4 种事件，覆盖基础对话链路：

| 事件类型 | data 字段 | 说明 |
| --- | --- | --- |
| `llm_start` | `{message}` | 流开始，前端可显示「思考中」占位 |
| `response_chunk` | `{chunk, accumulated}` | 一个内容片段 + 累积全文 |
| `llm_end` | `{message, usage, model}` | 流正常结束，`usage` 为 token 用量，`model` 为模型名 |
| `error` | `{message}` | 流异常（如模型调用失败） |

::: tip accumulated 的用途
`accumulated` 是到当前为止的完整文本。前端既可以逐字追加 `chunk`（更流畅），也可以直接用 `accumulated` 覆盖（断流恢复更可靠）。
:::

### 前端扩展事件（`components/chat/Chat.vue` 处理）

VibeBase 前端在 Agent 模式下还监听以下事件类型，用于高级研究/推理/搜索/工具调用流程。这些事件由 Agent 链路在增强模式下产生，前端按 `data.type` 分发渲染：

| 事件类型 | 用途 |
| --- | --- |
| `thinking_start` | 进入深度思考状态，立即展示「思考中」UI |
| `reasoning_chunk` | 推理过程片段（深度思考） |
| `search_start` | 联网搜索开始 |
| `search_results` | 返回搜索结果列表 |
| `search_end` | 搜索阶段结束（深度研究也用它标记完成） |
| `tool_call` | Agent 发起工具调用 |
| `tool_result` | 工具调用返回结果 |
| `plan_ready` | 研究计划就绪 |
| `research_plan` | 研究计划详情 |
| `sources_update` | 引用来源更新 |
| `user_clarification_request` | Agent 反问，请求用户澄清 |
| `points_deducted` | 积分已扣减（前端刷新余额） |
| `points_insufficient` | 积分不足提示 |
| `points_warning` | 积分低余额预警 |

::: warning 事件来源
核心 4 事件（`llm_start`/`response_chunk`/`llm_end`/`error`）是 `api/services/chat.py` 的 `StreamingAgent.ainvoke_streaming` 确定产生的。扩展事件依赖 Agent 增强链路（研究/搜索/推理/工具），基础对话模式下不会全部出现。前端对未匹配类型应静默忽略，保证向前兼容。
:::

## ConversationReq 请求体

对话请求体定义在 `schema/chat.py`：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `user_input` | string | 是 | 用户的问题 |
| `dialog_id` | string | 是 | 对话的 ID 值（关联 `dialogs` 表） |
| `file_url` | string? | 否 | 对话中上传文件的 OSS 链接 |
| `open_search` | bool? | 否 | 是否开启联网搜索（默认 false） |
| `open_reasoning` | bool? | 否 | 是否开启深度思考（默认 false） |
| `open_research` | bool? | 否 | 是否开启研究模式（默认 false） |
| `llm_id` | string? | 否 | 指定使用的 LLM 模型 ID |

## 两种对话模式

| 模式 | 开关 | 行为 |
| --- | --- | --- |
| **对话（chat，默认）** | 三个开关全 false | 单轮问答，走 `StreamingAgent` 直接调 LLM |
| **Agent（自动化）** | 选 Agent 类型 | 自动启用 `open_search` + `open_research` + `open_reasoning`，触发搜索/研究/推理/工具调用链路 |

::: info Agent 模式
Agent 模式（对应 `dialogs.agent_type` 为 `Agent` / `MCPAgent`）会编排多步工具调用与搜索，因此前端会收到 `tool_call`/`search_results`/`plan_ready` 等扩展事件。`MCPAgent` 进一步接入 MCP 协议工具。
:::

## 完整链路：一次对话

以下是一次对话在服务端的完整处理流程（来自 `api/v1/chat.py`）：

```text
1. POST /api/v1/chat 进入 chat 端点
   • Depends(get_login_user) → 得到 login_user (user_id / user_name)
        │
2. 解析能力单价 _resolve_ability_price(DEFAULT_ABILITY_ID)
   • 查 abilities 表（ability_id="AB001"）
   • 查到且 status="up" → 返回 (ability_id, point_price)
   • 查不到 → 用默认值 (AB001, 5)
        │
3. 积分扣费（前置校验，余额不足直接 402，不进入流式）
   if is_llm_configured() and user_id not in ("1", "dev_001"):
       consume_points(user_id, point_price, ability, source_type="dialog",
                      source_id=dialog_id, remark="AI 对话消费")
       余额不足 → raise HTTPException(402, "积分余额不足，请充值后再试")
       其他异常 → 降级为不扣费，继续对话
        │
4. StreamingAgent() + HistoryService.select_history(dialog_id)
   • 加载最近 10 条历史作为上下文
        │
5. 返回 StreamingResponse(generate(), text/event-stream)
   generate() 是异步生成器：
   a. 先持久化用户消息到 histories（role=user）
   b. async for event in chat_agent.ainvoke_streaming(user_input, history):
        yield f'data: {json.dumps(event)}\n\n'
        累积 response_chunk 的 chunk 到 response_content
        记录 llm_end 的 usage / error 到 events
   c. 持久化 AI 回复到 histories（role=assistant, content, events）
   d. 写入 api_logs（积分消耗 / 响应耗时 / 状态）
        │
6. 前端 fetchEventSource 逐字渲染 → 用户看到回复
```

### 后端生成器核心代码

```python
async def generate():
    response_content = ""
    events = []
    call_status = "success"

    # 先存用户消息
    await HistoryService.create_history(User_Role, conversation_req.user_input, [], dialog_id)

    async for event in chat_agent.ainvoke_streaming(conversation_req.user_input, history_messages):
        yield f'data: {json.dumps(event)}\n\n'
        if event["type"] == "response_chunk":
            response_content += event["data"]["chunk"]
        elif event["type"] == "llm_end":
            events.append(event)
        elif event["type"] == "error":
            call_status = "failed"
            events.append(event)
        else:
            events.append(event)

    # 流结束：持久化 AI 回复 + 写日志
    await HistoryService.create_history(Assistant_Role, response_content, events, dialog_id)
    _record_api_log(user_id, user_name, ability_id, point_price,
                    response_ms=int((time.time() - start_time) * 1000), status=call_status)

return StreamingResponse(generate(), media_type="text/event-stream")
```

## 积分扣费规则

对话扣费遵循以下规则（详见 [积分系统](./points-system)）：

| 条件 | 行为 |
| --- | --- |
| LLM 已配置 **且** `user_id` 不在 `("1", "dev_001")` | 调用 `consume_points` 扣减积分 |
| LLM 未配置（`is_llm_configured()` 为 false） | **不扣费**，走降级响应 |
| `user_id` 为 `"1"` 或 `"dev_001"` | **不扣费**（特权账号） |
| `consume_points` 抛 `ValueError("积分余额不足")` | 返回 **HTTP 402**，不进入流式 |
| `consume_points` 抛其他异常 | **降级不扣费**，对话继续（fail open） |

::: warning 扣费在流开始前
积分校验与扣减发生在 `StreamingResponse` 返回**之前**。这样余额不足时可以直接抛 402，避免「流到一半发现没钱」的尴尬。代价是：扣费成功但 LLM 调用失败时**不会自动退款**（当前实现），积分会作为失败调用记入 `api_logs`（status=failed）。
:::

## [DONE] 终止

前端约定：当收到 `data: [DONE]` 时认为流彻底结束，停止读取。这是 SSE 生态的通用终止信号。VibeBase 后端实际产生的终止信号是 `llm_end` 事件，`[DONE]` 由前端配合识别：

```ts
// components/chat/Chat.vue
onmessage(event) {
  if (event.data === '[DONE]') {
    // 流彻底结束
    return
  }
  const data = JSON.parse(event.data)
  switch (data.type) {
    case 'response_chunk': /* 追加字符 */ break
    case 'llm_end':        /* 结束处理 */ break
    case 'error':          /* 错误处理 */ break
    // ...
  }
}
```

## 前端 fetchEventSource 用法

对话是前端唯一不走 axios 的接口，用 `@microsoft/fetch-event-source` 处理 SSE（因为它支持 POST + 自定义请求头，浏览器原生 `EventSource` 只支持 GET）：

```ts
import { fetchEventSource } from '@microsoft/fetch-event-source'

await fetchEventSource('/api/v1/chat', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,      // 手动注入 token
  },
  body: JSON.stringify({
    dialog_id,
    user_input: text,
    open_search,
    open_reasoning,
    open_research,
    llm_id,
  }),
  onopen(response) {
    // 连接建立，可校验 response.ok
  },
  onmessage(event) {
    if (event.data === '[DONE]') return
    const data = JSON.parse(event.data)
    switch (data.type) {
      case 'response_chunk':     // 追加字符
      case 'reasoning_chunk':    // 推理片段
      case 'points_deducted':    // 刷新余额
      case 'points_insufficient':// 提示充值
      // ... 其余扩展事件
    }
  },
  onclose() {
    // 流正常关闭
  },
  onerror(error) {
    // 错误处理，抛出可触发重连
  },
})
```

::: tip 为什么不用原生 EventSource
浏览器原生 `EventSource` 只支持 GET 请求、不能自定义请求头（无法带 `Authorization`）。`@microsoft/fetch-event-source` 基于 fetch，支持 POST + 任意 header + 可控重连，是对话流的正确选择。
:::

## 优雅降级

### LLM 未配置时的降级

当 `OPENAI_API_KEY` / `OPENAI_MODEL` 未配置或为占位符（`your-api-key`、`sk-xxx`、`changeme` 等），`is_llm_configured()` 返回 false。此时 `StreamingAgent` 不抛 500，而是返回可读的降级提示：

```python
async def ainvoke_streaming(self, user_input, history_messages):
    if not self.configured:
        yield {"type": "llm_start", "data": {"message": "模型未配置，返回降级提示"}}
        fallback = (
            "当前后端尚未配置 AI 模型密钥，暂时无法生成真实回复。\n"
            "请在 VibeBase/vibe-base/.env 中设置 OPENAI_API_KEY / OPENAI_BASE_URL / OPENAI_MODEL，"
            "或在 config/config.dev.yaml 的 multi_models.conversation_model 中填入有效配置后重启服务。"
        )
        for ch in fallback:
            yield {"type": "response_chunk", "data": {"chunk": ch, "accumulated": ""}}
        yield {"type": "llm_end", "data": {"message": "降级响应完成", "usage": None, "model": "fallback"}}
        return
    # ...正常调用 LLM...
```

::: info 降级也走完整协议
即使降级，后端依然返回 `llm_start` → `response_chunk` × N → `llm_end` 完整事件序列，前端无需为「无模型」单独编码。
:::

### 模型调用失败

LLM 调用异常时，捕获并返回 `error` 事件，前端展示错误气泡而非整页崩溃：

```python
except Exception as e:
    logger.error(f"LLM call failed: {e}")
    yield {"type": "error", "data": {"message": f"模型调用失败: {str(e)}"}}
```

### 模型配置优先级

`_resolve_model_config()` 的解析优先级：**环境变量 > config.{ENV}.yaml**。

| 配置项 | 环境变量 | YAML 路径 |
| --- | --- | --- |
| API Key | `OPENAI_API_KEY` | `multi_models.conversation_model.api_key` |
| Base URL | `OPENAI_BASE_URL` | `multi_models.conversation_model.base_url` |
| 模型名 | `OPENAI_MODEL` | `multi_models.conversation_model.model_name` |

详见 [配置 · LLM 模型配置](../configuration/llm)。

## 前端预扣费检查

为避免发送后才发现积分不足（402），前端在发送前会调用积分检查接口估算所需积分：

```ts
// 前端估算：输入长度 × 2 作为预估 token 数
const estimatedTokens = userInput.length * 2
await checkPointsSufficientAPI(estimatedTokens)
// 返回 { is_sufficient, token_count, remaining_points }
```

若 `is_sufficient === false`，前端直接提示充值，不再发起对话请求，提升体验。

## 排障

| 症状 | 排查 |
| --- | --- |
| 收到降级提示文本 | `.env` 未配置 `OPENAI_API_KEY`/`OPENAI_MODEL`，或为占位符 |
| 402 积分余额不足 | 余额不足，充值或用 `dev_001` 测试 |
| 流断在中间 | LLM 网关超时，检查 `OPENAI_BASE_URL` 连通性 |
| 前端不渲染 | 检查 `event.data === '[DONE]'` 判断与 `data.type` 分发 |
| 扣了费但回复失败 | 当前实现不自动退款，记录在 `api_logs`（status=failed） |
| Agent 模式无扩展事件 | 基础对话链路只产生核心 4 事件，扩展事件需 Agent 增强 |

## 接下来

- [积分系统](./points-system) — `consume_points` 的完整实现
- [认证机制](./authentication) — `get_login_user` 如何拿到 user_id
- [配置 · LLM 模型配置](../configuration/llm) — 模型配置细节
- [功能指南 · AI 对话](../guide/chat) — 用户侧对话功能
