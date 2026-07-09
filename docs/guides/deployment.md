# 部署指南

汇总各子项目的容器化 / 上线部署要点。详细参数以各子项目内部文档为准（如 `VibeAdmin/doc/部署指南.md`）。

## 1. 端口对照

| 服务 | 端口 | 说明 |
| --- | --- | --- |
| VibeAdmin 前端 | 80 / 5173 | Nginx 反代 `/api/` → 8080 |
| VibeAdmin 后端 | 8080 | FastAPI + Uvicorn |
| VibeBase 前端 | 80 / 5175 | Nginx（Docker 多阶段构建）|
| VibeBase 后端 | 8081 / 8881 | FastAPI（API / 管理）|
| PostgreSQL | 5432 | VibeBase 主库（按项目隔离）|
| Vibe-Mp-H5(H5) | 5174 | 开发服务器，`pnpm dev:h5` |
| Vibe-Mp-H5(小程序) | — | 微信开发者工具导入 `dist/dev/mp-weixin` |

## 2. VibeAdmin 部署

- **Docker / Compose**：根目录 `docker-compose.yml` 一键编排前后端，Nginx 将 `/api/` 反向代理到后端，无需额外 CORS 配置。
- **Vercel**：`vibe-admin-web/vercel.json` 已配置前端静态部署。
- **生产数据库**：由 SQLite(开发) 切换为 PostgreSQL 16，详见 `VibeAdmin/doc/数据库设计.md`。

## 3. VibeBase 部署

- **Docker Compose**：`docker-compose up -d` 启动前端(80)、后端(8081/8881)、PostgreSQL。
- **前端镜像**：`vibe-base-web/Dockerfile` 多阶段构建（Node 20 Alpine 构建 → Nginx Alpine 运行），支持 `MODE=dev|test|prod` 构建参数。
- **健康检查**：前端容器配置 HTTP 80 端口健康检查。

## 4. Vibe-Mp-H5 部署

- **H5 构建**：`pnpm build:h5`，产物在 `dist/build/h5`，部署到 Nginx 即可。如需非根目录部署，修改 `manifest.config.ts` 中 `h5.router.base`。
- **微信小程序**：`pnpm build:mp`，产物在 `dist/build/mp-weixin`，用微信开发者工具打开后上传审核。
- **其他小程序端**：支持支付宝/百度/抖音/快手等，对应命令见 `package.json` 中的 `build:mp-*` 脚本。

## 5. VibeApp 部署

- Flutter 构建产物分别发布至 **App Store**（iOS）与 **Google Play**（Android）。
- `android/`、`ios/`、`web/` 为各平台工程目录，构建命令见 `VibeApp/README.md`。

## 6. 部署建议

1. **环境隔离**：dev / test / prod 使用不同 `.env` 与数据库实例。
2. **反向代理**：统一由 Nginx 暴露 80/443，按路径（`/api/`、`/admin/`）分流到各后端。
3. **数据库**：生产统一使用 PostgreSQL 16，做好备份与恢复（参考各项目数据库文档）。
4. **密钥管理**：JWT 密钥、数据库密码等通过 `.env` 注入，避免入库。
