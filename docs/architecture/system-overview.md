# 系统架构总览

## 1. 两入口体系

Vibe 产品体系的**最终用户**与**运营人员**走完全独立的入口，后端共用同一套数据库：

```
   ┌─────────────────────────────────────────────────────────┐
   │                    最终用户                              │
   │         使用 AI 对话、充值、管理 API Key                   │
   └──────┬──────────────────┬────────────────────┬───────────┘
          │                  │                    │
     ┌────▼────┐      ┌─────▼──────┐      ┌──────▼───────┐
     │VibeApp  │      │Vibe-Mp-H5  │      │  VibeBase    │
     │Flutter  │      │ 小程序+H5  │      │  Web 端      │
     │iOS/Andr │      │ (微信/H5)  │      │ (桌面浏览器)  │
     └────┬────┘      └─────┬──────┘      └──────┬───────┘
          │                 │                    │
          └─────────────────┼────────────────────┘
                            │
                     ┌──────▼───────┐
                     │VibeBase 后端  │
                     │ 用户端 API    │
                     │ FastAPI:8081  │
                     └──────┬───────┘
                            │
                     ┌──────▼───────┐
                     │VibeAdmin 后端 │
                     │ 运营管理 API  │
                     │ FastAPI:8080  │
                     └──────┬───────┘
                            │
                     ┌──────▼───────┐
                     │PostgreSQL+Redi│
                     │ 共享数据库     │
                     └──────────────┘
```

```
   ┌──────────────────────────────────────────────────────────┐
   │                  运营人员 / 管理员                         │
   │   管理用户、订单、角色、系统设置                            │
   └──────────────────────────┬───────────────────────────────┘
                              │
                       ┌──────▼───────┐
                       │ VibeAdmin Web │
                       │ 管理后台前端   │
                       │ Vue3+shadcn   │
                       │ 浏览器 :5173   │
                       └──────┬───────┘
                              │
                       ┌──────▼───────┐
                       │VibeAdmin 后端│
                       │ 运营管理 API  │
                       │ FastAPI:8080  │
                       └──────┬───────┘
                              │
                       ┌──────▼───────┐
                       │ PostgreSQL    │
                       │ (同一共享数据库)│
                       └──────────────┘
```

### 分层角色

| 层 | 子项目 | 服务对象 | 核心职责 |
| --- | --- | --- | --- |
| B 端（管理后台） | VibeAdmin | 运营人员 / 管理员 | 用户管理、权限(RBAC)、AI 能力配置、订单/收入、工单、系统设置 |
| C 端（用户端） | VibeBase | 最终用户 | 智能对话、账户体系、调用运营能力 |
| 移动端（App） | VibeApp | 移动用户 | 原生跨端体验，对接 VibeBase 与 VibeAdmin 后端 |
| 移动端（小程序/H5） | Vibe-Mp-H5 | 移动用户 / 微信用户 | uni-app 小程序 + H5 跨端应用，一套代码运行于微信小程序与浏览器 H5 |

## 2. 职责划分

### VibeAdmin（B 端）
- 通用后台脚手架底座：JWT 认证、RBAC 引擎、shadcn-vue 组件库、i18n、暗色主题、Command Menu、TanStack Query 数据层、文件路由。
- 内置示例业务（AI 能力运营后台）：仪表盘、用户/管理员/角色、充值订单、收入统计、AI 能力、API 调用日志、工单、公告、系统设置。
- 可作为任意 SaaS/运营后台的二次开发底座。

### VibeBase（C 端）
- 面向最终用户的智能对话产品。
- 包含 C 端 Web 前端（`vibe-base-web/`）与 FastAPI 后端（`vibe-base/`）。
- 提供 14 个 HTML 设计原型（`ui/`）作为产品视觉基线。
- 后端依赖 PostgreSQL 作为主数据库。

### VibeApp（移动端 - App）
- Flutter 跨端 App，复用 VibeBase 的对话/数据服务与 VibeAdmin 的管理能力。
- 状态管理 Riverpod、路由 GoRouter、网络 Dio、本地存储 SharedPreferences。

### Vibe-Mp-H5（移动端 - 小程序 + H5）
- 基于 `unibest`（uniapp 开发框架），基于 `uni-app` + `Vue 3` + `TypeScript` + `Vite` + `UnoCss` + `Wot UI` + `z-paging`。
- 一套代码同时编译到 **微信小程序 (mp-weixin)** 与 **H5**，也可扩展至支付宝/百度/抖音/快手等小程序平台。
- 内置约定式路由、Layout 布局、请求封装/拦截、登录拦截、i18n 多语言、UnoCSS 原子化样式。
- 前端状态管理使用 Pinia，HTTP 请求使用 alova，UI 组件库使用 Wot UI，列表滚动使用 z-paging。
- VSCode 开发，命令行运行，不依赖 HBuilderX。

## 3. 技术栈对照

| 维度 | VibeAdmin | VibeBase | VibeApp | Vibe-Mp-H5 |
| --- | --- | --- | --- | --- |
| 前端框架 | Vue 3.5 + Vite 7 + TS 5.8 | Vue 3 + TS | Flutter / Dart | uni-app + Vue 3 + Vite + TS |
| UI | Tailwind 4 + shadcn-vue | Vue 3 + TS | 40+ 内置组件 | Wot UI + UnoCss |
| 后端 | FastAPI + Uvicorn | FastAPI | — | — |
| 状态/数据 | Pinia 3 + TanStack Query 5 | — | Riverpod + GoRouter | Pinia |
| HTTP 客户端 | axios | Dio | Dio | alova |
| 数据库 | PostgreSQL（统一主库） | PostgreSQL（统一主库） | SharedPreferences | — |
| 缓存 | Redis（令牌黑名单 / 限流） | Redis（限流） | — | — |
| 认证 | JWT (python-jose + bcrypt) | JWT (python-jose + bcrypt) | — | — |

## 4. 统一数据库（各自 vendored 的 vibe_common）

三端后端（VibeAdmin、VibeBase）统一到**同一套数据库（同一个 PostgreSQL + 同一个 Redis）**；但 `vibe_common`（模型 / 数据库 / Redis / 配置 / 安全）已 **vendored 进各自后端目录内**（`VibeAdmin/vibe-admin/vibe_common/` 与 `VibeBase/vibe-base/vibe_common/` 各一份），不再依赖仓库根目录的共享库：

- **一套表结构、两份拷贝**：所有 ORM 模型（用户、角色、订单、工单、对话、消息等）定义在各自后端内的 `vibe_common/models/` 中，二者内容一致、指向同一数据库，避免「两套用户 / 两套订单」的分裂。注意两份拷贝需人工保持一致。
- **统一的 Base 与引擎**：`vibe_common/db/base.py` 提供 `Base`（含 `to_dict()`）、异步引擎（Admin 用）、同步引擎（VibeBase 用），两者指向同一 `DATABASE_URL`。
- **统一 Redis**：`vibe_common/db/redis.py` 提供令牌黑名单、限流、缓存的同步/异步封装，两端共用。

### 两套用户体系（明确分离）

| 体系 | 表 | 说明 |
| --- | --- | --- |
| 管理后台用户 | `admin_users` / `admin_roles` | 仅 VibeAdmin（B 端）使用，独立于 C 端 |
| C 端用户 | `users` / `roles` / `user_roles` | Admin 运营查看 与 Base 产品使用 **同一张 `users` 表、同一份数据** |

> 关键约束：管理端的「注册用户」就是前端的用户（共用 `users`）；管理端看到的充值记录（`recharge_orders`）、工单（`tickets`）等，其 `user_id` 都指向 `users.user_id`。管理员账户本身不在 `users` 中。

## 5. 数据流与依赖关系

```
用户端入口（3个）：                             运营端入口（1个）：
VibeApp ──┐                                    VibeAdmin ──┐
Vibe-Mp-H5 ──┤                                    │
VibeBase Web ──┘                                  │
       │                                        │
       └── VibeBase 后端 (:8081)                └── VibeAdmin 后端 (:8080)
                 │                                        │
                 └── 同一 PostgreSQL + Redis ──────────────┘
```

- VibeApp、Vibe-Mp-H5、VibeBase 三者共享同一套对话/数据服务契约，Vibe-Mp-H5 作为轻量化前端层，其接口标准与 VibeBase 对齐。
- VibeAdmin 与 VibeBase 各自 vendored 的 `vibe_common` 指向同一数据库，C 端用户/订单/工单数据天然一致（两份模型需人工保持同步）。
- 各后端独立部署，可通过 Nginx 反向代理（如 VibeAdmin 的 `/api/`）聚合对外。

## 6. 部署拓扑（端口对照）

| 服务 | 端口 | 说明 |
| --- | --- | --- |
| VibeAdmin 前端 | 80 / 5173 | Nginx 反代 `/api/` → 8080 |
| VibeAdmin 后端 | 8080 | FastAPI |
| VibeBase 前端 | 80 / 5175 | Nginx（Docker 多阶段） |
| VibeBase 后端 | 8081 / 8881 | FastAPI（API / 管理） |
| PostgreSQL | 5432 | VibeBase 主库 |

详细部署方式见 [../guides/deployment.md](../guides/deployment.md)。
