# Docker 部署

VibeBase 支持用 Docker / Docker Compose 一键部署，这是最推荐的部署方式。本页涵盖后端、前端的容器化部署。

## 前置准备

- 已安装 Docker 与 Docker Compose
- 服务器至少 2GB 内存（推荐 4GB）
- 已准备好 PostgreSQL 与 Redis（可容器化或使用云服务）

## 架构

生产部署推荐架构：

```
                    ┌──────────────┐
   用户 ────443────▶│   Nginx      │
                    │  反向代理     │
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │ 前端静态  │ │ 后端 API  │ │  (可选)   │
        │ :80/443  │ │ :8081    │ │ VibeAdmin│
        │ Vue dist │ │ FastAPI  │ │  :8080   │
        └──────────┘ └────┬─────┘ └──────────┘
                          │
              ┌───────────┴───────────┐
              ▼                       ▼
        ┌──────────┐            ┌──────────┐
        │PostgreSQL│            │  Redis   │
        │  :5432   │            │  :6379   │
        └──────────┘            └──────────┘
```

## 后端 Docker 部署

### Dockerfile

VibeBase 后端已自带 `vibe-base/Dockerfile`。典型结构：

```dockerfile
FROM python:3.12-slim

WORKDIR /app

# 安装系统依赖（psycopg2 等需要）
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libpq-dev && rm -rf /var/lib/apt/lists/*

# 安装 Python 依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制代码
COPY . .

EXPOSE 8081

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8081"]
```

### 构建镜像

```bash
cd VibeBase/vibe-base
docker build -t vibebase-backend:latest .
```

### 运行

```bash
docker run -d \
  --name vibebase-backend \
  -p 8081:8081 \
  --env-file .env \
  -e ENVIRONMENT=production \
  --restart unless-stopped \
  vibebase-backend:latest
```

::: tip 环境变量
通过 `--env-file .env` 注入环境变量。务必确保生产环境的 `.env`：
- `SECRET_KEY` 已改为随机强密钥
- `DATABASE_URL` 指向生产数据库
- `ENVIRONMENT=production`（禁用 dev-login）
:::

## 前端 Docker 部署

### Dockerfile

前端采用**多阶段构建**（Node 构建 → Nginx 运行），产物约 20MB：

```dockerfile
# 构建阶段
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build:prod

# 运行阶段
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### 构建与运行

```bash
cd VibeBase/vibe-base-web

# 默认 prod 构建
docker build -t vibebase-frontend:latest .

# 指定环境
docker build --build-arg MODE=prod -t vibebase-frontend:prod .

docker run -d \
  --name vibebase-frontend \
  -p 80:80 \
  --restart unless-stopped \
  vibebase-frontend:latest
```

### nginx.conf

前端 Nginx 配置（已含 `vibe-base-web/nginx.conf`）：

```nginx
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # SPA history 模式回退（VibeBase 用 hash 模式，此条作兜底）
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API 反向代理到后端
    location /api/ {
        proxy_pass http://backend:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        # SSE 支持（对话流式必需）
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 300s;
    }
}
```

::: danger SSE 必须关闭缓冲
对话接口用 SSE 流式响应，**必须**在 Nginx 配置 `proxy_buffering off;`，否则流会被缓冲导致用户看不到逐字输出。
:::

## Docker Compose 一键部署

`vibe-base/docker-compose.yml` 已编排好全套服务：

```bash
cd VibeBase/vibe-base
docker-compose up -d
```

启动后：

- 前端：http://localhost
- 后端 API：http://localhost:8081
- API 文档：http://localhost:8081/docs

### 生产 docker-compose 示例

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: vibe
      POSTGRES_PASSWORD: ${PG_STRONG_PASSWORD}
      POSTGRES_DB: vibe
    volumes:
      - pg_data:/var/lib/postgresql/data
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    restart: unless-stopped

  backend:
    build: ./vibe-base
    env_file: ./vibe-base/.env
    environment:
      - ENVIRONMENT=production
      - DATABASE_URL=postgresql+asyncpg://vibe:${PG_STRONG_PASSWORD}@postgres:5432/vibe
      - REDIS_URL=redis://redis:6379/0
    depends_on: [postgres, redis]
    restart: unless-stopped

  frontend:
    build: ./vibe-base-web
    ports:
      - "80:80"
    depends_on: [backend]
    restart: unless-stopped

volumes:
  pg_data:
```

::: warning 注意
- 生产 PG 密码务必用强密码（`${PG_STRONG_PASSWORD}` 从 `.env` 注入）
- 后端不直接暴露端口，只通过前端 Nginx 反代访问
- 数据卷 `pg_data` 保证数据持久化
:::

## 数据持久化

| 数据 | 存储位置 | 持久化方式 |
| --- | --- | --- |
| 业务数据 | PostgreSQL | docker volume `pg_data` |
| 头像文件 | S3 / MinIO | 对象存储（外部） |
| Redis 数据 | Redis | 默认内存（重启丢失，可接受） |

::: tip 备份策略
定期备份 PostgreSQL：
```bash
docker exec <pg_container> pg_dump -U vibe vibe > backup_$(date +%F).sql
```
:::

## 环境变量清单

生产环境 `.env` 关键项：

```bash
ENVIRONMENT=production
SECRET_KEY=<随机强密钥>
DATABASE_URL=postgresql+asyncpg://vibe:<强密码>@postgres:5432/vibe
REDIS_URL=redis://redis:6379/0
OPENAI_API_KEY=<真实key>
OPENAI_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1
OPENAI_MODEL=qwen-plus
PAYMENT_NOTIFY_SECRET=<支付验签密钥>
```

## 健康检查

部署后验证：

```bash
# 后端健康
curl http://localhost:8081/health
# 期望: {"status":"OK"}

# 前端可访问
curl -I http://localhost
# 期望: HTTP/1.1 200

# API 通路（通过前端 Nginx）
curl http://localhost/api/v1/announcement
```

## 常见问题

### Q：前端能打开但 API 404？

检查前端 Nginx 的 `proxy_pass` 是否正确指向后端容器。Docker Compose 中用服务名 `backend:8081`。

### Q：对话没有逐字输出？

Nginx 必须加 `proxy_buffering off;`（见上文 nginx.conf）。否则 SSE 会被缓冲。

### Q：容器重启后数据丢失？

PostgreSQL 没挂载 volume。检查 docker-compose 的 `volumes` 配置。

### Q：后端连不上数据库？

容器间用服务名通信（如 `postgres:5432`），不是 `localhost`。确认 `DATABASE_URL` 用的是服务名。

## 相关文档

- [生产环境部署](./production) — 裸机部署
- [Nginx 反向代理](./nginx) — 详细配置
- [域名与 HTTPS](./domain-https)
- [后端配置](../configuration/backend)
