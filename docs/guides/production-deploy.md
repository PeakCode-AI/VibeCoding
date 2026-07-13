# 生产环境部署方案

> 本文记录 VibeCoding(VibeAdmin + VibeBase)的 Docker 生产部署方案,作为部署执行的依据与日后复盘参考。
> 制定日期:2026-07-13。访问方式:**IP + 端口,HTTP**(HTTPS 后续追加)。

## 1. 部署目标

把 VibeAdmin(运营后台)+ VibeBase(C 端用户产品)及各自前端、Redis、对象存储,用 Docker Compose 部署到生产服务器,连接服务器同机的已有 PostgreSQL。**本地开发环境完全不受影响**(本地继续用 `docker-compose.middleware.yml` 的 PG:5433/Redis:6379)。

| 项 | 值 |
| --- | --- |
| 生产服务器 | `118.31.224.254`(SSH `root`,内网 IP `172.29.72.219`) |
| 数据库 | 服务器同机 PostgreSQL,`172.29.72.219:5432`,库 `vibeadmin`,用户 `vibeadmin` |
| 部署方式 | Docker Compose,全部容器在单一 network |
| 访问方式 | `http://118.31.224.254:<端口>`,HTTP |

## 2. 访问端口

| 服务 | URL | 容器内 | 说明 |
| --- | --- | --- | --- |
| VibeAdmin 前端 | `http://118.31.224.254` | Nginx:80 | `/api/` 反代到 vibeadmin-backend:8080 |
| VibeBase 前端 | `http://118.31.224.254:8082` | Nginx:80→主机8082 | `/api/` 反代到 vibebase-backend:8081 |
| VibeAdmin 后端 | `http://118.31.224.254:8080` | 8080 | FastAPI,`/health` 健康检查 |
| VibeBase 后端 | `http://118.31.224.254:8081` | 8081 | FastAPI,`/health` 健康检查 |
| Redis | 容器内部 | 6379 | 不对外暴露 |
| MinIO | `http://118.31.224.254:9001`(控制台) | 9000/9001 | 对象存储(如启用) |

## 3. 部署拓扑

```
服务器 118.31.224.254 (= 内网 172.29.72.219)
├── PostgreSQL(已存在,库 vibeadmin,监听 :5432)  ← 容器经 host.docker.internal:5432 连接
└── docker network: vibe-prod
    ├── redis          (:6379 容器内)
    ├── minio          (:9000/9001) + minio-init(建桶 vibe-storage)
    ├── vibeadmin-backend (:8080)  ── 依赖 redis
    ├── vibebase-backend  (:8081)  ── 依赖 redis
    ├── vibeadmin-web     (:80→主机80)  nginx 反代 /api/ → vibeadmin-backend:8080
    └── vibebase-web      (:80→主机8082) nginx 反代 /api/ → vibebase-backend:8081
```

**关键点**:两后端共享同一数据库 `vibeadmin`,需使用**同一个** `SECRET_KEY`(JWT 跨服务互认)。

## 4. 凭据处理原则(安全)

- 生产密钥(DB 密码、JWT SECRET_KEY、S3 密钥、支付密钥)全部写入 `deploy/prod/.env.production`。
- **该文件被 `.gitignore` 忽略,绝不提交、绝不推送**;通过 `scp` 上传到服务器。
- 仓库内只保留 `deploy/prod/.env.production.example`(占位值)供参考。
- SSH 密码仅存在于执行部署者的本地会话,不写入任何文件。
- compose 通过 `env_file: .env.production` 或 `environment` 引用,不在 compose 文件里硬编码明文。

> ⚠️ **安全提示**:本次部署的 DB 密码已出现在沟通记录中。**部署完成后建议更换数据库密码**并同步更新 `.env.production`。

## 5. 数据初始化

后端容器**首次启动时自动建表**,无需手动迁移:

| 系统 | 自动行为 | 说明 |
| --- | --- | --- |
| VibeAdmin | 建全表 + 创建超级管理员 `admin@example.com / admin123`(role=super_admin) | 由 `app/main.py` lifespan 调 `init_db()` |
| VibeBase | 建全表 + 灌入 6 条默认 AI ability(对话/图像/语音等基础设施数据) | 由 `main.py` lifespan 调 `init_database()` |

**不灌演示 seed 数据**(`seed_data.py` / `SEED_DB_ON_STARTUP=False`),生产环境保持干净。

> 因两后端共享 metadata,启动顺序上 VibeAdmin 先建表即可,VibeBase 启动时表已存在会跳过建表、仅补 ability 数据(幂等)。

## 6. 实施步骤

### 6.1 本地准备
1. 在仓库创建 `docs/guides/production-deploy.md`(本文)。
2. 创建 `deploy/prod/docker-compose.prod.yml`(生产编排,可入库)。
3. 创建 `deploy/prod/.env.production.example`(占位,可入库)与 `deploy/prod/.env.production`(真实密钥,不入库)。
4. `.gitignore` 追加 `deploy/prod/.env*`(保留 `.env.production.example`)。

### 6.2 探测服务器环境(只读,失败则停下汇报)
SSH 到 `118.31.224.254`,确认:
- OS / CPU 架构(`uname -a`)
- Docker & Docker Compose 是否已安装(`docker version`、`docker compose version`)
- 数据库连通性(`pg_isready -h 127.0.0.1 -p 5432 -U vibeadmin` 或 `psql` 探测)
- 端口占用(`80 / 8082 / 8080 / 8081 / 6379 / 9000` 是否被占)
- 服务器是否能访问 GitHub(决定代码同步方式)

### 6.3 同步代码与配置到服务器
- **首选**:服务器 `git clone` 各仓库到 `/opt/vibe`(若能访问 GitHub)。
- **兜底**:`rsync` 本地源码(排除 `.git / node_modules / .env / venv / dist`)。

上传 `deploy/prod/` 到服务器 `/opt/vibe/deploy/prod/`。

### 6.4 构建并启动
```bash
cd /opt/vibe
docker compose -f deploy/prod/docker-compose.prod.yml --env-file deploy/prod/.env.production up -d --build
```
等待所有 healthcheck 转 healthy。

### 6.5 验证
- `curl http://118.31.224.254:8080/health`(VibeAdmin 后端)→ `{"status":"healthy"}`
- `curl http://118.31.224.254:8081/health`(VibeBase 后端)→ `{"status":"OK"}`
- 浏览器访问 `http://118.31.224.254`,用 `admin@example.com / admin123` 登录 VibeAdmin。
- 浏览器访问 `http://118.31.224.254:8082`,看到 VibeBase 首页。
- 进数据库查表:`psql` 或 PG 容器 `\dt` 确认表已建、超管已建。

### 6.6 端口放行提示
若外网访问不通,需在**阿里云控制台安全组**放行:`80、8082、8080、8081`(9001 可选)。我会提示你手动放行。

## 7. 风险与回滚

- **本地零影响**:所有改动只新增 `deploy/prod/` 与本文档,不改本地现有配置/端口。
- **回滚**:`docker compose -f deploy/prod/docker-compose.prod.yml down` 清理容器;数据库已存在不重建,不动数据。
- **失败点**:服务器无 Docker(需先装)、DB 端口/密码不对、安全组未放行 —— 每步先探测再执行,失败即停汇报。

## 8. 本次不做的事

- 不改本地任何现有配置/端口。
- 不提交任何密码到 git。
- 不配 HTTPS(以后加 Let's Encrypt)。
- 不部署 VibeApp / Vibe-Mp-H5(本次范围外)。
- 不灌演示 seed 数据。

## 9. 相关文件

- 编排:`deploy/prod/docker-compose.prod.yml`
- 凭据模板:`deploy/prod/.env.production.example`
- 凭据(不入库):`deploy/prod/.env.production`
- 本地中间件参考:`docker-compose.middleware.yml`
- 部署指南(各端通用):`docs/guides/deployment.md`
