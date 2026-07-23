# 模型代理端到端验证

本文档演示如何验证「VibeAdmin 配置 LLM 供应商 → VibeBase 代理端点转发 → 移动端调用」的完整链路。

## 前置准备

### 1. 生成 MASTER_KEY

VibeAdmin 与 VibeBase 必须使用**同一** MASTER_KEY（用于加解密 llm_providers.api_key_enc）。

```bash
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
# 输出形如：abcdef123456...=
```

### 2. 配置 .env

**VibeAdmin/vibe-admin/.env**:
```bash
MASTER_KEY=上一步生成的字符串
DATABASE_URL=postgresql+asyncpg://vibe:vibe@localhost:5432/vibe
# 其他...
```

**VibeBase/vibe-base/.env**:
```bash
MASTER_KEY=同上（必须一致）
DATABASE_URL=postgresql+asyncpg://vibe:vibe@localhost:5432/vibe
# 其他...
```

> 如果 VibeBase 不配置 MASTER_KEY，加解密会抛 `CryptoError`，代理端点返回 503。

### 3. 启动服务

```bash
# 中间件
docker compose -f /Users/jwangkun/Coding/VibeCoding/docker-compose.middleware.yml up -d

# VibeAdmin 后端
cd /Users/jwangkun/Coding/VibeCoding/VibeAdmin/vibe-admin
.venv/bin/python run_server.py  # :8080

# VibeAdmin 前端
cd /Users/jwangkun/Coding/VibeCoding/VibeAdmin/vibe-admin-web
pnpm dev  # :5173

# VibeBase 后端
cd /Users/jwangkun/Coding/VibeCoding/VibeBase/vibe-base
.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8081 --reload

# VibeBase 前端（可选，用于在 Web 申请 API Key）
cd /Users/jwangkun/Coding/VibeCoding/VibeBase/vibe-base-web
npm run dev  # :5175
```

## 步骤一：在 VibeAdmin 配置 LLM 供应商

1. 浏览器打开 http://localhost:5173，用 `admin@example.com / admin123` 登录
2. 左侧菜单 → **API 运营** → **模型供应商**（新增菜单）
3. 点击「+ 新增供应商」，填写：
   - 名称：`Deepseek 官方`
   - 供应商类型：`deepseek`
   - Base URL：`https://api.deepseek.com/v1`
   - API Key：你的 Deepseek 真实 Key（明文填入，入库后加密）
   - 模型列表：添加 `deepseek-chat`、`deepseek-reasoner`
   - 默认模型：`deepseek-chat`
   - 优先级：`10`
4. 点击「创建」
5. 在列表里点「测试」按钮验证连通性（应返回「连接成功 · XXXms」）

## 步骤二：在 VibeBase 申请 vb-xxx API Key

### 方式 A：通过 Web UI

1. 浏览器打开 http://localhost:5175，注册并登录
2. 控制台 → API Key → 新建 Key → 复制 `vb-xxxxxxxx...`

### 方式 B：通过 API

```bash
# 注册（如未注册）
curl -X POST http://localhost:8081/api/v1/user/register \
  -H "Content-Type: application/json" \
  -d '{"user_name":"testuser","user_email":"test@example.com","user_password":"test123456"}'

# 登录拿 JWT
TOKEN=$(curl -s -X POST http://localhost:8081/api/v1/user/login \
  -H "Content-Type: application/json" \
  -d '{"user_account":"testuser","user_password":"test123456"}' | python -c "import sys,json;print(json.load(sys.stdin)['data']['access_token'])")

# 申请 API Key
API_KEY=$(curl -s -X POST http://localhost:8081/api/v1/api-keys \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"移动端测试"}' | python -c "import sys,json;print(json.load(sys.stdin)['data']['full_key'])")

echo "你的 vb-xxx Key: $API_KEY"
```

## 步骤三：用 vb-xxx Key 调用 OpenAI 兼容代理

### 流式调用（OpenAI 风格 SSE）

```bash
curl -N http://localhost:8081/v1/chat/completions \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-chat",
    "messages": [{"role":"user","content":"用一句话介绍自己"}],
    "stream": true
  }'
```

预期输出：
```
data: {"id":"chatcmpl-...","object":"chat.completion.chunk","created":...,"model":"deepseek-chat","choices":[{"index":0,"delta":{"content":"你好"},"finish_reason":null}]}

data: {"id":"chatcmpl-...","object":"chat.completion.chunk","created":...,"model":"deepseek-chat","choices":[{"index":0,"delta":{},"finish_reason":"stop"}],"usage":{"prompt_tokens":12,"completion_tokens":8,"total_tokens":20}}

data: [DONE]
```

### 非流式调用

```bash
curl http://localhost:8081/v1/chat/completions \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-chat",
    "messages": [{"role":"user","content":"hi"}],
    "stream": false
  }'
```

### 列出可用模型

```bash
curl http://localhost:8081/v1/models
```

预期：
```json
{
  "object": "list",
  "data": [
    {"id":"deepseek-chat","object":"model","created":0,"owned_by":"Deepseek 官方"},
    {"id":"deepseek-reasoner","object":"model","created":0,"owned_by":"Deepseek 官方"}
  ]
}
```

## 步骤四：用 openai SDK 调用（移动端/任何 OpenAI 客户端）

### Python

```python
from openai import OpenAI

client = OpenAI(
    api_key="vb-你的key",
    base_url="http://localhost:8081/v1",
)

# 流式
stream = client.chat.completions.create(
    model="deepseek-chat",
    messages=[{"role": "user", "content": "你好"}],
    stream=True,
)
for chunk in stream:
    if chunk.choices and chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="")
print()

# 非流式
resp = client.chat.completions.create(
    model="deepseek-chat",
    messages=[{"role": "user", "content": "hi"}],
)
print(resp.choices[0].message.content)
print(f"usage: {resp.usage}")
```

### Dart（Flutter）

```dart
import 'package:openai/openai.dart';

OpenAI.apiKey = 'vb-你的key';
OpenAI.baseUrl = 'http://localhost:8081/v1';

final chat = await OpenAI.instance.chat.create(
  model: 'deepseek-chat',
  messages: [
    OpenAIChatCompletionChoiceMessageModel(
      role: OpenAIChatMessageRole.user,
      content: '你好',
    ),
  ],
);
print(chat.choices.first.message.content);
```

## 步骤五：在 VibeAdmin 查看调用统计

1. 浏览器打开 http://localhost:5173/api-logs
2. 顶部汇总卡应显示：总调用次数、总 Token 消耗、总积分消耗、失败次数
3. 表格新增列：`模型` / `Prompt` / `Completion` / `Total`
4. 也可调聚合接口：

```bash
ADMIN_TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"admin123"}' | python -c "import sys,json;print(json.load(sys.stdin)['data']['access_token'])")

curl "http://localhost:8080/api/v1/api-logs/summary?group_by=model" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

预期返回：
```json
{
  "total_calls": 3,
  "total_tokens": 156,
  "total_points": 15,
  "failed_calls": 0,
  "by_day": [],
  "by_model": [
    {"model": "deepseek-chat", "calls": 3, "tokens": 156, "points": 15}
  ],
  "by_user": []
}
```

## 故障排查

| 现象 | 原因 | 解决 |
| --- | --- | --- |
| 401 `Invalid API key` | vb-xxx Key 不存在或被禁用 | 重新申请 Key 或在 Web 端启用 |
| 402 `Insufficient points balance` | 积分余额不足 | 在 VibeBase Web 充值积分 |
| 503 `No LLM provider configured` | VibeAdmin 没配供应商或被禁用 | 在 VibeAdmin 模型供应商页配置并启用 |
| 502 `Upstream error` + 解密失败日志 | VibeAdmin 与 VibeBase 的 MASTER_KEY 不一致 | 检查两端 .env 的 MASTER_KEY |
| 拿不到 token usage（prompt/completion 都是 0） | LLM 供应商不支持 `stream_options.include_usage` | 代理端已做兼容降级，记 0 不报错 |

## 架构回顾

```
移动端 (vb-xxx Key)
    │
    ▼
VibeBase /v1/chat/completions  ←── 鉴权 vb-xxx + 扣积分 + 记 api_log
    │
    ├── 解密 llm_providers.api_key_enc → 真实 Deepseek Key
    │
    ▼
真实 LLM (api.deepseek.com)
    │
    ▼ (流式回传 OpenAI SSE)
VibeBase → 移动端
    │
    └── 写 api_logs (model_name + prompt/completion/total_tokens)

VibeAdmin 读取同一 api_logs 表 → 调用日志页 + 汇总卡 → 统计用户消耗
```

真实 LLM API Key 永不下发到客户端；客户端只持有 VibeBase 签发的 vb-xxx Key。
