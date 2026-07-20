# 技术架构

VibeBase 采用**主流、稳定、易招聘**的技术栈，避免冷门框架带来的维护与招聘成本。本页是整体架构的全景说明。

## 架构全景

![VibeBase 技术架构总览](/hero-architecture.svg)

下面是完整的分层架构（文字版）：

```
┌─────────────────────────── 客户端层 ───────────────────────────┐
│                                                                  │
│   VibeBase Web        VibeApp         Vibe-Mp-H5     VibeAdmin  │
│   Vue3 + Vite         Flutter         uni-app        Vue3+Vite  │
│   :5175               (App)           :5174          :5173      │
│                                                                  │
└──────────┬──────────────┬──────────────┬──────────────┬─────────┘
           │              │              │              │
           │   HTTP / SSE (JWT Bearer)   │              │
           │              │              │              │
┌──────────▼──────────────▼──────────────▼──────────────▼─────────┐
│                      API 网关层（FastAPI）                       │
│                                                                  │
│   VibeBase API (:8081)              VibeAdmin API (:8080)       │
│   ┌─────────────────────┐           ┌─────────────────────┐    │
│   │ 中间件               │           │ 中间件               │    │
│   │  - CORS              │           │  - CORS              │    │
│   │  - 白名单标记         │           │  - 白名单标记         │    │
│   │  - Redis 限流         │           │  - Redis 限流         │    │
│   │  - 全局异常处理        │           │  - 全局异常处理        │    │
│   ├─────────────────────┤           ├─────────────────────┤    │
│   │ Router → Service → DAO         │ │ Router → Service → DAO│    │
│   │ 统一响应 UnifiedResponseModel  │ │                       │    │
│   └──────────┬──────────┘           └──────────┬──────────┘    │
└──────────────┼──────────────────────────────────┼──────────────┘
               │                                  │
┌──────────────▼──────────────────────────────────▼──────────────┐
│                         数据层                                   │
│                                                                  │
│   PostgreSQL (共享)              Redis (各自连接)                │
│   ┌──────────────────┐           ┌──────────────────┐          │
│   │ users / roles    │           │ 限流计数器         │          │
│   │ points / orders  │           │ Token 黑名单       │          │
│   │ dialogs / logs   │           │ 缓存              │          │
│   │ ... 20+ 张表     │           └──────────────────┘          │
│   └──────────────────┘                                         │
│                                                                 │
│   对象存储 S3/MinIO (头像等)                                    │
└─────────────────────────────────────────────────────────────────┘
               │
┌──────────────▼─────────────────────────────────────────────────┐
│                      外部服务层                                  │
│                                                                  │
│   LLM (OpenAI 兼容 / 通义千问)   支付网关 (微信/支付宝)          │
└─────────────────────────────────────────────────────────────────┘
```

## 用户端（VibeBase Web）

::: code-group

```text [技术栈]
框架      Vue 3.5 + TypeScript 5.8
构建      Vite 6
样式      Tailwind CSS 4
状态      Pinia 3 + pinia-plugin-persistedstate
UI        shadcn-vue (基于 Reka UI)
路由      Vue Router 4 (hash 模式)
HTTP      axios
SSE       @microsoft/fetch-event-source
富文本    Tiptap 3 (starter-kit + image)
Markdown  marked + highlight.js
图标      lucide-vue-next + @iconify/vue
```

```text [目录约定]
src/
├── apis/         按模块组织的 API 调用（18 个模块）
├── components/   组件（chat / console / ui / login / home ...）
├── composables/  组合式函数（useAuth / usePoints / useTable）
├── stores/       Pinia 仓库（19 个 store）
├── views/        页面（auth / console / user / legal / error）
├── router/       路由配置
├── config/       常量
├── types/        TypeScript 类型
└── utils/        工具函数（http / storage / markdown-parser）
```

:::

## 后端（VibeBase API）

::: code-group

```text [技术栈]
框架      FastAPI 0.115 + Uvicorn 0.34
语言      Python 3.12
包管理    Poetry
ORM       SQLAlchemy 2.0 + SQLModel
数据库    PostgreSQL (asyncpg 异步 / psycopg2 同步)
缓存      Redis 5.2
认证      JWT (python-jose) + bcrypt
AI        OpenAI SDK 1.95 + LangChain Core 0.3
配置      pydantic-settings + YAML
日志      loguru
```

```text [目录约定]
vibe-base/
├── main.py            应用入口（FastAPI app + 中间件 + 异常处理）
├── settings.py        YAML 配置加载
├── api/
│   ├── router.py      路由总聚合
│   ├── v1/            API v1 端点（按模块分文件）
│   ├── services/      业务服务层
│   └── errcode/       错误码定义
├── database/
│   ├── models/        ORM 模型
│   ├── dao/           数据访问层
│   └── init_data.py   种子数据
├── schema/            Pydantic 请求/响应模型
├── config/            config.{ENV}.yaml
├── utils/             工具（JWT / hash / constants）
└── vibe_common/       共享核心库（配置 / 数据库 / 模型）
```

:::

### 三层架构

后端严格遵循 **Router → Service → DAO** 分层：

```
请求 → Router (api/v1/xxx.py)        路由、参数校验、认证
         ↓
      Service (api/services/xxx.py)   业务逻辑编排
         ↓
      DAO (database/dao/xxx.py)       数据库 CRUD
         ↓
      Model (vibe_common/models/)     ORM 模型定义
```

- **Router 层** 只做 HTTP 相关的事：接收请求、校验参数、调用 Service、包装响应
- **Service 层** 承载业务逻辑：积分扣减、订单创建、流式调用等
- **DAO 层** 只关心数据库操作：增删改查，不包含业务判断

详见 [后端开发规范](../development/backend-conventions)。

### 统一响应格式

所有非流式接口都返回统一的 `UnifiedResponseModel`：

```json
{
  "status_code": 200,
  "status_message": "SUCCESS",
  "data": { ... },
  "detail": "（兼容旧前端的附加字段）"
}
```

唯一例外是对话接口 `/chat`，它返回 `text/event-stream` 的 SSE 流。详见 [聊天与流式](../development/chat-streaming)。

## 移动端（VibeApp）

```text
框架      Flutter
语言      Dart
状态      （待补充）
构建      build_runner (代码生成)
测试      Flutter widget/unit tests
```

VibeApp 复用 VibeBase 的全部 API，只是换了 Flutter 的 UI 壳。详见 [多端协作 · VibeApp](../multi-end/vibeapp)。

## 小程序端（Vibe-Mp-H5）

```text
框架      uni-app
语言      Vue 3 SFC (script setup)
样式      Tailwind 优先
构建      Vite (pnpm)
测试      Vitest + jsdom
语法检查  ESLint
```

Vibe-Mp-H5 一套代码同时编译出微信小程序与 H5，复用 VibeBase API。详见 [多端协作 · Vibe-Mp-H5](../multi-end/vibe-mp-h5)。

## 运营后台（VibeAdmin）

与 VibeBase 技术栈几乎一致（Vue 3 + FastAPI），但多了一套后台专属的 UI 组件（`@antfu/eslint-config`、2 空格缩进）。详见 [多端协作 · VibeAdmin](../multi-end/vibeadmin)。

## 数据流：一次对话的完整链路

以用户发送一条消息为例，展示各层如何协作：

```
1. 用户在 VibeBase Web 输入消息，点击发送
        │
2. 前端 POST /api/v1/chat (Authorization: Bearer <token>)
   请求体: { dialog_id, user_input, open_search, ... }
        │
3. FastAPI 中间件链:
   mark_whitelist_paths → rate_limit_middleware → 路由匹配
        │
4. Router (api/v1/chat.py):
   get_login_user 依赖 → 解析 JWT → 校验黑名单 → 得到 user_id
        │
5. Service (api/services/chat.py):
   - 解析能力定价 (abilities 表, 默认 AB001 / 5 积分)
   - 检查积分余额，不足返回 402
   - 扣减积分 (consume_points)
   - 加载最近 10 条历史 (histories 表)
        │
6. StreamingAgent 调用 LLM (OpenAI 兼容 / 通义千问)
   逐字流式返回 → SSE event: response_chunk
        │
7. 流结束:
   - 持久化用户消息 + AI 回复到 histories 表
   - 写入 api_logs (积分消耗 / 响应耗时 / 状态)
        │
8. 前端逐字渲染 → 消息气泡 → 用户看到回复
```

## 关键设计决策

### 为什么用 PostgreSQL 而非 MySQL / SQLite

- **JSON 支持** — `histories.events` 字段存储 SSE 事件 JSON，PostgreSQL 的 JSONB 更高效
- **与 VibeAdmin 共享** — 统一一个数据库实例，避免数据孤岛
- **Decimal 精度** — `balance` / `amount` 等金额字段用 `Numeric(12,2)`，避免浮点误差

### 为什么 JWT 用双 Token

- access token 短期有效（7 天），泄露风险可控
- refresh token 长期有效（30 天），用于无感续签
- Redis 黑名单实现「主动撤销」，弥补 JWT 无法服务端踢人的缺陷

详见 [开发指南 · 认证机制](../development/authentication)。

### 为什么用 SSE 而非 WebSocket

- **单向推送** — 对话只需要服务端 → 客户端单向流，SSE 足够
- **HTTP 友好** — 走标准 HTTP，天然过 Nginx / CDN，无需额外协议升级
- **断线重连** — 浏览器原生支持 EventSource 的自动重连

### 为什么后端不用异步 ORM 为主

- DAO 层以**同步 SQLAlchemy Session** 为主（`database/dao/*`），代码简单直观
- `vibe_common` 同时暴露了异步引擎，供 VibeAdmin 等异步场景使用
- 同步 DAO 通过自动改写连接串（`+asyncpg` → `+psycopg2`）复用同一组模型

## 接下来

- [快速开始](../quickstart/requirements) — 把架构跑起来
- [开发指南](../development/structure) — 深入代码结构
- [配置](../configuration/backend) — 配置这套架构
