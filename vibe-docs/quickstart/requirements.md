# 环境要求

开始之前，请确认你的开发环境满足以下要求。VibeBase 由后端（Python）和前端（Node）两部分组成，并依赖 PostgreSQL 与 Redis 两个中间件。

## 后端要求

| 依赖 | 最低版本 | 推荐版本 | 说明 |
| --- | --- | --- | --- |
| Python | 3.12 | 3.12.x | 使用了 3.12 的语法特性 |
| Poetry | 1.8+ | 最新 | 包管理（推荐）；也可用 pip |
| PostgreSQL | 14+ | 15 / 16 | 主数据库 |
| Redis | 6+ | 7.x | 限流、Token 黑名单 |

::: tip Python 版本必须 ≥ 3.12
项目 `pyproject.toml` 声明了 `python = "^3.12"`。如果你用 pyenv，可以：
```bash
pyenv install 3.12
pyenv local 3.12
```
:::

## 前端要求

| 依赖 | 最低版本 | 推荐版本 | 说明 |
| --- | --- | --- | --- |
| Node.js | 18 | 20 LTS | Vite 6 要求 Node 18+ |
| npm | 9+ | 最新 | 随 Node 安装 |
| pnpm | 8+ | 最新 | 可选，但部分子工程推荐 |

::: warning Node 版本
建议使用 Node 20 LTS。如果你用 nvm：
```bash
nvm install 20
nvm use 20
```
:::

## 中间件

VibeBase 依赖两个中间件，**必须在启动后端之前先运行**：

### PostgreSQL

VibeBase 与 VibeAdmin 共用同一个 PostgreSQL 实例。

- 开发环境端口约定：`5433`（避开本机可能已有的 5432，如 ServBay）
- 默认数据库：`vibe`，用户 `vibe`，密码 `vibe`（仅开发）
- 生产环境请使用强密码

### Redis

用于请求限流（120 次 / 60 秒）与 JWT Token 黑名单（登出撤销）。

- 默认地址：`redis://localhost:6379/0`
- Redis 不可用时后端会**降级放行**（fail-open），不影响主流程

## 端口约定

VibeBase 在开发环境下使用固定端口，已写入后端 CORS 白名单：

| 服务 | 端口 | 说明 |
| --- | --- | --- |
| VibeBase 前端 | `5175` | Vue 开发服务器 |
| VibeBase 后端 | `8081` | FastAPI |
| VibeAdmin 前端 | `5173` | （可选）运营后台 |
| VibeAdmin 后端 | `8080` | （可选）运营后台 |
| Vibe-Mp-H5 前端 | `5174` | （可选）小程序 / H5 |
| PostgreSQL | `5433` | 数据库 |
| Redis | `6379` | 缓存 |

::: danger 修改端口的连带影响
如果你修改了任一前端端口，必须同步更新 `vibe-base/main.py` 中 `register_middleware` 的 `origins` 列表，否则会触发 CORS 跨域错误。
:::

## 可选外部服务

以下服务**不强制要求**，但配置后能解锁完整功能：

| 服务 | 用途 | 不配置的影响 |
| --- | --- | --- |
| OpenAI 兼容 / 通义千问 API Key | AI 对话、图像理解 | 对话走降级提示文案，不扣积分 |
| S3 / MinIO | 头像上传 | 头像上传返回 503，其他功能正常 |
| 支付网关密钥 | 真实支付回调 | 充值回调接口拒绝所有匿名通知 |

::: tip 零配置也能跑
即使不配置任何外部服务，VibeBase 也能正常启动、登录、浏览界面。AI 对话会返回一段降级提示，充值走模拟回调。这让你可以**先看产品全貌，再决定接入哪些服务**。
:::

## 操作系统

VibeBase 在以下系统上经过验证：

- **macOS** — Apple Silicon (arm64) 与 Intel 均可
- **Linux** — Ubuntu 22.04+ / CentOS 8+（生产部署推荐）
- **Windows** — 建议使用 WSL2

## 验证环境

安装完成后，可以用以下命令验证：

```bash
# Python
python --version    # 应输出 3.12.x

# Node
node --version      # 应输出 v20.x

# PostgreSQL
psql --version      # 应输出 14+

# Redis
redis-cli --version # 应输出 6+
```

## 接下来

环境就绪后，前往 [获取源码与安装](./installation)。

## 相关文档

- [获取源码与安装](./installation)
- [本地启动](./local-startup)
- [首次配置](./first-config)
- [数据库配置](../configuration/database)
