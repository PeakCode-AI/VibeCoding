# 获取源码与安装

本页指导你获取 VibeBase 源码并安装前后端依赖。假设你已完成 [环境要求](./requirements) 的检查。

## 1. 获取源码

VibeBase 是 VibeCoding 工作区的一部分，包含后端、用户端前端、运营后台、App、小程序等多个子工程。

```bash
git clone <你的仓库地址> VibeCoding
cd VibeCoding
```

仓库根目录结构：

```
VibeCoding/
├── VibeBase/          # ← 你需要的：用户端产品
│   ├── vibe-base/     #   后端
│   ├── vibe-base-web/ #   前端
│   └── start_dev.sh   #   一键启动脚本
├── VibeAdmin/         # 运营后台（可选）
├── VibeApp/           # Flutter App（可选）
├── Vibe-Mp-H5/        # 小程序 / H5（可选）
└── vibe-docs/         # 本文档站（可选）
```

::: tip 最低启动组合
只想把 VibeBase 跑起来，只需要 `VibeBase/vibe-base/`（后端）和 `VibeBase/vibe-base-web/`（前端）两个目录。
:::

## 2. 安装后端依赖

VibeBase 后端使用 Python 3.12，支持 Poetry 或 pip 两种安装方式。

### 方式一：Poetry（推荐）

```bash
cd VibeBase/vibe-base

# 安装 Poetry（如未安装）
pip install poetry

# 安装依赖（会自动创建虚拟环境）
poetry install
```

### 方式二：pip

```bash
cd VibeBase/vibe-base

# 建议先创建虚拟环境
python -m venv .venv
source .venv/bin activate    # Windows: .venv\Scripts\activate

# 安装依赖
pip install -r requirements.txt
```

::: details 主要依赖清单
| 包 | 版本 | 用途 |
| --- | --- | --- |
| fastapi | ~0.115.5 | Web 框架 |
| uvicorn | ~0.34.0 | ASGI 服务器 |
| sqlalchemy | ~2.0.32 | ORM |
| sqlmodel | ~0.0.21 | SQLModel 兼容层 |
| pydantic | ~2.11.7 | 数据验证 |
| asyncpg | 0.30.0 | PG 异步驱动 |
| psycopg2-binary | 2.9.10 | PG 同步驱动 |
| redis | 5.2.1 | Redis 客户端 |
| python-jose | 3.3.0 | JWT |
| bcrypt | 4.2.0 | 密码加密 |
| openai | ~1.95.0 | AI 集成 |
| langchain-core | ~0.3.70 | LangChain |
| loguru | ~0.7.2 | 日志 |
:::

## 3. 安装前端依赖

VibeBase 前端使用 npm 或 pnpm。

```bash
cd VibeBase/vibe-base-web

# 方式一：npm
npm install

# 方式二：pnpm（更快，推荐）
pnpm install
```

::: details 主要依赖清单
| 包 | 版本 | 用途 |
| --- | --- | --- |
| vue | ^3.5.13 | 框架 |
| vue-router | ^4.5.0 | 路由 |
| pinia | ^3.0.1 | 状态管理 |
| axios | ^1.10.0 | HTTP |
| tailwindcss | ^4.1.10 | 样式 |
| reka-ui | ^2.6.1 | 无样式组件（shadcn-vue 基座）|
| @microsoft/fetch-event-source | ^2.0.1 | SSE |
| @tiptap/vue-3 | ^3.11.0 | 富文本 |
| marked | ^15.0.12 | Markdown |
| highlight.js | ^11.11.1 | 代码高亮 |
| lucide-vue-next | ^0.514.0 | 图标 |
:::

## 4. 准备配置文件

复制环境变量示例文件：

```bash
# 后端
cd VibeBase/vibe-base
cp .env.example .env

# 前端
cd ../vibe-base-web
cp .env.example .env
```

此时先**不要修改** `.env`，下一节的 [本地启动](./local-startup) 会告诉你需要改哪些。完整配置说明见 [首次配置](./first-config)。

## 5. 启动中间件

在启动前后端之前，必须先启动 PostgreSQL 和 Redis。

### 方式一：Docker（推荐）

如果安装了 Docker，最快的方式是用 docker-compose：

```bash
# 在 vibe-base 目录下（已有 docker-compose.yml）
cd VibeBase/vibe-base
docker-compose up -d            # 启动 PostgreSQL + Redis
```

### 方式二：本地安装

- **macOS**：`brew install postgresql redis && brew services start postgresql redis`
- **Linux (Ubuntu)**：`sudo apt install postgresql redis-server`
- **Windows**：使用对应安装包或 WSL2

::: warning 数据库端口
开发环境约定 PostgreSQL 端口为 `5433`（避开 ServBay 等可能占用 5432 的服务）。如果你的 PG 跑在 5432，请在后端 `.env` 的 `DATABASE_URL` 中相应修改。
:::

## 6. 验证安装

```bash
# 后端目录下，验证 Python 依赖可导入
cd VibeBase/vibe-base
python -c "import fastapi, sqlalchemy, redis; print('后端依赖 OK')"

# 前端目录下，验证 Node 依赖
cd ../vibe-base-web
node -e "console.log('前端依赖 OK')"
```

## 常见问题

### Q：`poetry install` 报 Python 版本不匹配？

`pyproject.toml` 要求 `python = "^3.12"`。请确保：

```bash
python --version    # 必须 3.12+
```

如有多个 Python 版本，用 pyenv 指定：`pyenv local 3.12`。

### Q：`pip install` 报 `psycopg2-binary` 编译失败？

`psycopg2-binary` 是预编译的，一般不需要编译。如果仍失败，确保系统装了 `libpq-dev`（Ubuntu）或 `postgresql-libs`（其他发行版）。

### Q：`npm install` 报 node-sass / esbuild 错误？

通常是 Node 版本过低。升级到 Node 20 LTS：

```bash
nvm install 20 && nvm use 20
rm -rf node_modules package-lock.json
npm install
```

### Q：Windows 下 `psycopg2` / `bcrypt` 安装失败？

建议使用 WSL2 进行后端开发，避免 Windows 原生编译问题。

## 接下来

依赖安装完成后，前往 [本地启动](./local-startup) 把服务跑起来。

## 相关文档

- [环境要求](./requirements)
- [本地启动](./local-startup)
- [首次配置](./first-config)
