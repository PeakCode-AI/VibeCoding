# 生产环境部署

本页指导你在裸机（非 Docker）或云服务器上部署 VibeBase 生产环境。如果你用 Docker，请先看 [Docker 部署](./docker)。

## 部署前清单

::: danger 上线前必须确认
- [ ] `SECRET_KEY` 已改为随机强密钥（且与 VibeAdmin 一致）
- [ ] `ENVIRONMENT=production`（禁用 dev-login 后门）
- [ ] `OPENAI_API_KEY` 已配置真实 Key
- [ ] PostgreSQL 使用强密码
- [ ] 已配置 HTTPS（见 [域名与 HTTPS](./domain-https)）
- [ ] 已更新 CORS 白名单（见 [CORS 配置](../configuration/cors)）
- [ ] 已配置 Nginx 反代的 `proxy_buffering off`（SSE 必需）
:::

## 1. 准备服务器

推荐配置：

| 项 | 最低 | 推荐 |
| --- | --- | --- |
| CPU | 2 核 | 4 核 |
| 内存 | 2 GB | 4 GB |
| 磁盘 | 20 GB | 50 GB SSD |
| 系统 | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS |

## 2. 安装系统依赖

```bash
# Ubuntu / Debian
sudo apt update
sudo apt install -y python3.12 python3.12-venv python3-pip nodejs npm nginx redis-server

# PostgreSQL
sudo apt install -y postgresql postgresql-contrib
```

## 3. 配置 PostgreSQL

```bash
sudo -u postgres psql <<EOF
CREATE USER vibe WITH PASSWORD '你的强密码';
CREATE DATABASE vibe OWNER vibe;
GRANT ALL PRIVILEGES ON DATABASE vibe TO vibe;
EOF
```

::: tip 生产端口
生产环境 PG 通常用默认 5432，不需要像开发那样用 5433。相应地修改 `DATABASE_URL`。
:::

## 4. 部署后端

```bash
# 创建部署目录
sudo mkdir -p /opt/vibebase
sudo chown $USER:$USER /opt/vibebase
cd /opt/vibebase

# 拉取代码
git clone <你的仓库> .

# 后端
cd vibe-base
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# 配置环境变量
cp .env.example .env
# 编辑 .env，填入生产配置
```

### 用 systemd 管理后端

创建 `/etc/systemd/system/vibebase-backend.service`：

```ini
[Unit]
Description=VibeBase Backend (FastAPI)
After=network.target postgresql.service redis-server.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/vibebase/vibe-base
EnvironmentFile=/opt/vibebase/vibe-base/.env
Environment=ENVIRONMENT=production
ExecStart=/opt/vibebase/vibe-base/.venv/bin/uvicorn main:app --host 127.0.0.1 --port 8081 --workers 4
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now vibebase-backend
sudo systemctl status vibebase-backend
```

::: tip workers 数量
`--workers 4` 适合 4 核服务器。一般设为 CPU 核数。注意每个 worker 是独立进程，内存占用会乘以 workers 数。
:::

## 5. 部署前端

```bash
cd /opt/vibebase/vibe-base-web
npm ci
npm run build:prod    # 产物在 dist/
```

将构建产物交给 Nginx：

```bash
sudo mkdir -p /var/www/vibebase
sudo cp -r dist/* /var/www/vibebase/
```

## 6. 配置 Nginx

详见 [Nginx 反向代理](./nginx)。核心配置：

```nginx
server {
    listen 80;
    server_name your-domain.com;
    root /var/www/vibebase;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:8081;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        # SSE 必需
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 300s;
    }
}
```

```bash
sudo nginx -t
sudo systemctl reload nginx
```

## 7. 配置 HTTPS

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

详见 [域名与 HTTPS](./domain-https)。

## 8. 更新 CORS

生产环境需在 `vibe-base/main.py` 的 `register_middleware` 中添加你的域名：

```python
origins = [
    'https://your-domain.com',
    'https://www.your-domain.com',
    # ...保留开发端口用于本地调试
]
```

重启后端生效。详见 [CORS 配置](../configuration/cors)。

## 验证部署

```bash
# 1. 后端健康
curl http://127.0.0.1:8081/health
# {"status":"OK"}

# 2. 通过域名访问
curl https://your-domain.com/api/v1/announcement

# 3. 确认 dev-login 已禁用（应返回 403）
curl -X POST https://your-domain.com/api/v1/user/dev-login

# 4. 测试对话 SSE（需 Token）
curl -N https://your-domain.com/api/v1/chat \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"dialog_id":"test","user_input":"你好"}'
```

## 日志与监控

```bash
# 后端日志
sudo journalctl -u vibebase-backend -f

# Nginx 访问日志
sudo tail -f /var/log/nginx/access.log

# Nginx 错误日志
sudo tail -f /var/log/nginx/error.log
```

::: tip 日志轮转
后端用 loguru，建议配置日志轮转避免日志文件无限增长。
:::

## 性能优化

| 优化项 | 建议 |
| --- | --- |
| uvicorn workers | 设为 CPU 核数 |
| PG 连接池 | `pool_size=10, max_overflow=20` |
| Redis 连接池 | 复用连接，避免频繁建连 |
| Nginx gzip | 开启静态资源压缩 |
| 静态资源缓存 | 前端 dist 配置 long-term cache |
| CDN | 静态资源上 CDN |

## 备份

```bash
# 每日备份 PostgreSQL（加入 crontab）
0 3 * * * pg_dump -U vibe vibe | gzip > /backup/vibe_$(date +\%F).sql.gz

# 保留最近 30 天
find /backup -name "vibe_*.sql.gz" -mtime +30 -delete
```

## 常见问题

### Q：对话接口 502 / 504？

- 502：后端进程挂了，检查 `systemctl status vibebase-backend`
- 504：后端响应超时，检查 `proxy_read_timeout`（SSE 建议至少 300s）

### Q：上传头像 503？

S3 / MinIO 未配置或不可达。检查 `.env` 的 `S3_*` 配置。详见 [对象存储](../configuration/storage)。

### Q：支付回调一直失败？

`PAYMENT_NOTIFY_SECRET` 未配置或与支付网关不一致。详见 [支付配置](../configuration/payment)。

## 相关文档

- [Docker 部署](./docker)
- [Nginx 反向代理](./nginx)
- [域名与 HTTPS](./domain-https)
- [CORS 配置](../configuration/cors)
