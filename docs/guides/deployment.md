# 部署指南

汇总各子项目的容器化 / 上线部署要点。详细参数以各子项目内部文档为准：

- `VibeAdmin/doc/部署指南.md`
- `VibeBase/doc/部署指南.md`
- `VibeApp/doc/发布指南.md`
- `Vibe-Mp-H5/README.md`（含小程序发布）

> 端口分配为单一事实来源，详见 `STARTUP.md`。生产环境端口（80/443）由 Nginx 对外暴露，内部服务端口固定。

## 1. 端口对照

### 应用服务

| 服务 | 开发端口 | 生产端口 | 说明 |
| --- | --- | --- | --- |
| VibeAdmin 前端 | 5173 | 80 | Nginx 反代 `/api/` → `api:8080` |
| VibeAdmin 后端 | 8080 | 8080 | FastAPI + Uvicorn |
| VibeBase 前端 | 5175 | 80 | Nginx 反代 `/api/` → `backend:8081` |
| VibeBase 后端 | 8081 | 8081 | FastAPI + Uvicorn |
| Vibe-Mp-H5（H5） | 5174 | 80 | `pnpm dev:h5` 开发；生产为静态产物 |
| Vibe-Mp-H5（小程序） | — | — | 微信开发者工具导入 `dist/dev/mp-weixin` |
| VibePay 后端 | 8080 | 80 / 443 | Spring Boot（线上 `pay.vibeadmin.cn`） |

### 中间件

| 服务 | 端口 | 说明 |
| --- | --- | --- |
| PostgreSQL | 5432（项目 compose）/ 5433（monorepo 中间件） | 统一数据库，Admin/Base 共享 |
| Redis | 6379 | 缓存 / 限流 |
| MinIO | 9000（S3 API）/ 9001（控制台） | 对象存储 |

> VibeBase 后端**只有一个端口 8081**。历史文档中出现的 `8881` / `8880` 仅为管理端口的历史规划，当前并未实现，部署时请勿暴露。

## 2. VibeAdmin 部署

详见 `VibeAdmin/doc/部署指南.md`。要点：

- **Docker / Compose**：`cd VibeAdmin/vibe-admin && docker compose up -d --build`，编排 `api`（后端 8080）+ PostgreSQL 16 + Redis 7。前端单独 `cd vibe-admin-web && docker build .` 生成 Nginx 镜像（80）。
- **Nginx 反代**：`vibe-admin-web/nginx.conf` 将 `/api/` 反代到 compose 服务名 `api:8080`（与 `docker-compose.yml` 一致）。
- **Vercel**：`vibe-admin-web/vercel.json` 已配置前端静态部署（SPA rewrite）。
- **生产数据库**：由 SQLite（开发）切换为 PostgreSQL 16，详见 `VibeAdmin/doc/数据库设计.md`。

## 3. VibeBase 部署

详见 `VibeBase/doc/部署指南.md`。要点：

- **Docker Compose**：`cd VibeBase && docker-compose up -d --build` 启动前端（80）、后端（8081）、PostgreSQL、Redis。
  - compose 内后端服务名为 `backend`，前端 Nginx 反代 `/api/` → `backend:8081`。
- **前端镜像**：`vibe-base-web/Dockerfile` 多阶段构建（Node 20 Alpine 构建 → Nginx Alpine 运行），`vibe-base-web/nginx.conf` 提供 SPA fallback 与 API 反代。
- **健康检查**：后端 `GET /health`（8081）；前端容器 HTTP 80 端口健康检查。
- **裸机部署**：`bash vibe-base/start_server.sh start|stop|restart|status`（基于 PID 文件管理，无 reload）。

## 4. Vibe-Mp-H5 部署

- **H5 构建**：`pnpm build:h5`，产物在 `dist/build/h5`，部署到 Nginx 即可。如需非根目录部署，修改 `manifest.config.ts` 中 `h5.router.base`。Nginx 配置参照其他端（SPA fallback + `/api/` 反代到 VibeBase 后端 8081）。
- **微信小程序**：
  1. `pnpm build:mp`，产物在 `dist/build/mp-weixin`；
  2. 用微信开发者工具打开该目录；
  3. 在开发者工具中点「上传」生成体验版/审核包，或使用 CI 脚本 `node scripts/upload-weixin.js`（需配置微信小程序的 `appid` 与上传密钥）。
- **其他小程序端**：支持支付宝/百度/抖音/快手等，对应命令见 `package.json` 中的 `build:mp-*` 脚本。

## 5. VibeApp 部署

详见 `VibeApp/doc/发布指南.md`。要点：

- Flutter 一套代码构建 Android / iOS。
- **Android**：`flutter build apk` 或 `flutter build aab`（推荐 aab 上架 Google Play）。需配置签名 keystore。
- **iOS**：`flutter build ipa`，通过 Xcode 签名（证书 + Provisioning Profile）后上传 App Store Connect。
- 发布前在 `lib/core/` 配置生产环境后端地址（指向 VibeBase API `https://<域名>/api/`），版本号在 `pubspec.yaml` 维护。

## 6. VibePay 部署（支付中台）

VibePay 是商业化闭环的「收钱」环节，已部署线上站点 [https://pay.vibeadmin.cn/](https://pay.vibeadmin.cn/)。详见 `VibePay/vibePay/README.md`。要点：

- **Docker Compose（推荐）**：`cd VibePay/vibePay && docker compose up -d`，编排 Spring Boot 服务（8080）+ 独立 PostgreSQL（`vibepay` 库，数据持久化于具名卷 `vibepay-pgdata`）。
- **本地运行**：`mvn clean package && java -jar target/mq-0.0.1-SNAPSHOT.war`，默认端口 8080。
- **环境变量**：通过 `DB_HOST` / `DB_PORT` / `DB_NAME` / `DB_USER` / `DB_PASS` / `SERVER_PORT` 指定连接与端口。
- **Nginx 反代**：对外暴露 80/443，将域名（如 `pay.vibeadmin.cn`）反代到 `vibepay:8080`；回调地址在后台配置为 VibeBase 的 `/api/v1/recharge/notify`。
- **安卓监控端**：商户在后台生成绑定二维码，安装 `VibePay/vibePay-App/` 并扫码绑定，用于监听微信/支付宝收款通知。

## 7. 部署建议

1. **环境隔离**：dev / test / prod 使用不同 `.env` 与数据库实例。
2. **反向代理**：统一由 Nginx 暴露 80/443，按路径（`/api/`、`/admin/`）分流到各后端；VibePay 走独立域名（如 `pay.vibeadmin.cn`）。
3. **数据库**：生产统一使用 PostgreSQL 16，做好备份与恢复（参考各项目数据库文档）。VibePay 使用独立 `vibepay` 库，与业务库解耦。
4. **密钥管理**：JWT 密钥、数据库密码、VibePay 通讯密钥（appKey）等通过 `.env` 注入，避免入库；仓库内所有占位密钥（如 `vibe-dev-shared-secret-change-in-prod`、`minioadmin`）**上线前必须替换**。
5. **中间件**：monorepo 提供 `docker-compose.middleware.yml` 统一编排 PG/Redis/MinIO，生产可复用或替换为托管服务。
