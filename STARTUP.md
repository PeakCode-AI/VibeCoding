# Vibe 全栈启动指南（本次已启动的服务）

本文档整理当前本地实际运行的服务、各自的启动脚本，以及**一键启动**方式。
适用环境：macOS（ServBay 提供 Node / Python / PostgreSQL），Docker Desktop 提供中间件。

> 约定：所有开发端口**集中规划、显式固定、相邻分组**（见下）。前端聚在 `517x`，后端聚在 `808x`，
> 中间件保持原隔离段（5433/6379）。三个前端均开启 Vite `strictPort`，端口被占用时**直接报错退出**
> 而不是自动 +1 换端口（这正是之前互相抢 5173 的根因）。Vibe-Mp-H5（H5 端，端口 **5174**）已纳入 `start-all.sh` 一键启动。

---

## 一、服务清单与端口

| 服务 | 类型 | 端口 | 可访问地址 | 依赖 |
| --- | --- | --- | --- | --- |
| VibeAdmin 前端 | Vue3 + Vite | **5173** | http://localhost:5173/ | 代理 `/api/v1` → 后端 8080 |
| Vibe-Mp-H5 前端 | uni-app H5 | **5174** | http://localhost:5174/ | 直连 VibeBase 后端 8081 |
| VibeBase 前端 | Vue3 + Vite | **5175** | http://localhost:5175/ | 代理 `/api/v1` → 后端 8081 |
| VibeAdmin 后端 | FastAPI | **8080** | http://localhost:8080/（文档 `/docs`） | PostgreSQL(5433) + Redis(6379) |
| VibeBase 后端 | FastAPI | **8081** | http://localhost:8081/（文档 `/docs`） | PostgreSQL(5433) + Redis(6379) |
| PostgreSQL | Docker | **5433** | localhost:5433（库 `vibe`/用户 `vibe`/密码 `vibe`） | —— |
| Redis | Docker | **6379** | localhost:6379 | —— |

> ⚠️ PostgreSQL 主机端口固定为 **5433**，刻意避开 ServBay 自带的 5432（后者没有 `vibe` 库）。
> 应用连接串统一写 `localhost:5433` 即可。
>
> ✅ **VibeAdmin 与 VibeBase 现已共享同一套 PostgreSQL（`vibe` 库）**，两者的 ORM 模型统一收敛到 `vibe_common/models/`。
> 因此**必须在 PostgreSQL 运行的前提下**才能启动任一后端（包括 VibeAdmin）。

---

## 一之一、端口分配（单一事实来源，相邻分组避免抢端口）

端口按**业务分组、连续相邻**规划，全部显式固定：

| 分组 | 服务 | 端口 | 连接方式 / 备注 |
| --- | --- | --- | --- |
| 前端段 `517x` | VibeAdmin 前端 | **5173** | Vue3+Vite（`vite.config.ts` 固定）|
| | Vibe-Mp-H5 | **5174** | uni-app H5（`env/.env.development` 固定，直连 8081）|
| | VibeBase 前端 | **5175** | Vue3+Vite（`vite.config.ts` 固定，代理 → 8081）|
| | VibeApp（Flutter web） | **5176**（预留） | `flutter run -d web-server --web-port 5176` |
| 后端段 `808x` | VibeAdmin 后端 | **8080** | FastAPI，CORS 放行 5173/5174/5175/5176 |
| | VibeBase 后端 | **8081** | FastAPI，CORS 放行 5173/5174/5175/5176 |
| 中间件段 | PostgreSQL | **5433** | 隔离段，刻意避开 ServBay 自带 5432 |
| | Redis | **6379** | 隔离段 |

> 调整端口后，记得同步更新对应后端的 CORS 白名单（见上表后端段「CORS 放行」列）。

---

## 二、重要架构事实（避免踩坑）

1. **VibeAdmin 与 VibeBase 后端共用同一 PostgreSQL(`vibe` 库，端口 5433)。**
   两后端的 `.env` 均已指向：
   ```ini
   DATABASE_URL=postgresql+asyncpg://vibe:vibe@localhost:5433/vibe
   REDIS_URL=redis://localhost:6379
   ```
   ORM 模型统一在 `vibe_common/models/`（VibeBase 用 vendored 副本，VibeAdmin 引用同一套）。
   **启动任一后端前，必须确保 PostgreSQL(5433) 已运行。**

2. **VibeBase 后端自带 `.env`（无需再注入环境变量）。**
   文件 `VibeBase/vibe-base/.env` 已包含 `DATABASE_URL` / `SECRET_KEY` / `REDIS_URL`，
   启动时由 `database/__init__.py` 通过 `python-dotenv` 自动加载。

3. **VibeBase 后端依赖 Python ≥ 3.10（实际用 3.13 venv）。**
   项目根 `VibeBase/vibe-base/.venv/` 为预置虚拟环境；`poetry install` 在本地因 Rust 依赖（jiter）编译失败，
   已改用 `pip install -r requirements.txt`（已生成）安装。系统自带 Python 3.9 **不兼容**
   （代码使用了 `X | None` 等新语法）。启动命令见第三节。

4. **VibeBase 前端默认直连真实后端（Mock 关闭）。**
   `src/composables/useMock.ts` 的 `isMockEnabled()` 现在返回
   `import.meta.env.VITE_ENABLE_MOCK === 'true'`（默认 false）。
   即：**不设置该变量时，前端调用真实 `/api/v1` 接口**。
   如需本地联调假数据，在 `.env` 设置 `VITE_ENABLE_MOCK=true` 再 `npm run dev`。

5. **前端 shim 修复（一次性）。**
   VibeAdmin 前端 `vite-plugin-vue-devtools` 在 Node 25 下加载配置时会访问不完整的 `localStorage` 导致崩溃。
   已通过 `VibeAdmin/vibe-admin-web/vite.localstorage-shim.mjs` 垫片修复，并在 `package.json` 中用
   `NODE_OPTIONS='--import=./vite.localstorage-shim.mjs' vite` 方式加载（**不要**用 `node xxx .bin/vite`，
   因为 `.bin/vite` 是 shell 脚本，被 node 当 JS 加载会报 `missing )`）。

6. **PATH 问题。**
   非交互 shell 里 `node/npm/pnpm/docker` 可能不在 PATH（ServBay Node 在
   `/Applications/ServBay/package/node/25/25.9.0/bin`）。一键脚本已自动补 PATH；
   手动在终端启动通常没问题（登录 shell 已加载 ServBay 环境）。

---

## 三、各服务手动启动命令

### 中间件（Docker）
```bash
# 首次或中间件未运行时
docker compose -f docker-compose.middleware.yml up -d      # Postgres(5433)+Redis(6379)
# 若已有容器 vibe-pg / vibe-redis，可直接
docker start vibe-pg vibe-redis
```

### VibeAdmin 后端（8080，PostgreSQL）
```bash
cd VibeAdmin/vibe-admin
python3 -m uvicorn app.main:app --host 127.0.0.1 --port 8080
# 默认管理员：admin@example.com / admin123
# 依赖 PostgreSQL(5433) + Redis(6379)，与 VibeBase 共享同一数据库
# 默认不灌演示种子数据；如需演示数据，在 .env 设置 SEED_DB_ON_STARTUP=true
```

### VibeBase 后端（8081，PostgreSQL+Redis）
```bash
cd VibeBase/vibe-base
# 已自带 .venv（Python 3.13）+ .env，直接启动即可
.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8081 --reload
# 若需重建环境： python3.13 -m venv .venv && .venv/bin/pip install -r requirements.txt

# AI 能力（可选）：在 .env 配置 OPENAI_API_KEY/BASE_URL/MODEL 启用真实对话；
#   VL_* 启用图片理解；PAYMENT_NOTIFY_SECRET 启用支付回调验签。均留空时相关能力自动降级。

# 接口冒烟测试（零额外依赖，需中间件已启动）：
.venv/bin/python tests/smoke_test.py
```

#### 可选：Docker 化运行 VibeBase 后端
```bash
# 前置：中间件已启动（docker-compose.middleware.yml）
docker compose -f docker-compose.vibebase.yml up -d --build   # 容器经 host.docker.internal 复用 PG/Redis
```

### VibeAdmin 前端（5173）
```bash
cd VibeAdmin/vibe-admin-web
pnpm dev
```

### VibeBase 前端（5175）
```bash
cd VibeBase/vibe-base-web
npm run dev      # vite.config.ts 中 server.port=5175，并代理 /api/v1 → 8081
# 默认直连真实后端。需要假数据时：在 .env 设置 VITE_ENABLE_MOCK=true
```

---

## 四、一键启动（推荐）

脚本位置：`start-all.sh`（已 `chmod +x`）。

```bash
cd /Users/jwangkun/Coding/VibeCoding
./start-all.sh
```

行为：
- **幂等**：已监听的端口不会重复拉起；未启动的才启动。
- 启动顺序：中间件 → 后端 → 前端。
- 启动完成后**统一打印端口与可访问地址**，并对四个 HTTP 服务做健康检查（✅/❌）。
- 所有进程日志写入 `/tmp/vibe-logs/`，便于排查。

示例输出：
```
============================================================
  Vibe 全栈服务访问地址
============================================================
服务                   端口     地址
VibeAdmin 前端         5173     http://localhost:5173/
Vibe-Mp-H5 前端        5174     http://localhost:5174/
VibeBase 前端          5175     http://localhost:5175/
VibeAdmin 后端         8080     http://localhost:8080/   (API 文档: /docs)
VibeBase 后端          8081     http://localhost:8081/   (API 文档: /docs)
PostgreSQL             5433     localhost:5433   库=vibe 用户=vibe 密码=vibe
Redis                  6379     localhost:6379
------------------------------------------------------------
健康检查:
  ✅ VibeAdmin 前端 可访问 (HTTP 200)
  ✅ Vibe-Mp-H5 前端 可访问 (HTTP 200)
  ✅ VibeBase 前端 可访问 (HTTP 200)
  ✅ VibeAdmin 后端 可访问 (HTTP 200)
  ✅ VibeBase 后端 可访问 (HTTP 200)
```

---

## 五、停止服务（如需）

```bash
# 前端/后端：直接结束对应进程（nohup 启动的）
# 中间件：
docker stop vibe-pg vibe-redis
# 或
docker compose -f docker-compose.middleware.yml down
```

---

## 六、本次为修复/优化而改动的文件

| 文件 | 改动 |
| --- | --- |
| `VibeAdmin/vibe-admin-web/package.json` | `dev`/`build` 改为 `NODE_OPTIONS='--import=./vite.localstorage-shim.mjs' vite`（修复 `node .bin/vite` 的 SyntaxError） |
| `VibeAdmin/vibe-admin-web/vite.localstorage-shim.mjs` | 新增 localStorage 垫片，兼容 Node 25 不完整的全局 `localStorage` |
| `VibeAdmin/vibe-admin/app/api/v1/endpoints/auth.py` | 补 `HTTPAuthorizationCredentials` 导入（修复 NameError） |
| `VibeAdmin/vibe-admin/vibe_common/core/config.py` | 补 `VERSION` 字段（修复 `settings.VERSION` AttributeError） |
| `VibeBase/vibe-base/vibe_common/core/config.py` | 同上，补 `VERSION` 字段 |
| `docker-compose.middleware.yml` | 新增：中间件一键定义（Postgres 5433 + Redis 6379） |
| `start-all.sh` | 新增：全栈一键启动脚本 |
| `VibeAdmin/vibe-admin/.env` | **改为共享 PostgreSQL**（`postgresql+asyncpg://vibe:vibe@localhost:5433/vibe`），与 VibeBase 共用 `vibe` 库 |
| `VibeBase/vibe-base/.env` | 新增：显式 `DATABASE_URL`/`SECRET_KEY`/`REDIS_URL`，不再依赖外部注入 |
| `VibeBase/vibe-base/requirements.txt` | 新增：从 `.venv` 导出的可复现依赖清单（替代 `poetry install`） |
| `VibeBase/vibe-base/api/v1/analytics.py` | **修复 500 错误**：原 `usage()` 用 `range` 作为查询参数名，遮蔽了内置 `range()`，导致 `range(days-1,-1,-1)` 抛 `TypeError`；改为 `period: str = Query("7d", alias="range")` |
| `VibeBase/vibe-base-web/src/composables/useMock.ts` | `isMockEnabled()` 默认关闭 Mock，直连真实后端（`VITE_ENABLE_MOCK==='true'` 才启用） |
| `VibeBase/vibe-base-web/src/apis/*` | 对齐真实后端响应结构（recharge/points/roles/announcement/analytics/consume 等） |
| `VibeAdmin/vibe-admin/app/api/v1/endpoints/{pricing,billing,dashboard}.py` | 新增定价套餐 / 账单历史 / 真实仪表盘指标；挂载 `pricing`、`billing` 路由 |
| `VibeBase/vibe-base/api/v1/{apikey,profile,security,feedback,misc,...}.py` | 新增/对齐 API Key、个人资料、退出、反馈、图片理解等接口 |
| `VibeBase/vibe-base/api/v1/accounts.py` + `vibe_common/models/sub_account.py` + `database/dao/sub_account.py` | **新增子账号管理**：`sub_accounts` 表 + DAO + `GET/POST/PUT/DELETE /api/v1/accounts` 及 `toggle-status`；前端 `accountApi` 接通真实分支 |
| `VibeBase/vibe-base/api/v1/user.py` | `set-password` 支持校验原密码（`old_password`）；前端 `securityApi.changePasswordAPI` 接通真实后端 |
| `VibeBase/vibe-base/api/v1/analytics.py` | 重新应用 `range`→`period(alias="range")` 修复（曾被回退），现 3 个 range 参数均 200 |
| **—— 第二轮（2026-07-09）—— ** | |
| `VibeBase/vibe-base/api/services/chat.py` + `api/v1/chat.py` | **AI 对话真实化**：模型配置支持 `OPENAI_*` 环境变量优先；未配置时 SSE 降级提示且不扣积分 |
| `VibeBase/vibe-base/api/v1/misc.py` | **图片理解真实化**：接入 OpenAI 兼容视觉模型（`VL_*` 回退 `OPENAI_*`），未配置时降级 |
| `VibeBase/vibe-base/api/v1/recharge.py` | **新增支付异步通知** `POST /recharge/notify`（HMAC-SHA256 验签 + 幂等加积分）；修复 detached 对象访问 |
| `VibeBase/vibe-base/vibe_common/models/operation_log.py` + `database/{models,dao}/operation_log.py` | **新增操作日志**：模型/别名/DAO（含登录设备聚合） |
| `VibeBase/vibe-base/api/v1/{security,user}.py` | **安全中心**：登录/改密埋点 + `operation-logs`、`devices` 接口；前端 `securityApi.ts` 接通 |
| `VibeBase/vibe-base/{config/config.dev.yaml,.env.example}` | 白名单加 `/recharge/notify`；补 `OPENAI_*`/`VL_*`/`PAYMENT_NOTIFY_SECRET` 样例 |
| `VibeBase/vibe-base/tests/smoke_test.py` | **新增冒烟测试**（零依赖，22 项断言） |
| `VibeBase/vibe-base/Dockerfile` + `.dockerignore` + `docker-compose.vibebase.yml` | **VibeBase Docker 化**（复用中间件 PG/Redis，含健康检查） |
| `VibeAdmin/vibe-admin/app/api/v1/endpoints/agents.py` + `vibe-admin-web/src/pages/agents/index.vue` | **Agents 联调**：接口改 Pydantic body，前端页面接入真实调用 |
| **—— 第三轮（2026-07-09）：统一端口分配（相邻分组、固定端口）—— ** | |
| 端口规划 | **前端段 `517x`：5173 VibeAdmin / 5174 Vibe-Mp-H5 / 5175 VibeBase / 5176 VibeApp(预留)；后端段 `808x`：8080 VibeAdmin / 8081 VibeBase；中间件 5433/6379 保持隔离** |
| `VibeAdmin/vibe-admin-web/vite.config.ts` | **前端端口显式固定 5173 + `strictPort:true`** |
| `Vibe-Mp-H5/vite.config.ts` | 新增 `strictPort:true`（端口 5174 由 `env/.env.development` 固定）|
| `VibeBase/vibe-base-web/vite.config.ts` | 端口 **9510 → 5175** + `strictPort:true` |
| `VibeBase/vibe-base/main.py` | 后端端口 **7860 → 8081**；**CORS 白名单**改为前端段 5173/5174/5175/5176（含 127.0.0.1）|
| `VibeBase/vibe-base/{start_server.sh,start_dev.sh,docker-compose.yml}` + `docker-compose.vibebase.yml` | 后端端口 **7860 → 8081** |
| `VibeBase/vibe-base-web/vite.config.ts` | 代理目标 **7860 → 8081** |
| `Vibe-Mp-H5/env/{.env,.env.development}` | 后端地址 **7860 → 8081** |
| `VibeAdmin/vibe-admin/run_server.py` | 后端端口 **8000 → 8080**（文档打印）|
| `VibeAdmin/vibe-admin/.env` | **CORS** 改为前端段 5173/5174/5175/5176（+8080）|
| `VibeAdmin/vibe-admin-web/{.env,.env.local}` | 后端地址 **8000 → 8080** |
| `start-all.sh` | 后端 8000→8080 / 7860→8081；前端 9510→5175；**新增 Vibe-Mp-H5（5174）**；同步表头/等待/打印/健康检查 |
| `STARTUP.md` | 服务清单与「端口分配」小节改为相邻分组新方案；更新手动启动命令与示例输出 |
| `VibeAdmin/vibe-admin/app/core/init_db.py` | **修复种子幂等**：超级管理员按 `email OR admin_id` 判重，避免共享库已存在 `A001` 时唯一键冲突导致后端启动失败（端口迁移时暴露）|
| 各 `README.md` / `docs/*` / `docker-compose*.yml` / `.env*` | 全量同步新端口（后端 8080/8081，前端 5173/5174/5175，VibeBase 管理端口 8881）|
