# Nginx 反向代理

VibeBase 生产部署中，Nginx 承担两个角色：托管前端静态资源 + 反向代理后端 API。本页是 Nginx 配置的完整指南。

## 为什么需要 Nginx

| 职责 | 说明 |
| --- | --- |
| 托管前端 | Vue 构建产物（`dist/`）是静态文件，Nginx 直接服务 |
| 反向代理 | 将 `/api/` 请求转发到后端 FastAPI（:8081） |
| SSE 支持 | 对话流式响应需要特殊配置 |
| HTTPS 终止 | 集中处理 SSL 证书 |
| 负载均衡 | 多 worker / 多实例时分发请求 |
| gzip 压缩 | 减少传输体积 |

## 完整配置

```nginx
# /etc/nginx/conf.d/vibebase.conf

# 后端上游（多实例可在此负载均衡）
upstream vibebase_backend {
    server 127.0.0.1:8081;
    # server 127.0.0.1:8082;  # 横向扩展时加
    keepalive 32;
}

server {
    listen 80;
    server_name your-domain.com www.your-domain.com;

    # HTTP 跳转 HTTPS（配置 SSL 后启用）
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com www.your-domain.com;

    # SSL 证书
    ssl_certificate     /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    # 前端静态资源
    root /var/www/vibebase;
    index index.html;

    # gzip 压缩
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    gzip_min_length 1000;

    # SPA 回退（hash 模式其实不需要，但作兜底）
    location / {
        try_files $uri $uri/ /index.html;
        add_header Cache-Control "no-cache";
    }

    # 静态资源长缓存（带 hash 的 js/css）
    location ~* \.(?:js|css|png|jpg|jpeg|gif|ico|svg|woff2?)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # ★ API 反向代理
    location /api/ {
        proxy_pass http://vibebase_backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # ★★★ SSE 流式必需配置 ★★★
        proxy_buffering off;       # 关闭缓冲，让流实时推送
        proxy_cache off;           # 关闭缓存
        proxy_read_timeout 300s;   # 长连接超时（深度研究可能很久）

        # WebSocket 支持（预留，虽然 VibeBase 用 SSE）
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # 文件上传大小限制（头像 ≤5MB，留余量）
    client_max_body_size 10M;
}
```

## SSE 配置详解

::: danger 最关键的配置
对话接口 `/api/v1/chat` 返回 `text/event-stream`（SSE）。如果 Nginx 缓冲响应，用户会看到「一直转圈、最后一次性出现全部文字」而非逐字输出。

必须配置：
```nginx
proxy_buffering off;
proxy_cache off;
```
:::

### 为什么默认会有问题

Nginx 默认会**缓冲**后端响应，等攒够一定大小再发给客户端（提升吞吐）。这对普通 HTTP 是优化，但对 SSE 是灾难——流被攒在 Nginx 里，客户端收不到。

| 配置 | 默认 | SSE 场景 | 说明 |
| --- | --- | --- | --- |
| `proxy_buffering` | on | **off** | 关闭响应缓冲 |
| `proxy_cache` | off | off | 关闭缓存 |
| `proxy_read_timeout` | 60s | **300s** | 深度研究耗时较长 |

## 多实例负载均衡

当单机性能不足时，可启动多个后端实例：

```nginx
upstream vibebase_backend {
    # 最少连接策略（适合长连接的 SSE）
    least_conn;
    server 127.0.0.1:8081;
    server 127.0.0.1:8082;
    server 127.0.0.1:8083;
    keepalive 32;
}
```

::: warning SSE 与负载均衡
SSE 是长连接。负载均衡策略建议用 `least_conn`（最少连接），避免某实例因长连接堆积过载。注意：如果同一对话的多条消息要落到同一实例，需要会话保持（但 VibeBase 每次 `/chat` 是独立请求，无此问题）。
:::

## 与 VibeAdmin 共存

如果同一台服务器同时部署 VibeBase 与 VibeAdmin：

```nginx
# VibeBase
server {
    server_name vibebase.example.com;
    # ... 前端 + /api/ → :8081
}

# VibeAdmin
server {
    server_name admin.example.com;
    root /var/www/vibeadmin;
    location /api/ {
        proxy_pass http://127.0.0.1:8080;
        # ...同样配置
    }
}
```

::: tip 宝塔面板架构
参考项目根目录的部署文档：`www.vibeadmin.cn` 采用宝塔面板 + Nginx 反代架构。
:::

## 客户端 IP 透传

为了让后端拿到真实客户端 IP（而非 Nginx 的 127.0.0.1），必须透传：

```nginx
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
```

后端 `parse_client(request)` 会优先读 `X-Forwarded-For` 首段作为客户端 IP，用于限流与操作日志。

## 常用命令

```bash
# 测试配置语法
sudo nginx -t

# 重新加载（不中断服务）
sudo systemctl reload nginx
# 或
sudo nginx -s reload

# 查看状态
sudo systemctl status nginx

# 查看错误日志
sudo tail -f /var/log/nginx/error.log
```

## 排障

### 对话不逐字输出

确认 `proxy_buffering off`。用 `curl -N` 测试：

```bash
curl -N https://your-domain.com/api/v1/chat ...
# 应该看到逐字输出，而非最后一次性出现
```

### 502 Bad Gateway

后端未启动或端口不对。检查：
- `curl http://127.0.0.1:8081/health`
- Nginx `proxy_pass` 的端口与后端实际端口一致

### 413 Request Entity Too Large

上传文件超限。调大 `client_max_body_size`：

```nginx
client_max_body_size 10M;
```

### 静态资源 404

`root` 路径与前端产物实际位置不一致。确认 `/var/www/vibebase/index.html` 存在。

## 相关文档

- [生产环境部署](./production)
- [域名与 HTTPS](./domain-https)
- [CORS 配置](../configuration/cors)
