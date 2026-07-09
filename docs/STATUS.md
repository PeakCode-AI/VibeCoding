# 项目实现状态与待办（STATUS / TODO）

> 本文档记录 VibeCoding 各子项目的**真实实现状态**，以及尚未完成的功能清单（待办）。
> 最后更新：2026-07-09（第二轮：完成 T2/T4/T5/T6/T7）
> 配套启动说明见根目录 `STARTUP.md`，架构总览见 `README.md`。

---

## 一、已完成的后端接口（实测可用，返回 200）

### VibeBase（C 端，FastAPI :8081，共享 PostgreSQL `vibe` 库）

| 模块 | 接口 | 状态 | 说明 |
| --- | --- | :---: | --- |
| 认证 | `POST /api/v1/user/register` `login` `dev-login` | ✅ | 注册/登录，JWT 7 天有效 |
| 用户 | `GET /api/v1/user/info` `PUT /api/v1/user/update` `GET /api/v1/user/icons` `POST /api/v1/user/set-password` | ✅ | 资料/头像/改密 |
| 对话 | `POST /api/v1/chat` `POST /api/v1/upload` | ✅ | 流式对话；**支持 `.env` 注入 `OPENAI_*`，未配置时优雅降级不扣费** |
| 对话历史 | `dialog` / `message` / `history` 系列 | ✅ | 会话与消息持久化 |
| 充值 | `records` `callback` `POST /api/v1/recharge/notify` 等 | ✅ | 充值记录；**新增支付网关异步通知 `notify`（HMAC-SHA256 验签，幂等加积分）** |
| API Key | `GET/POST /api/v1/api-keys` `DELETE /api/v1/api-keys/{id}` `enable/disable` | ✅ | 密钥 CRUD + 状态切换 |
| 公告 | `GET /api/v1/announcement` | ✅ | 类型/置顶映射 |
| AI 能力 | `GET /api/v1/ability` | ✅ | 能力列表 |
| 用量分析 | `GET /api/v1/analytics/usage?range=today\|7d\|30d` | ✅ | **已修复 500**（原 `range` 遮蔽内置函数） |
| 个人资料 | `GET/PUT /api/v1/user/profile` | ✅ | 昵称/头像/简介 |
| 积分 | `GET /api/v1/points/info` `POST /api/v1/points/transactions` `POST /api/v1/points/check` `GET /api/v1/points/records` | ✅ | 积分余额/明细/校验 |
| 角色权限 | `GET/POST/PUT/DELETE /api/v1/roles` | ✅ | 角色 CRUD |
| 安全 | `logout` `GET /api/v1/security/operation-logs` `GET/DELETE /api/v1/security/devices` | ✅ | 登出 + **操作日志/登录设备（真实埋点，登录/改密自动记录）** |
| 反馈 | `POST /api/v1/feedback` | ✅ | 用户反馈入库 |
| 图片理解 | `POST /api/v1/image/understand` | ✅ | **接入视觉模型（OpenAI 兼容），未配置 `VL_*` 时降级演示** |
| 消费记录 | `GET /api/v1/consume/records` | ✅ | 消费明细 |

### VibeAdmin（B 端，FastAPI :8080，共享 PostgreSQL `vibe` 库）

| 模块 | 接口 | 状态 | 说明 |
| --- | --- | :---: | --- |
| 认证 | `/api/v1/auth/*` | ✅ | JWT + bcrypt |
| 概览 | `/api/v1/dashboard/*` | ✅ | **真实指标**（对比昨日计算环比） |
| 用户 | `/api/v1/users/*` | ✅ | 用户管理 |
| 管理员 | `/api/v1/admins/*` | ✅ | 管理员管理 |
| 角色 | `/api/v1/roles/*` | ✅ | RBAC |
| 充值订单 | `/api/v1/recharge-orders/*` | ✅ | 订单管理 |
| 收入 | `/api/v1/income/*` | ✅ | 收入统计 |
| AI 能力 | `/api/v1/abilities/*` | ✅ | 能力配置 |
| 调用日志 | `/api/v1/api-logs/*` | ✅ | 日志查看 |
| 工单 | `/api/v1/tickets/*` | ✅ | 工单流转 |
| 公告 | `/api/v1/announcements/*` | ✅ | 公告管理 |
| 系统设置 | `/api/v1/system-settings/*` | ✅ | 平台配置 |
| 智能体 | `/api/v1/agents/*` | ✅ | 任务/数据/报告三类 Agent |
| 任务 | `/api/v1/tasks/*` | ✅ | 运营任务 CRUD |
| 定价套餐 | `/api/v1/pricing/plans` 系列 | ✅ | **新增**：套餐 CRUD + 启停 |
| 账单历史 | `/api/v1/billing/history` | ✅ | **新增**：账单分页 |

---

## 二、待办清单（未实现 / 需完善）

### 🔴 P0 — 影响核心可用性的真实缺口

| # | 功能 | 现状 | 建议实现 |
| --- | --- | --- | --- |
| T1 | **子账号管理** `POST/GET/PUT/DELETE /api/v1/accounts` | ✅ **已实现**（2026-07-09）：`sub_accounts` 模型 + DAO + 路由 + 前端 `accountApi` 真实分支 | — |
| T2 | **AI 对话真实化** `/api/v1/chat` | ✅ **已实现**（2026-07-09）：`OPENAI_API_KEY/BASE_URL/MODEL` 环境变量优先于 yaml；未配置时返回可读降级提示（SSE）且不扣费 | — |
| T3 | **改密前端打通** | ✅ **已实现**（2026-07-09）：`set-password` 支持校验原密码，前端 `changePasswordAPI` 接通真实后端 | — |

### 🟡 P1 — 增强完整性（中等工作量）

| # | 功能 | 现状 | 建议实现 |
| --- | --- | --- | --- |
| T4 | **图片理解真实化** `/api/v1/image/understand` | ✅ **已实现**（2026-07-09）：接入视觉模型（`VL_*` 或回退 `OPENAI_*`），未配置时降级演示 | — |
| T5 | **充值支付真实回调** `/api/v1/recharge/notify` | ✅ **已实现**（2026-07-09）：新增支付网关异步通知端点（HMAC-SHA256 验签 + 幂等加积分，白名单免登录）；对接官方网关需替换为 RSA/证书验签 | — |
| T6 | **安全中心其余能力** | ✅ **已实现**（2026-07-09）：`operation_logs` 模型/DAO + 登录/改密埋点 + 操作日志/登录设备接口 + 前端接通；2FA 仍前端本地态（需额外基础设施） | 2FA 后端化（可选） |
| T7 | **VibeAdmin Agents/Tasks 前端联调** | ✅ **已实现**（2026-07-09）：修复 agents 接口入参（改 Pydantic body，前端 JSON 可用）；`agents` 页面接入 `agentsApi` 真实调用；tasks 前后端字段已核对一致 | — |

### 🟢 P2 — 工程化 / 体验优化

| # | 功能 | 建议 |
| --- | --- | --- |
| T8 | **统一响应与错误码** | ✅ **已实现**（2026-07-09 第三轮）：`main.py` 全局异常处理器统一 `HTTPException`/`RequestValidationError`/未捕获异常为 `UnifiedResponseModel`；前端 `http.ts` 优先读 `status_message` | — |
| T9 | **接口自动化测试** | ✅ **已实现**（2026-07-09）：`VibeBase/vibe-base/tests/smoke_test.py` 零依赖冒烟脚本（22 项断言，覆盖鉴权/安全/积分/充值验签幂等/对话&图片降级），`.venv/bin/python tests/smoke_test.py` 可跑，失败非 0 退出便于 CI |
| T10 | **Vibe-Mp-H5 / VibeApp 业务页** | ✅ **已实现**（2026-07-09 第四/五轮）：后端双 token 机制；两前端均打通「登录→存双 token→401 无感刷新→登出吊销」，且「我的」页已接真实 `/user/info`+`/points/info`；首页/其他业务页仍待按需扩展 |
| T11 | **Docker 化 VibeBase** | ✅ **已实现**（2026-07-09）：新增 `VibeBase/vibe-base/Dockerfile` + `.dockerignore` + 根目录 `docker-compose.vibebase.yml`（经 `host.docker.internal` 复用中间件 PG/Redis，含健康检查） |

---

## 三、本轮已修复的关键问题（回顾）

1. **VibeBase analytics 500**：`usage(range: str = Query("7d"))` 用 `range` 作参数名，**遮蔽内置 `range()`**，导致 `range(days-1,-1,-1)` 抛 `TypeError`。改为 `period: str = Query("7d", alias="range")`。
   > ⚠️ 该文件曾被外部修改回退此修复并改用 `PointAccountDao` 读取积分余额，已重新应用 `period`/`alias="range"` 修复，当前实测 3 个 range 参数均返回 200。
2. **共享数据库统一**：VibeAdmin 与 VibeBase 的 `.env` 均指向同一 PostgreSQL（`vibe` 库，:5433），ORM 模型统一在 `vibe_common/models/`。
3. **依赖可复现**：VibeBase 由 `poetry install`（Rust 编译失败）改为 `.venv` + `requirements.txt`（已生成）。
4. **前端 Mock 默认关闭**：`isMockEnabled()` 默认直连真实后端，仅 `VITE_ENABLE_MOCK=true` 时走 mock。
5. **缺失模型别名补齐**：`database/models/` 下 `ability/announcement/recharge_order/api_log` 别名文件；修正 `message.py` 错误的 `MessageDownTable/MessageLikeTable` 导入。
6. **依赖版本钉死**：`starlette==0.46.2` + `sse-starlette==2.2.1`，避免 Starlette 1.x 破坏 `on_startup`。

---

## 三·补、第二轮（2026-07-09）新增与修复

1. **AI 对话真实化（T2）**：`api/services/chat.py` 新增 `_resolve_model_config()` / `is_llm_configured()`，模型配置优先读环境变量 `OPENAI_API_KEY/OPENAI_BASE_URL/OPENAI_MODEL`（回退 yaml）；未配置或占位符时 `StreamingAgent` 走降级 SSE 提示，`chat.py` 同步跳过积分扣费。
2. **图片理解真实化（T4）**：`api/v1/misc.py` 接入 OpenAI 兼容视觉模型，配置 `VL_API_KEY/VL_BASE_URL/VL_MODEL`（回退 `OPENAI_*`）；未配置时返回演示文案（`fallback: true`）。
3. **充值异步通知（T5）**：`api/v1/recharge.py` 新增 `POST /recharge/notify`，HMAC-SHA256 验签（`PAYMENT_NOTIFY_SECRET`）+ 幂等加积分；已加入白名单免登录。修复 `_credit_order` 的 detached 对象访问（Session 内取值）。
4. **安全中心（T6）**：新增 `operation_logs` 模型（`vibe_common/models/operation_log.py` + `database/models` 别名 + `database/dao/operation_log.py`）；登录成功/改密自动埋点；新增 `GET /security/operation-logs`、`GET/DELETE /security/devices`（设备由登录日志按 IP/浏览器/系统聚合）；前端 `securityApi.ts` 三个接口接通真实后端。
5. **VibeAdmin Agents 联调（T7）**：`app/api/v1/endpoints/agents.py` 的 `task-analysis/data-analysis/report-generation` 改用 Pydantic body（`AgentQueryRequest`/`ReportRequest`），与前端 JSON 请求匹配；`pages/agents/index.vue` 接入 `agentsApi.taskAnalysis` 并渲染消息流。
6. **配置样例更新**：`.env.example` 补充 `OPENAI_*`、`VL_*`、`PAYMENT_NOTIFY_SECRET`；`config.dev.yaml` 白名单加入 `/api/v1/recharge/notify`。

> 实测：VibeBase 全部 GET 端点（真实用户）返回 200；对话/图片理解降级路径正常；充值 notify 验签、幂等、加积分均通过。

---

## 三·补补、第三轮（2026-07-09）统一响应与错误码

1. **全局异常统一（T8）**：`main.py` 新增 `register_exception_handlers()`，注册三类处理器：
   - `RequestValidationError` → 422，拼接 `loc: msg` 中文提示；
   - `HTTPException` → 原样 `status_code` + 中文 `status_message`（取 `exc.detail`）；
   - 兜底 `Exception` → 500 统一文案（记录日志，避免堆栈泄露）。
   所有错误体统一为 `{status_code, status_message, data, detail}`，并保留 `detail` 兼容旧前端。
2. **前端错误提取修复**：`vibe-base-web/src/utils/http.ts` 的 `extractErrorMessage` 原只读 `message/error/msg`，导致后端 `HTTPException` 的中文 `detail` 读不到、用户只看到泛化 "Bad Request"。现优先读 `status_message`，并兼容 `detail`。重复注册等错误现已能显示中文（如「用户名已被注册」）。

> 实测：重复注册→409 中文 `status_message`；缺参→422 中文；未授权→401 中文；均保留 `detail` 兼容。

---

## 三·补补补、第四轮（2026-07-09）双 token 机制 + 两前端登录闭环

用户决策：**两个端都先做登录闭环**，且**后端补充 refresh token 双 token 机制（更完整）**。

### 1. 后端双 token 机制（VibeBase）
- `api/services/user.py`：
  - `get_user_jwt()` 重写为签发**真正区分**的 access/refresh（原实现两者完全相同，是缺陷）：access 带 `type:"access"`、refresh 带 `type:"refresh"`，共享 `jti`，expire 分别为 `ACCESS_TOKEN_EXPIRE_TIME=7d` / `REFRESH_TOKEN_EXPIRE_TIME=30d`（新增于 `utils/JWT.py`）。
  - 新增 `get_user_by_refresh_token()`（校验 type/过期/黑名单）、`revoke_token()`（加入 Redis 黑名单，ttl 取剩余有效期）。
  - `get_login_user()` 鉴权时拒绝 `type=="refresh"` 的令牌被当作 access 使用。
- `api/v1/user.py`：`register`/`login`/`dev-login` 均返回 `{access_token, refresh_token}`；新增 `POST /api/v1/user/refresh`（旋转机制：吊销旧 refresh、签发全新双 token）。
- `api/v1/security.py`：`logout` 扩展为同时吊销 access + refresh（双 token 防续期）。
- `api/v1/user.py`：`GET /user/info` 改为**从鉴权 token 取当前用户**（不再依赖 `user_id` 参数，更安全，也便于前端无参调用）。

> 实测（TestClient）：register/login 返回双 token；access 可用；`refresh` 当 access 用 → 401 `Invalid token type`；logout 后 access/refresh 均 401 `Token has been revoked`（Redis 黑名单 + 旋转吊销生效）。

### 2. Vibe-Mp-H5（uni-app）登录闭环
- `env/.env`：`VITE_SERVER_BASEURL=http://localhost:8081`、`VITE_AUTH_MODE=double`、`VITE_APP_PROXY_ENABLE=true`、`VITE_APP_PROXY_PREFIX=/api`。
- `vite.config.ts`：proxy `rewrite` 改为**保留 `/api` 前缀**原样转发到后端（H5 同源无 CORS；小程序端绝对路径拼接同样正确）。
- `src/http/http.ts`：响应格式适配 VibeBase 的 `{status_code, status_message, data}`；请求自动注入 `Authorization: Bearer`；刷新请求标记 `meta.ignoreRefresh` 防止死循环。
- `src/http/tools/enum.ts`：`getResponseMessage` 优先读 `status_message`。
- `src/api/login.ts`：路径改 `/api/v1/user/{login,refresh,info,logout}`，参数/字段蛇形↔驼形映射为前端 `IDoubleTokenRes` / `IUserInfoRes`。
- `src/store/token.ts`：logout 传入 refreshToken 给后端吊销。
- 新增 `src/pages/login/index.vue` 登录页，并在 `src/pages.json` 注册。

### 3. VibeApp（Flutter）登录闭环（从零搭建，原为纯脚手架）
- `core/constants/app_config.dart`：`baseUrl`。
- `core/storage/token_storage.dart`：SharedPreferences 存双 token。
- `core/network/api_client.dart`：Dio 单例 + 拦截器（注入 Bearer、401 无感刷新双 token、刷新失败清 token）。
- `features/auth/{models,data,presentation/providers,presentation/pages}`：登录模型/仓储/riverpod 状态/登录页。
- `main.dart`：启动预加载 TokenStorage 并 `ApiClient().init()`。
- `app_router.dart`：新增 `/login` 全屏路由，`initialLocation` 指向登录页；已登录用户在登录页自动跳首页。

> 注：两个前端均完成**代码层**对接，但需在各自开发环境运行验证（Vibe-Mp-H5：`pnpm install && pnpm dev:h5`；VibeApp：`flutter pub get && flutter run`），本机无 uni-app/Flutter 运行环境，未能实跑验证。

---

## 三·补补补补、第五轮（2026-07-09）业务页深度：两端「我的」页

登录闭环已通，本轮把两端的「我的」页接到真实接口（`/user/info` + `/points/info`），形成「登录 → 个人中心 → 登出」完整闭环。

### 1. Vibe-Mp-H5（uni-app）「我的」页
- `src/api/login.ts`：新增 `getPointsInfo()`（对接 `GET /api/v1/points/info`，映射 `remaining/used/total_points`）+ `IPointsInfo` 类型。
- `src/pages/me/me.vue`：由占位页改写为真实个人中心——
  - 未登录 → 显示「去登录」按钮（`navigateTo` 到登录页）；
  - 已登录 → 并行拉取用户信息（`userStore.fetchUserInfo()`）与积分，展示头像/用户名/ID 与「剩余/已用/累计」积分卡，并提供「退出登录」（调 `tokenStore.logout()` + 清用户信息）。
  - 依赖 `onShow` 重新加载，tab 切换回来即刷新。
- `src/pages.json`：清理重复的 `login` 路由条目。

### 2. VibeApp（Flutter）「我的」页（新增 profile feature）
- `features/profile/models/profile_models.dart`：`PointsInfo`（映射 `remaining/used/total_points`）。
- `features/profile/data/profile_repository.dart`：`fetchUserInfo()` / `fetchPoints()`。
- `features/profile/presentation/providers/profile_provider.dart`：`ProfileNotifier`（并行加载，riverpod 手动 API）。
- `features/profile/presentation/pages/profile_page.dart`：个人中心 UI（渐变头 + 积分卡 + 退出登录，登出复用 `authProvider.logout()` 后跳 `/login`）。
- `app/router/app_router.dart`：新增 `/profile` 路由，并把底部导航由 4 项扩为 5 项（新增「我的」tab，`_currentIndex` 映射同步到 index 4）。

> 实测（仅后端可达）：`register` → `/user/info` 返回 `{user_id,user_name,user_avatar,...}`、`/points/info` 返回 `{remaining/used/total_points}`、`logout` 返回「已退出登录」。两个前端仅完成**代码层**，本机无 uni-app/Flutter 运行环境，未能实跑验证。

### 安全风险（待跟进，非本轮改动）
- `GET /api/v1/user/info` 返回的 `data` 直接是 `UserTable` 序列化，包含 `user_password`（哈希）等敏感字段。前端目前仅映射少量字段未渲染，但响应体本身泄露哈希。建议后端对该接口做字段白名单（只返回 `user_id/user_name/user_avatar/user_description` 等）。

---

## 三·补补补补补、第六轮（2026-07-09）品牌统一 + 全量接口层 + 对话核心

### 1. 品牌统一（两端与 Base 前端 vibe-base-web 对齐）
- **主色**：`#2563eb`（亮）/ `#3b82f6`（暗）；圆角 0.75rem；蓝色光晕 + 毛玻璃。
- **Logo**：蓝色圆形 + 白色字母 V（`src/static/logo.svg` 已替换为该样式；Flutter 新增 `BrandLogo` 组件）。
- **名称/描述**：
  - Vibe-Mp-H5：`package.json` name→`vibe-app`、`manifest.json` name→`VibeApp`、描述统一；`pages.json` 导航栏标题→`VibeApp`、tabBar 选中色→`#2563eb`；`uni.scss` 主色→`#2563eb`；新增 `src/config/brand.ts` 品牌常量 + 全局品牌样式（aura/glass/`.vibe-logo`/`.text-brand`/`.bg-brand-gradient`）。
  - VibeApp(Flutter)：`app_colors.dart` 主色族改蓝、`vibe_theme.dart` 暗色主色→`#3b82f6`、`pubspec.yaml` 描述统一；新增 `brand.dart` 常量、`BrandLogo` 组件；Android/iOS 应用名此前已是 `VibeApp`。
- **配色实测**：后端冒烟 8 个端点（公告/能力/充值套餐/对话列表/积分流水/安全日志/API Key/工单）均 200。

### 2. 全量接口层（两端覆盖 VibeBase /api/v1 全部 ~60 端点）
- **Vibe-Mp-H5** `src/api/`：`login`(auth/user/profile，清理原占位假接口) + `points` + `chat`(SSE 流式 `streamChat`/上传/点赞点踩) + `dialog` + `recharge` + `content`(公告/能力) + `support`(工单/反馈) + `security`(操作日志/设备/API Key) + `admin`(角色/子账号/用量/消费/图片理解) + `types` + 统一出口 `index.ts`。
- **VibeApp(Flutter)** `core/`：`api_endpoints.dart`(全端点常量) + `models/api_models.dart`(全 DTO) + `network/api_service.dart`(覆盖全部端点，含 Dio `ResponseType.stream` 实现的 `streamChat` 流式)。

### 3. 核心对话体验（两端）
- **Vibe-Mp-H5**：`pages/index/index.vue` 重写为 AI 主页（开始对话/最近对话/AI 能力/公告）；新增 `pages/chat/index.vue`(SSE 流式、自动建对话、历史入口)、`pages/dialog/list.vue`(历史/删除)、`pages/announcement/detail.vue`；均注册进 `pages.json`。
- **VibeApp(Flutter)**：新增 `features/chat`(repository/provider/页面) 流式对话 + `dialog_list_page`；`app_router` 注册 `/chat`、`/dialog`；`profile_page` 品牌蓝化并增加「AI 对话/对话历史/意见反馈」入口。

### 待办（接口已就绪，页面待建；非阻断）
- Vibe-Mp-H5：充值/积分页、反馈工单页、安全/API Key 页、资料编辑页。
- VibeApp：充值/积分 UI、公告能力 UI、反馈工单、安全/API Key、资料编辑。
- 两端 App 图标（PNG）需以蓝色 V 重制（二进制无法在此生成）；uni-app 非 H5 端 SSE 需原生层桥接。

---

## 四、实施优先级建议

1. 先完成 **P0（T1/T2/T3）**，让 C 端产品核心闭环（账号/对话/改密）真实可用。
2. 再推进 **P1（T4~T7）** 增强运营与体验。
3. 最后做 **P2** 工程化收尾与多端接入。
