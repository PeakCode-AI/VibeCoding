# 后端配置

VibeBase 后端采用**双配置源**设计：`.env` 管理密钥与连接串，`config.{ENV}.yaml` 管理业务参数。本页是后端配置的总览与机制说明。

## 双配置源

```
┌─────────────────────────────────────────────────────┐
│  vibe_common/core/config.py  (pydantic-settings)    │
│  读取 .env → settings 对象                           │
│  • DATABASE_URL / REDIS_URL / SECRET_KEY            │
│  • S3_* / OPENAI_* / VL_* / PAYMENT_NOTIFY_SECRET   │
└─────────────────────────────────────────────────────┘
                        +
┌─────────────────────────────────────────────────────┐
│  settings.py  (YAML 加载)                            │
│  读取 config/config.{ENV}.yaml → app_settings 对象   │
│  • server (project_name / version)                  │
│  • whitelist_paths[]                                │
│  • multi_models (conversation_model ...)            │
│  • redis / llm / response                           │
└─────────────────────────────────────────────────────┘
```

### 何时用哪个

| 类型 | 放在哪 | 原因 |
| --- | --- | --- |
| 密钥、API Key、数据库密码 | `.env` | 敏感、环境相关、不入库 |
| 连接串（DB / Redis / S3） | `.env` | 环境相关 |
| 路由白名单、模型名、服务名 | `config.yaml` | 非敏感、可入库、便于版本管理 |
| 业务开关 | `config.yaml` | 可随代码 review |

## config.yaml 结构

以 `config/config.dev.yaml` 为例：

```yaml
# 服务信息
server:
  project_name: "VibeBase"
  version: "1.0.0"

# 多模型配置（供 services 层调用）
multi_models:
  conversation_model:
    model_name: "qwen-plus"
    api_key: "your-api-key"          # 建议留空，用 .env 的 OPENAI_API_KEY
    base_url: "https://dashscope.aliyuncs.com/compatible-mode/v1"

# 白名单路径（无需认证）
whitelist_paths:
  - /health
  - /api/v1/user/login
  - /api/v1/user/register
  - /api/v1/user/dev-login
  - /api/v1/recharge/notify

# 以下为空对象占位（按需扩展）
redis: {}
llm: {}
response: {}
```

### 字段说明

#### server

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `project_name` | string | FastAPI 应用名（显示在 `/docs` 标题） |
| `version` | string | 应用版本 |

#### multi_models

定义多个模型实例，每个模型对象结构：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `model_name` | string | 模型标识（如 `qwen-plus`） |
| `api_key` | string | API Key（建议留空，走 `.env`） |
| `base_url` | string | OpenAI 兼容端点 |

::: tip 推荐做法
`multi_models` 中的 `api_key` 建议留空或占位，实际的 Key 通过 `.env` 的 `OPENAI_API_KEY` 注入。这样 Key 不会进入 git。
:::

#### whitelist_paths

**字符串前缀列表**。请求路径以任一项开头时，中间件会标记 `request.state.is_whitelisted = True`，认证依赖会放行（视为已登录管理员）。

::: warning 白名单 ≠ 公开
白名单路径跳过的是 **JWT 认证**，不代表完全公开。例如 `/api/v1/recharge/notify` 虽在白名单，但仍有 HMAC 签名校验。
:::

## .env 配置

`.env` 通过 `python-dotenv` 在 `database/__init__.py` 中加载，被 `vibe_common/core/config.py` 的 pydantic-settings 读取。完整变量见 [首次配置的环境变量速查表](../quickstart/first-config#环境变量速查表)。

## 环境隔离

通过 `ENVIRONMENT` 环境变量切换配置：

```bash
# 开发（默认）
ENVIRONMENT=dev python main.py
# → 读取 config/config.dev.yaml

# 生产
ENVIRONMENT=production python main.py
# → 读取 config/config.production.yaml
```

::: tip ENVIRONMENT 的其他作用
`ENVIRONMENT` 还影响：
- **dev-login**：仅在非 `production` 时可用（`/api/v1/user/dev-login`）
- 建议为 dev / staging / production 维护独立的 `.env` 与 `config.{env}.yaml`
:::

## 配置加载流程

```
main.py 启动
    │
    ├─ import database/__init__.py
    │      └─ dotenv.load_dotenv() 把 .env 注入环境变量
    │
    ├─ lifespan(app)
    │      ├─ await initialize_app_settings()
    │      │      └─ settings.py 读取 config.{ENV}.yaml
    │      │         → app_settings 对象（运行期业务配置）
    │      │
    │      └─ await init_database()
    │             └─ Base.metadata.create_all() + 种子数据
    │
    └─ vibe_common/core/config.py（被各处 import）
           └─ pydantic-settings 读取环境变量
              → settings 对象（连接 / 密钥 / 存储配置）
```

## 修改配置后

- **修改 `.env`** → 需**重启后端**（dotenv 只在启动时读取一次）
- **修改 `config.yaml`** → 需**重启后端**（`initialize_app_settings` 只在 lifespan 调用一次）

::: danger 热重载有限
`uvicorn --reload` 只会重载 Python 代码变更，**不会**重新读取 `.env` 或 `config.yaml`。改了配置文件必须手动重启。
:::

## 排障：配置不生效

| 症状 | 排查 |
| --- | --- |
| 后端读到的仍是旧值 | 重启后端（uvicorn --reload 不重读配置文件） |
| `app_settings.whitelist_paths` 为空 | 检查 `config.{ENV}.yaml` 是否存在、`ENVIRONMENT` 是否正确 |
| LLM 走降级 | `.env` 的 `OPENAI_API_KEY` 为空或占位符 |
| `SECRET_KEY` 改了但 Token 失效 | 正常现象——换密钥后所有旧 Token 失效 |

## 子配置专题

接下来每个专题页面深入讲解：

- [数据库配置](./database) — 连接串、双引擎、表自动创建
- [Redis 配置](./redis) — 限流、Token 黑名单
- [LLM 模型配置](./llm) — OpenAI 兼容、优雅降级
- [对象存储配置](./storage) — S3 / MinIO
- [支付配置](./payment) — 回调验签
- [CORS 与跨端](./cors) — 前端端口白名单
- [JWT 与认证密钥](./jwt) — 双 Token、跨服务互通
- [前端配置](./frontend) — Vite 环境变量
