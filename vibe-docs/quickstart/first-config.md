# 首次配置

本地启动跑通后，本页指导你完成**让产品真正可用**的关键配置。这些配置项分两类：**必须配置**（不配则功能缺失）和**可选配置**（增强体验）。

## 配置文件全景

VibeBase 的配置分散在几处，理解它们的关系是配置的基础：

```
vibe-base/
├── .env                    ← 核心密钥与连接（必看）
├── config/
│   └── config.dev.yaml     ← YAML 配置（白名单、模型、服务信息）
└── vibe_common/core/config.py  ← 配置加载逻辑（读取 .env）
```

::: tip 配置优先级
`vibe_common/core/config.py` 通过 pydantic-settings 读取 `.env`；`settings.py` 读取 `config.{ENV}.yaml`。两者职责不同：
- `.env` 存**密钥与连接串**（敏感、环境相关）
- `config.yaml` 存**业务配置**（白名单、模型名、非敏感参数）
:::

## 必须配置（影响核心功能）

### 1. 数据库连接（默认可用，按需修改）

`.env` 中的 `DATABASE_URL`：

```bash
# 开发默认（docker-compose 启动的 PG）
DATABASE_URL=postgresql+asyncpg://vibe:vibe@localhost:5433/vibe
```

如果你的 PostgreSQL 端口 / 用户 / 密码不同，修改此处。

::: details 连接串格式
```
postgresql+asyncpg://<用户名>:<密码>@<主机>:<端口>/<数据库名>
```
- `+asyncpg` 是异步驱动；DAO 层会自动改写为 `+psycopg2`（同步）使用
- 生产环境务必使用强密码
:::

详见 [数据库配置](../configuration/database)。

### 2. JWT 密钥（默认可用，生产必改）

```bash
SECRET_KEY=vibe-dev-shared-secret-change-in-prod
```

::: danger 生产环境必改
这个默认密钥是开发共享用的（让 VibeBase 和 VibeAdmin 互认 Token）。**生产环境必须替换为随机强密钥**：

```bash
# 生成随机密钥
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

把输出填入 `SECRET_KEY`，并确保 VibeAdmin 使用**相同的** `SECRET_KEY`（否则跨服务 Token 互认失效）。
:::

详见 [JWT 与认证密钥](../configuration/jwt)。

## 可选配置（解锁完整功能）

### 3. AI 对话模型（强烈建议配置）

不配置的话，对话只能返回降级提示。配置后才能真正对话：

```bash
# .env
OPENAI_API_KEY=sk-你的真实key
OPENAI_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1
OPENAI_MODEL=qwen-plus
```

::: info 优雅降级机制
当 `OPENAI_API_KEY` 为空或为占位符（`your-api-key` / `sk-xxx` / `changeme` 等）时，对话接口会：
- 返回一段中文降级提示（"AI 服务暂未配置..."）
- **不扣除积分**
- 不报错

这让你可以在未配置 LLM 时也能演示产品界面。详见 [LLM 模型配置](../configuration/llm)。
:::

### 4. 视觉理解模型（用于图像理解）

```bash
# .env
VL_API_KEY=                  # 留空则回退使用 OPENAI_* 的 Key
VL_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1
VL_MODEL=qwen-vl-plus
```

### 5. Redis（默认可用）

```bash
# .env
REDIS_URL=redis://localhost:6379/0
```

Redis 不可用时后端 fail-open 放行，不阻塞主流程。详见 [Redis 配置](../configuration/redis)。

### 6. 对象存储（头像上传，可选）

头像上传需要 S3 / MinIO。不配置时上传会返回 503，其他功能正常：

```bash
# .env
S3_ENDPOINT=http://localhost:9000
S3_ACCESS_KEY=minioadmin
S3_SECRET_KEY=minioadmin
S3_BUCKET=vibe-storage
S3_PUBLIC_URL=http://localhost:9000/vibe-storage
```

详见 [对象存储配置](../configuration/storage)。

### 7. 支付回调（真实充值，可选）

要对接真实支付网关，需要配置验签密钥：

```bash
# .env
PAYMENT_NOTIFY_SECRET=你的HMAC密钥
```

::: warning 不配置的后果
`PAYMENT_NOTIFY_SECRET` 留空时，`/api/v1/recharge/notify` 端点会**拒绝所有匿名回调**，无法对接真实支付。开发期可用 `/api/v1/recharge/callback` 走模拟回调。
:::

详见 [支付配置](../configuration/payment)。

## 数据库初始化与种子数据

后端首次启动时会自动：

1. **建表** — `Base.metadata.create_all()` 创建全部 20+ 张表
2. **种子数据** — 写入默认 AI 能力（AB001 ~ AB006）

默认种子能力（见 `database/init_data.py`）：

| 能力 ID | 名称 | 类别 | 积分价格 |
| --- | --- | --- | --- |
| AB001 | AI 对话 | nlp | 5 |
| AB002 | 文本生成 | nlp | 8 |
| AB003 | 图像生成 | vision | 20 |
| AB004 | 语音合成 | voice | 10 |
| AB005 | 语音识别 | voice | 6 |
| AB006 | OCR 识别 | vision | 12 |

::: tip 手动重置
如果你想重置数据库，删除对应 schema 后重启后端即可（生产慎用）。开发环境最快：
```bash
# 谨慎！仅开发环境
docker-compose down -v   # 删除 PG 数据卷
docker-compose up -d     # 重启会重新建表 + 种子
```
:::

## 前端配置

前端 `.env` 主要配置后端地址：

```bash
# vibe-base-web/.env
VITE_API_BASE_URL=http://localhost:8081
```

::: tip 开发环境代理
本地开发时，Vite 会代理 `/api` 到后端，所以 `VITE_API_BASE_URL` 留空也能工作。生产部署时需正确指向后端公网地址。
:::

详见 [前端配置](../configuration/frontend)。

## 环境变量速查表

以下是 `.env.example` 中的全部变量，供快速查阅：

| 变量 | 必填 | 默认 / 示例 | 说明 |
| --- | --- | --- | --- |
| `DATABASE_URL` | ✅ | `postgresql+asyncpg://vibe:vibe@localhost:5433/vibe` | 数据库连接串 |
| `REDIS_URL` | ✅ | `redis://localhost:6379/0` | Redis 连接 |
| `SECRET_KEY` | ✅ | `vibe-dev-shared-secret-change-in-prod` | JWT 签名密钥 |
| `OPENAI_API_KEY` | ❌ | — | AI 对话 Key |
| `OPENAI_BASE_URL` | ❌ | `https://dashscope.aliyuncs.com/compatible-mode/v1` | 对话端点 |
| `OPENAI_MODEL` | ❌ | `qwen-plus` | 对话模型 |
| `VL_API_KEY` | ❌ | — | 视觉模型 Key |
| `VL_BASE_URL` | ❌ | `https://dashscope.aliyuncs.com/compatible-mode/v1` | 视觉端点 |
| `VL_MODEL` | ❌ | `qwen-vl-plus` | 视觉模型 |
| `PAYMENT_NOTIFY_SECRET` | ❌ | — | 支付回调验签密钥 |
| `ENVIRONMENT` | ❌ | `dev` | 环境标识（影响 dev-login） |

## 配置加载机制

理解配置如何加载，有助于排障：

```
1. database/__init__.py 用 python-dotenv 加载 .env 到环境变量
        ↓
2. vibe_common/core/config.py (pydantic-settings) 读取环境变量
   → 生成 settings 对象（DATABASE_URL / SECRET_KEY / S3_* 等）
        ↓
3. settings.py 读取 config/config.{ENV}.yaml
   → 生成 app_settings 对象（白名单 / multi_models / server 信息）
        ↓
4. main.py lifespan 启动时：
   await initialize_app_settings()   ← 加载 YAML
   await init_database()              ← 建表 + 种子
```

::: tip 环境隔离
通过 `ENVIRONMENT` 环境变量切换配置文件：
- `ENVIRONMENT=dev` → 读 `config.dev.yaml`
- `ENVIRONMENT=production` → 读 `config.production.yaml`

建议为不同环境维护不同的 `.env` 与 `config.{env}.yaml`。
:::

## 验证配置

完成配置后重启后端，逐项验证：

```bash
# 1. 后端健康
curl http://localhost:8081/health

# 2. AI 对话（需要 Token，先用 dev-login）
TOKEN=$(curl -s -X POST http://localhost:8081/api/v1/user/dev-login | python -c "import sys,json; print(json.load(sys.stdin)['data']['access_token'])")

# 3. 发送一条消息
curl -N http://localhost:8081/api/v1/chat \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"dialog_id":"test","user_input":"你好"}'

# 如果配置了 LLM，会收到流式回复；否则收到降级提示
```

## 接下来

核心配置完成后，你可能想：

- 深入配置细节 → [配置分组](../configuration/backend)
- 开始二次开发 → [开发指南](../development/structure)
- 部署上线 → [部署](../deployment/docker)

## 相关文档

- [本地启动](./local-startup)
- [后端配置](../configuration/backend)
- [LLM 模型配置](../configuration/llm)
- [JWT 与认证密钥](../configuration/jwt)
