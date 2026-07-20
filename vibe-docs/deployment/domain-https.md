# 域名与 HTTPS

生产环境必须配置域名与 HTTPS。本页指导你完成域名解析、SSL 证书申请与 HTTPS 部署。

## 为什么必须 HTTPS

::: danger HTTP 的风险
- **密码明文传输** — 登录请求的密码会被中间人窃听
- **Token 被劫持** — JWT 在 HTTP 下可被嗅探
- **支付不安全** — 支付回调、网关通信必须 HTTPS
- **浏览器限制** — 部分 Web API（如剪贴板、地理位置）仅 HTTPS 可用
- **小程序强制** — 微信小程序要求后端必须 HTTPS
:::

## 域名解析

### 1. 购买域名

在阿里云 / 腾讯云 / Cloudflare 等域名注册商购买域名。

### 2. 添加 DNS 解析

在域名管理后台添加 A 记录：

| 记录类型 | 主机记录 | 记录值 | 说明 |
| --- | --- | --- | --- |
| A | `@` | 你的服务器公网 IP | 主域名 |
| A | `www` | 你的服务器公网 IP | www 子域 |
| A | `api` | 你的服务器公网 IP | （可选）API 独立子域 |

::: tip DNS 生效
DNS 解析通常几分钟到几小时生效。可用 `dig your-domain.com` 或 `nslookup` 验证。
:::

### 3. ICP 备案

::: warning 中国大陆服务器必须备案
如果服务器在中国大陆，域名**必须完成 ICP 备案**才能通过 80/443 端口对外服务。详见 [ICP 备案](./icp-filing)。
:::

## 申请 SSL 证书

### 方式一：Let's Encrypt（免费，推荐）

用 certbot 自动申请与续期：

```bash
# 安装 certbot
sudo apt install certbot python3-certbot-nginx

# 申请证书（会自动修改 Nginx 配置）
sudo certbot --nginx -d your-domain.com -d www.your-domain.com
```

certbot 会：
1. 验证域名所有权
2. 申请证书（保存在 `/etc/letsencrypt/live/your-domain.com/`）
3. 自动修改 Nginx 配置启用 HTTPS
4. 设置自动续期（cron / systemd timer）

::: tip 证书有效期
Let's Encrypt 证书有效期 90 天。certbot 会自动续期（`certbot renew`）。可用 `sudo certbot renew --dry-run` 测试续期。
:::

### 方式二：云服务商免费证书

阿里云 / 腾讯云提供免费 DV 证书（有效期 1 年，需手动续期）：

1. 在云控制台申请免费证书
2. 下载 Nginx 格式证书（`.pem` + `.key`）
3. 上传到服务器
4. 配置 Nginx 指向证书路径

### 方式三：付费证书（OV / EV）

企业级可选付费证书，提供组织验证。适合金融、政企场景。

## 配置 HTTPS Nginx

```nginx
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;
    # HTTP 强制跳转 HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com www.your-domain.com;

    # SSL 证书
    ssl_certificate     /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    # SSL 优化
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;

    # HSTS（告诉浏览器总是用 HTTPS）
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # ... 其余 location 配置同 [Nginx 反向代理]
}
```

## HSTS 安全头

::: tip HSTS
`Strict-Transport-Security` 告诉浏览器在指定天数内始终用 HTTPS 访问本站，防止 SSL Strip 攻击。
:::

```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

::: warning 先验证再启用 HSTS
启用 HSTS 后，如果证书过期或配置错误，用户将无法访问（浏览器强制 HTTPS 且不可绕过）。建议先用短 `max-age`（如 300）验证无误后再调大到 31536000（1 年）。
:::

## 更新后端配置

启用 HTTPS 后，需更新两处后端配置：

### 1. CORS 白名单

在 `main.py` 添加 HTTPS 域名：

```python
origins = [
    'https://your-domain.com',
    'https://www.your-domain.com',
    # 保留开发端口...
]
```

### 2. Cookie Secure 标记

如果用到 Cookie（VibeBase 主要用 Bearer Token，此项一般不需要），确保设置 `Secure` 标记。

## 证书自动续期

```bash
# 测试续期（不实际申请）
sudo certbot renew --dry-run

# 实际续期后需 reload nginx
# certbot 默认会配置 --deploy-hook 自动 reload
```

## 使用 CDN（可选）

高流量场景可在 Nginx 前加 CDN（Cloudflare / 阿里云 CDN）：

```
用户 → CDN → Nginx → 后端
```

::: warning CDN 与 SSE
CDN 可能缓冲 SSE 流。如果对话逐字输出异常，在 CDN 配置中对 `/api/chat` 路径**关闭缓存 / 关闭缓冲**，或让该路径绕过 CDN 直连源站。
:::

## 验证 HTTPS

```bash
# 检查证书
openssl s_client -connect your-domain.com:443 -servername your-domain.com

# 在线检测
# 访问 https://www.ssllabs.com/ssltest/ 输入域名，应得 A 以上评级
```

## 常见问题

### Q：证书申请失败「Connection refused」？

服务器 80 端口未开放或 Nginx 未启动。Let's Encrypt 验证需要通过 80 端口访问。

### Q：HTTPS 能访问但浏览器显示「不安全」？

可能是混合内容（页面里有 HTTP 的图片 / 脚本）。检查前端代码中的资源引用，全部改为 HTTPS 或相对协议 `//`。

### Q：续期失败？

检查 80 端口可达 + DNS 解析正常。`sudo certbot renew --dry-run` 看具体错误。

## 相关文档

- [Nginx 反向代理](./nginx)
- [生产环境部署](./production)
- [CORS 配置](../configuration/cors)
- [ICP 备案](./icp-filing)
