# 本地启动

本页指导你在本地把 VibeBase 的后端和前端跑起来，并验证各端能正常工作。假设你已完成 [获取源码与安装](./installation)。

## 启动顺序

::: danger 启动顺序很重要
必须按以下顺序启动，否则后端连不上数据库会报错：

1. **PostgreSQL + Redis**（中间件）
2. **VibeBase 后端**（FastAPI :8081）
3. **VibeBase 前端**（Vite :5175）
:::

## 方式一：一键启动脚本（推荐）

VibeBase 根目录提供了 `start_dev.sh` 一键启动脚本，会同时拉起后端和前端：

```bash
cd VibeBase
bash start_dev.sh
```

启动后：

- 后端 API：http://localhost:8081
- API 文档（Swagger）：http://localhost:8081/docs
- 前端界面：http://localhost:5175

::: tip 前提
`start_dev.sh` 假设 PostgreSQL（:5433）和 Redis（:6379）已经在运行。请先用 [安装文档](./installation#_5-启动中间件) 中的方式启动中间件。
:::

## 方式二：手动分别启动

如果你想分开启动（便于看各自日志），按下面操作。

### 1. 启动中间件

确保 PostgreSQL 和 Redis 已运行：

```bash
# 用 docker-compose（在 vibe-base 目录）
cd VibeBase/vibe-base
docker-compose up -d
```

验证：

```bash
# 验证 PostgreSQL（会提示输入密码，开发环境密码是 vibe）
psql -h localhost -p 5433 -U vibe -d vibe -c "SELECT 1;"

# 验证 Redis
redis-cli ping    # 应返回 PONG
```

### 2. 启动后端

::: code-group

```bash [Poetry]
cd VibeBase/vibe-base
poetry run python main.py
```

```bash [pip / venv]
cd VibeBase/vibe-base
source .venv/bin/activate
python main.py
```

:::

后端启动后，你会看到类似的日志：

```
INFO:     Uvicorn running on http://0.0.0.0:8081
INFO:     Application startup complete.
```

后端启动时会自动：

1. 读取 `config/config.{ENV}.yaml`（默认 `config.dev.yaml`）
2. 初始化数据库（`Base.metadata.create_all`，自动建表）
3. 写入种子数据（默认 AI 能力 AB001 ~ AB006）

::: warning 首次启动
首次启动会比较慢（需要建表 + 种子数据）。如果看到数据库连接错误，请检查 [数据库配置](../configuration/database)。
:::

### 3. 启动前端

新开一个终端：

```bash
cd VibeBase/vibe-base-web
npm run dev
```

启动后访问 http://localhost:5175 。

::: tip Vite 开发代理
`vite.config.ts` 配置了代理，前端 `/api` 请求会被转发到后端 `:8081`，所以本地开发不会有跨域问题。
:::

## 验证启动成功

### 1. 后端健康检查

```bash
curl http://localhost:8081/health
# 期望返回: {"status":"OK"}
```

### 2. 访问 API 文档

浏览器打开 http://localhost:8081/docs ，能看到完整的 Swagger 接口文档说明后端正常。

### 3. 前端界面

浏览器打开 http://localhost:5175 ，应该能看到 VibeBase 的 Landing 首页。

### 4. 注册并登录

1. 点击右上角「免费注册」
2. 完成注册（首个注册的用户会成为管理员，user_id = 1）
3. 登录后进入控制台 `http://localhost:5175/#/app/console/dashboard`

::: tip dev-login 快捷登录
开发环境下，可以用 `/api/v1/user/dev-login` 快速获取管理员 Token（仅当 `ENVIRONMENT != production`）：

```bash
curl -X POST http://localhost:8081/api/v1/user/dev-login
```
:::

## 测试 AI 对话

AI 对话需要配置 LLM API Key 才能真正对话，否则会返回降级提示。

### 已配置 API Key

1. 在 `.env` 中填写 `OPENAI_API_KEY`
2. 重启后端
3. 在控制台进入对话，发送消息，应收到流式 AI 回复

### 未配置 API Key

也能发送消息，但会收到一段降级提示文案（不扣积分）。详见 [LLM 模型配置](../configuration/llm)。

## 启动其他端（可选）

### VibeAdmin 运营后台

```bash
# 后端
cd VibeAdmin/vibe-admin
python run_server.py

# 前端
cd VibeAdmin/vibe-admin-web
pnpm install && pnpm dev
```

详见 [多端协作 · VibeAdmin](../multi-end/vibeadmin)。

### Vibe-Mp-H5 小程序

```bash
cd Vibe-Mp-H5
pnpm install
pnpm dev:h5      # H5 模式
pnpm dev:mp      # 微信小程序模式
```

详见 [多端协作 · Vibe-Mp-H5](../multi-end/vibe-mp-h5)。

## 停止服务

```bash
# 停止前后端：在对应终端按 Ctrl + C

# 停止中间件
cd VibeBase/vibe-base
docker-compose down
```

## 常见问题

### Q：后端启动报 `connection refused` 或数据库错误？

1. 确认 PostgreSQL 在运行：`psql -h localhost -p 5433 -U vibe -d vibe -c "SELECT 1;"`
2. 检查 `.env` 中 `DATABASE_URL` 的端口、用户名、密码是否正确
3. 确认数据库 `vibe` 已创建

### Q：前端打开是白屏？

1. 打开浏览器开发者工具看 Console 报错
2. 确认后端已启动（前端依赖后端 API）
3. 检查 `.env` 中 `VITE_API_BASE_URL` 是否指向正确的后端地址

### Q：对话返回「模型调用失败」？

说明 LLM 未正确配置。检查 `.env`：

- `OPENAI_API_KEY` 是否为真实 Key（不是占位符）
- `OPENAI_BASE_URL` 是否可达
- `OPENAI_MODEL` 模型名是否正确

详见 [LLM 模型配置](../configuration/llm)。

### Q：注册时提示「邀请码无效」？

注册需要有效的邀请码。开发环境可用 `dev-login` 跳过，或在数据库 `invitation_codes` 表手动插入邀请码。

## 接下来

服务跑起来后，前往 [首次配置](./first-config) 完善配置（LLM、支付、存储等）。

## 相关文档

- [获取源码与安装](./installation)
- [首次配置](./first-config)
- [配置总览](../configuration/backend)
