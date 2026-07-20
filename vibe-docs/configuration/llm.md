# LLM 模型配置

VibeBase 的对话能力通过 OpenAI 兼容协议对接任意大模型服务（DashScope / OpenAI / DeepSeek / 本地 vLLM 等）。本页讲解环境变量、优雅降级、积分扣费规则以及视觉模型的回退链。

源码位置：`api/services/chat.py`。

## OpenAI 兼容协议

VibeBase 使用官方 `openai` Python SDK 的 `AsyncOpenAI` 客户端，并采用**流式响应**：

```python
self._client = AsyncOpenAI(api_key=api_key, base_url=base_url or None)
stream = await self._client.chat.completions.create(
    model=self.model,
    messages=[...],
    stream=True,
    stream_options={"include_usage": True},   # 让最后一个 chunk 携带 token 用量
)
```

只要你的服务兼容 `POST /chat/completions`（OpenAI 协议），就可以无缝接入。`stream_options.include_usage=True` 会在流的最后一个 chunk 返回 `usage`（token 用量）。

::: tip 为什么要 include_usage
对话需要按 token 数计费。开启后，最后一个 chunk 会带上 `usage.prompt_tokens / completion_tokens / total_tokens`，便于成本统计与积分结算。
:::

## 环境变量

在 `vibe-base/.env` 中配置：

```bash
# 对话模型
OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxx
OPENAI_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1
OPENAI_MODEL=qwen-plus

# 视觉模型（可选，留空则回退到 OPENAI_*）
VL_API_KEY=
VL_BASE_URL=
VL_MODEL=qwen-vl-plus
```

### 对话模型（OPENAI_*）

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `OPENAI_API_KEY` | （空） | 模型服务 API Key |
| `OPENAI_BASE_URL` | `https://dashscope.aliyuncs.com/compatible-mode/v1` | OpenAI 兼容端点 |
| `OPENAI_MODEL` | `qwen-plus` | 模型标识 |

::: info 默认就是阿里云 DashScope
默认配置面向阿里云百炼（DashScope）的 `qwen-plus` 模型，开箱即用。换其他厂商只需改 `OPENAI_BASE_URL` 与 `OPENAI_MODEL`。
:::

### 视觉模型（VL_*）

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `VL_API_KEY` | （空） | 视觉模型 Key；为空时回退到 `OPENAI_API_KEY` |
| `VL_BASE_URL` | （空） | 视觉模型端点；为空回退到 `OPENAI_BASE_URL` |
| `VL_MODEL` | `qwen-vl-plus` | 视觉模型标识 |

详见下文「视觉模型回退链」。

## 配置解析优先级

`_resolve_model_config()` 按「环境变量 > config.yaml」的优先级解析：

```python
api_key   = os.getenv("OPENAI_API_KEY")   or (cfg.api_key   or "")
base_url  = os.getenv("OPENAI_BASE_URL")  or (cfg.base_url  or "")
model_name = os.getenv("OPENAI_MODEL")    or (cfg.model_name or "")
```

::: tip 建议把 Key 放在 .env
`config/config.dev.yaml` 的 `multi_models.conversation_model.api_key` 虽然也能填 Key，但会进入 git。推荐 yaml 中只放 `model_name`、`base_url`，Key 通过 `.env` 注入。
:::

## 优雅降级

### 占位符检测

`is_llm_configured()` 用来判断模型是否真的可用。它不仅检查「非空」，还排除一组**占位符**：

```python
_PLACEHOLDER_KEYS = {"", "your-api-key", "sk-xxx", "changeme", "none", "null"}

def is_llm_configured() -> bool:
    api_key, _, model_name = _resolve_model_config()
    return (bool(api_key)
            and api_key.strip().lower() not in _PLACEHOLDER_KEYS
            and bool(model_name))
```

命中以下任一情况，都视为「未配置」：

| 值（忽略大小写、首尾空格） | 视为 |
| --- | --- |
| 空字符串 | 未配置 |
| `your-api-key` | 未配置 |
| `sk-xxx` | 未配置 |
| `changeme` | 未配置 |
| `none` | 未配置 |
| `null` | 未配置 |

::: warning 这些占位符是有意设计的
它们正是 `.env.example`、`config.dev.yaml` 模板里给出的默认值。这样开箱即跑时不会真的去调付费接口，而是走降级，避免新人误烧钱。
:::

### 降级行为

未配置时，对话接口**不会**返回 500，而是**流式返回一段中文降级提示**：

```python
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
```

::: danger 降级不扣积分
降级路径**直接 return**，根本不会走到积分扣费逻辑。所以「未配置模型」时即使你疯狂发消息，账户积分也不会减少。这是一个安全网。
:::

降级响应仍是标准的 SSE 事件流，前端无需特殊处理，只是把降级文案当作回复显示出来。

## 系统提示词

固定写死在代码中：

```python
SYSTEM_PROMPT = "你是一个智能助手，请友好地帮助用户解决问题。请用中文回复。"
```

每次请求的 `messages` 数组结构为：

```text
[SystemMessage(SYSTEM_PROMPT)]   ← 固定首位
+ history_messages[-10:]         ← 最近 10 条历史
+ HumanMessage(user_input)       ← 本次输入
```

如需修改人设或语气，直接改 `SYSTEM_PROMPT` 常量（重启生效）。

## 历史窗口

VibeBase 不会把整个对话历史都喂给模型，而是**只取最近 10 条**：

```python
for msg in history_messages[-10:]:
    messages.append(msg)
```

::: info 为什么是 10 条
- 控制 token 成本：历史越长，prompt 越贵
- 大多数多轮对话场景，10 条（约 5 轮）已足够保持上下文
- 前端层面也限制了本地最多保留 100 条历史（见 [前端配置](./frontend)）
:::

## 积分扣费规则

每次成功对话对应一个 AI 能力，默认是 `AB001`（AI 对话，单价 5 积分）：

```python
DEFAULT_ABILITY_ID = "AB001"
DEFAULT_ABILITY_PRICE = 5
```

| 项 | 值 |
| --- | --- |
| 默认 ability_id | `AB001` |
| 能力名 | AI 对话 |
| 单价 | 5 积分 |
| 扣费时机 | 模型成功响应后扣减（降级路径不扣） |

### 谁能跳过扣费

```python
# 内置开发账号跳过积分扣费
if user.user_id in ("1", "dev_001"):
    # 直接走模型，不扣积分
    ...
```

`user_id` 为 `"1"` 或 `"dev_001"` 的账号是**开发账号**，对话不计费，便于联调与压测。

::: danger 切勿在生产保留这两个 ID
生产环境部署前，确保普通用户不会落到这两个 ID。如果是新建数据库，注意不要让自增主键或种子数据产生这两个 ID 的真实用户。
:::

## 视觉模型回退链

视觉（VL）模型的解析采用三级回退，由 `_resolve_model_config()` 实现：

```text
优先：VL_API_KEY / VL_BASE_URL / VL_MODEL （.env）
  └─ 若 VL_API_KEY 为空
       └─ 回退：OPENAI_API_KEY / OPENAI_BASE_URL （复用对话模型的 Key）
            └─ 再退：yaml multi_models.qwen_vl
```

::: tip 常见用法
- **对话与视觉用同一个厂商**：留空 `VL_*`，自动复用 `OPENAI_*`。
- **对话用文本模型，视觉用单独的视觉服务**：单独配置 `VL_API_KEY` / `VL_BASE_URL` / `VL_MODEL`，互不干扰。
:::

视觉模型同样会做占位符检测与降级，行为与对话模型一致。

## 如何切换模型

### 临时切换

改 `.env` 后**重启后端**（`uvicorn --reload` 不会重读 `.env`）：

```bash
# 切换到 DeepSeek
OPENAI_API_KEY=sk-deepseek-xxx
OPENAI_BASE_URL=https://api.deepseek.com/v1
OPENAI_MODEL=deepseek-chat

# 切换到 OpenAI 官方
OPENAI_API_KEY=sk-xxx
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_MODEL=gpt-4o-mini
```

### 永久切换（改默认）

编辑 `config/config.{ENV}.yaml` 的 `multi_models.conversation_model`，更新 `model_name` 与 `base_url`（Key 仍走 `.env`）：

```yaml
multi_models:
  conversation_model:
    model_name: "deepseek-chat"
    base_url: "https://api.deepseek.com/v1"
```

::: warning 前端模型列表是写死的
前端「选择模型」下拉里的 GPT-4 / GPT-3.5 Turbo / DeepSeek 是**前端 mock 静态列表**，与后端实际调用的模型无关。后端实际用的是 `OPENAI_MODEL`。详见 [前端配置](./frontend)。
:::

## 排障

| 症状 | 排查 |
| --- | --- |
| 对话返回「AI 服务暂未配置...」 | `OPENAI_API_KEY` 为空或命中占位符；检查 `.env` 是否加载、是否重启 |
| 对话返回 `模型调用失败: ...` | Key 错误 / `OPENAI_BASE_URL` 不通 / 模型名拼错；查看后端日志 |
| 改了 `.env` 但模型没变 | `--reload` 不重读 `.env`，需手动重启 |
| 前端选了 GPT-4，实际还是 qwen-plus | 前端模型下拉是静态 mock，与后端无关；后端实际模型由 `OPENAI_MODEL` 决定 |
| 一直不扣积分 | 当前账号是 `1` / `dev_001` 开发账号，被跳过计费 |
| 视觉接口报错 | `VL_*` 为空时回退到 `OPENAI_*`；确认回退后的 Key 是否支持视觉模型 |

::: details 自测是否真的接通了模型
不配置 Key 时发对话，应收到中文降级提示（说明降级路径正常）。配置真实 Key 后再发，应收到流式真实回复。两者都没问题，链路就是通的。
:::

## 相关文档

- [后端配置](./backend) — `.env` 与 `config.yaml` 的双配置源
- [前端配置](./frontend) — 前端模型列表 mock 的来源
- [对象存储配置](./storage) — 视觉上传图片的存储后端
