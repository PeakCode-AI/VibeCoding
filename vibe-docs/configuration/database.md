# 数据库配置

VibeBase 使用 PostgreSQL 作为主数据库，与 VibeAdmin 共享同一实例。本页讲解连接配置、同步/异步双引擎机制，以及表管理。

## 连接配置

数据库连接串在 `.env` 中配置：

```bash
DATABASE_URL=postgresql+asyncpg://vibe:vibe@localhost:5433/vibe
```

### 连接串格式

```
postgresql+asyncpg://<用户名>:<密码>@<主机>:<端口>/<数据库名>
```

| 部分 | 开发默认 | 说明 |
| --- | --- | --- |
| 驱动 | `+asyncpg` | 异步驱动；DAO 层会自动改写为 `+psycopg2`（同步）|
| 用户名 | `vibe` | 数据库角色 |
| 密码 | `vibe` | 开发默认；生产请用强密码 |
| 主机 | `localhost` | 本地开发 |
| 端口 | `5433` | 避开本机 5432（ServBay 等占用） |
| 数据库 | `vibe` | 库名 |

::: tip 为什么端口是 5433
开发环境约定 PG 端口为 `5433`，因为 macOS 上 ServBay / 本机自带的 PG 常占用 5432。`docker-compose.middleware.yml` 也映射到 5433。
:::

## 同步 / 异步双引擎

VibeBase 的数据库访问采用**双引擎策略**，这是理解数据层的关键。

### 两个引擎

```python
# vibe_common/db/ 暴露两个引擎
sync_engine    # 同步引擎（DAO 主力使用）
async_engine   # 异步引擎（vibe_common 内部 + VibeAdmin 使用）
```

它们指向**同一个数据库**，只是驱动不同。

### 自动改写机制

DAO 层以同步 Session 为主：

```python
from vibe_common.db.base import sync_engine
from sqlalchemy.orm import Session

# DAO 内部用同步 Session
with Session(sync_engine) as session:
    user = session.query(User).first()
```

`sync_engine` 在创建时，会自动把连接串里的 `+asyncpg` 改写为 `+psycopg2`：

```
DATABASE_URL 中的:  postgresql+asyncpg://vibe:vibe@localhost:5433/vibe
                         ↓ 自动改写
sync_engine 实际用: postgresql+psycopg2://vibe:vibe@localhost:5433/vibe
```

::: details 为什么这么做
- `vibe_common` 作为共享库，默认为异步场景设计（`asyncpg`）
- VibeBase 的 DAO 层为了代码简单直观，选择同步 SQLAlchemy Session
- 通过连接串自动改写，两边复用同一套 ORM 模型（`vibe_common/models/`），无需维护两份
:::

## 数据库初始化

### 自动建表

后端启动时，`lifespan` 调用 `init_database()`：

```python
# main.py
async def lifespan(app):
    await init_config()
    await init_database()   # ← 这里
    ...

# database/init_data.py
async def init_database():
    Base.metadata.create_all(sync_engine)   # 自动建全部表
    # + 写入种子数据（默认 AI 能力）
```

::: tip create_all 的行为
`create_all` 是**幂等**的：表已存在则跳过，不存在才创建。所以每次启动都调用是安全的。但它**不会**修改已有表结构（加列、改类型需手动迁移）。
:::

### 种子数据

首次启动会写入默认 AI 能力（`database/init_data.py`）：

| ability_id | name | category | point_price |
| --- | --- | --- | --- |
| AB001 | AI 对话 | nlp | 5 |
| AB002 | 文本生成 | nlp | 8 |
| AB003 | 图像生成 | vision | 20 |
| AB004 | 语音合成 | voice | 10 |
| AB005 | 语音识别 | voice | 6 |
| AB006 | OCR 识别 | vision | 12 |

## 共享数据库架构

VibeBase 与 VibeAdmin 共享同一个 `vibe` 数据库，表的所有权划分：

| 表 | 主要使用者 | 说明 |
| --- | --- | --- |
| `users` | 共享 | C 端用户 |
| `roles` / `user_roles` | 共享 | 角色体系 |
| `point_accounts` / `point_transactions` | 共享 | 积分账户与流水 |
| `recharge_orders` | 共享 | 充值订单 |
| `abilities` | 共享 | AI 能力定价 |
| `api_logs` | 共享 | 调用日志 |
| `dialogs` / `histories` | VibeBase | 对话数据 |
| `api_keys` / `sub_accounts` | VibeBase | 开发能力 |
| `tickets` / `feedbacks` | 共享 | 用户支持 |
| `announcements` | 共享 | 公告 |
| `operation_logs` | 共享 | 操作审计 |
| `admin_users` | VibeAdmin | 后台管理员 |
| `tasks` / `system_config` | VibeAdmin | 后台业务 |

所有模型统一定义在 `vibe_common/models/`，共用同一个 `Base.metadata`。

::: tip 为什么共享数据库
- **数据零孤岛** — 用户、订单、工单无需跨服务同步
- **跨服务 Token 互认** — 配合相同 `SECRET_KEY`，VibeBase 与 VibeAdmin 的 JWT 互通
- **运维简单** — 一个 PG 实例备份 / 迁移即可
:::

## 用 Docker 启动 PostgreSQL

推荐用 docker-compose 启动（`vibe-base/docker-compose.yml` 已配置）：

```bash
cd VibeBase/vibe-base
docker-compose up -d
```

::: details 手动创建数据库与用户
如果不用 docker-compose，需要手动初始化：

```sql
-- 用 postgres 超级用户连接
CREATE USER vibe WITH PASSWORD 'vibe';
CREATE DATABASE vibe OWNER vibe;
GRANT ALL PRIVILEGES ON DATABASE vibe TO vibe;
```
:::

## 数据库迁移

VibeBase 目前用 `create_all` 管理表结构，**未集成 Alembic 迁移**。这意味着：

- 新增模型 → 重启后端自动建表 ✅
- 修改已有模型（加列、改类型）→ **需要手动 ALTER TABLE** ⚠️

::: warning Schema 变更需谨慎
按 AGENTS.md 规范：「避免在未更新后端文档/测试的情况下修改 schema」。修改模型字段时：
1. 更新 `vibe_common/models/` 中的模型定义
2. 手动编写对应的 `ALTER TABLE` 语句
3. 同步更新 VibeAdmin（共享同一套模型）
4. 更新相关 API 文档与测试
:::

## 数据库连接池

SQLAlchemy 默认连接池参数（如未显式配置）：

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `pool_size` | 5 | 连接池大小 |
| `max_overflow` | 10 | 超出 pool_size 的最大溢出 |
| `pool_timeout` | 30s | 获取连接超时 |
| `pool_recycle` | -1 | 连接回收周期 |

生产高并发场景建议显式调优。

## 排障

### `connection refused` / `authentication failed`

1. 确认 PG 在运行：`psql -h localhost -p 5433 -U vibe -d vibe -c "SELECT 1;"`
2. 确认 `.env` 的 `DATABASE_URL` 与实际一致
3. 确认用户 `vibe` 有访问 `vibe` 库的权限

### `relation "xxx" does not exist`

表未创建。检查后端启动日志，确认 `init_database()` 执行成功。可能是模型未正确 import 导致 `Base.metadata` 未注册。

### `psycopg2` / `asyncpg` 相关错误

确认两个驱动都已安装（`requirements.txt` 中都有）：

```bash
pip install asyncpg psycopg2-binary
```

## 相关文档

- [后端配置](./backend) — 配置体系总览
- [数据模型](../development/data-models) — 完整表结构
- [Redis 配置](./redis) — 缓存与限流
