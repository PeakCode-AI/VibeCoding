# 常见问题

汇总 VibeBase 的常见问题，涵盖产品、开发、部署三个维度。

## 产品相关

### VibeBase 能直接上线吗？

::: details 能。VibeBase 是生产可用的完整产品，不是 Demo。
开箱即用包含：用户注册登录、AI 对话、积分计费、充值支付、运营控制台、安全中心等全部能力。配置好 LLM 与支付密钥后即可对外服务。
:::

### VibeBase 和普通的 AI 聊天模板有什么区别？

::: details 普通 AI 模板只解决「能对话」，VibeBase 解决「能收钱、能运营」。
普通模板给你一个聊天界面就结束了。VibeBase 提供的是完整商业闭环：用户能对话、能充值、能续费；运营方能管人、管订单、管收入；四端齐全（Web / 后台 / App / 小程序）。详见 [核心特性](../introduction/features)。
:::

### 我没有技术团队，能用 VibeBase 吗？

::: details 可以，但建议至少有基本的服务器运维能力。
VibeBase 提供 Docker 一键部署，非开发人员也能通过宝塔面板等工具部署。但 AI 产品的日常运营（调整能力定价、处理工单、查看数据）仍需在 VibeAdmin 后台操作，建议运营人员具备基本的互联网产品素养。
:::

### 数据会被锁定在你们服务器上吗？

::: details 不会。VibeBase 是源码交付，数据完全在你手里。
你拿到的是完整源码，部署在你自己的服务器，数据库、Redis、对象存储全部自主可控。我们无法访问你的数据，也不依赖我们的云服务。
:::

### 能用于客户交付项目吗？

::: details 可以。企业版授权明确包含商用与私有化部署。
VibeBase 天然适合外包 / 交付团队作为标准化交付物：完整、可商用、可私有部署。详见 [适用场景](../introduction/use-cases)。
:::

### 买之前能先体验吗？

::: details 可以先免费体验产品界面与交互。
你可以本地启动 VibeBase（无需配置真实 LLM 与支付，对话走降级提示、充值走模拟回调），完整体验所有功能页面。满意后再决定购买授权。
:::

### 源码授权定价（¥299/¥599/¥1,599）和控制台里的充值套餐是什么关系？

::: details 完全是两个概念。
- **源码授权**（Landing 页三档定价）= 购买 VibeBase 源码的使用权（学习版 / 专业版 / 企业版）
- **积分充值套餐**（控制台内）= 产品跑起来后，最终用户充值用的虚拟货币（¥99 / ¥399 / ¥999 换积分）

前者是「买源码」，后者是「用户用源码建的产品时充值」。
:::

## 开发相关

### Q：启动报数据库连接错误？

::: details 排查步骤
1. 确认 PostgreSQL 在运行：`psql -h localhost -p 5433 -U vibe -d vibe -c "SELECT 1;"`
2. 检查 `.env` 的 `DATABASE_URL`（端口、用户名、密码、库名）
3. 确认数据库 `vibe` 与用户 `vibe` 已创建
详见 [数据库配置](../configuration/database)。
:::

### Q：API 返回 401？

::: details Token 缺失或失效
1. 确认请求头带了 `Authorization: Bearer <token>`
2. Token 可能已过期（access 7 天）—— 用 refresh token 续签
3. Token 可能已被登出撤销（Redis 黑名单）
详见 [认证机制](../development/authentication)。
:::

### Q：如何切换 AI 模型？

::: details 修改 .env 的 OPENAI_*
在 `.env` 修改 `OPENAI_MODEL`（如 `qwen-plus` → `qwen-turbo`），重启后端。支持任何 OpenAI 兼容协议的模型。详见 [LLM 配置](../configuration/llm)。
:::

### Q：对话返回「降级提示」而不是真正的 AI 回复？

::: details LLM 未正确配置
`OPENAI_API_KEY` 为空或为占位符（`your-api-key` / `sk-xxx` / `changeme` 等）时走降级。填入真实 Key 并重启后端。详见 [LLM 配置](../configuration/llm#优雅降级)。
:::

### Q：前端打开是白屏？

::: details 后端未启动或地址错误
1. 确认后端已启动：`curl http://localhost:8081/health`
2. 检查前端 `.env` 的 `VITE_API_BASE_URL`
3. 浏览器开发者工具看 Console / Network 报错
:::

### Q：对话没有逐字输出（最后一次性出现）？

::: details Nginx 缓冲了 SSE
Nginx 必须配置 `proxy_buffering off;`。详见 [Nginx 反向代理 · SSE 配置](../deployment/nginx#sse-配置详解)。
:::

### Q：如何跳过登录直接测试？

::: details 用 dev-login
开发环境调用 `POST /api/v1/user/dev-login` 直接获取管理员 Token（仅 `ENVIRONMENT != production`）。
:::

### Q：充值回调一直失败？

::: details 支付验签密钥问题
`PAYMENT_NOTIFY_SECRET` 未配置或与支付网关不一致。开发期可用 `/api/v1/recharge/callback` 走模拟回调。详见 [支付配置](../configuration/payment)。
:::

### Q：头像上传返回 503？

::: details S3/MinIO 未配置
头像上传依赖对象存储。在 `.env` 配置 `S3_*` 并启动 MinIO。详见 [对象存储配置](../configuration/storage)。
:::

### Q：修改了 .env / config.yaml 但不生效？

::: details 需重启后端
uvicorn `--reload` 只重载 Python 代码，**不**重读配置文件。改配置后必须手动重启后端进程。
:::

### Q：前端页面与 README 路由表对不上？

::: details 以 router/index.ts 为准
当前路由只挂载了 Landing 页、`/app/console/*` 与 `/auth/*`。README 中的部分旧路由（如 `/chat`、`/user/profile`）是历史遗留，实际入口是控制台。
:::

## 部署相关

### Q：必须用 Docker 部署吗？

::: details 不必须，但推荐
也支持裸机部署（systemd + Nginx）。Docker 的优势是一致性与隔离。详见 [Docker 部署](../deployment/docker) 与 [生产环境部署](../deployment/production)。
:::

### Q：生产环境有哪些必须做的安全配置？

::: details 至少这几项
1. `SECRET_KEY` 改为随机强密钥
2. `ENVIRONMENT=production`（禁用 dev-login）
3. 启用 HTTPS
4. PostgreSQL 强密码
5. 更新 CORS 白名单为真实域名
详见 [生产环境部署](../deployment/production#部署前清单)。
:::

### Q：必须备案吗？

::: details 服务器在中国大陆就必须备案
海外服务器不需要。详见 [ICP 备案](../deployment/icp-filing)。
:::

### Q：VibeBase 和 VibeAdmin 要部署在同一台服务器吗？

::: details 不必须，但共享同一数据库
两者只要连同一个 PostgreSQL、配置相同的 `SECRET_KEY` 即可跨服务 Token 互认。可以分机部署。
:::

### Q：如何备份数据？

::: details 定期 pg_dump
```bash
pg_dump -U vibe vibe | gzip > backup_$(date +%F).sql.gz
```
建议加入 crontab 每日备份，保留 30 天。
:::

## 更多帮助

如果你的问题不在本页：

- 查阅左侧目录的对应章节
- 查看 [API 文档](http://localhost:8081/docs)（后端启动后）
- 提工单反馈（控制台 → 我的工单）
