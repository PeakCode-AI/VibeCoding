# 项目结构

VibeBase 分为 **后端（`vibe-base/`）** 与 **前端（`vibe-base-web/`）** 两个独立工程，后端采用 FastAPI 的三层架构，前端采用 Vue 3 + Vite 的单页应用。本页给出完整的目录树与各层职责，方便你快速定位代码。

::: tip 阅读顺序
如果你只看一页，先看本页了解「东西在哪」，再看 [后端开发规范](./backend-conventions) / [前端开发规范](./frontend-conventions) 了解「怎么写」。
:::

## 后端目录结构

```text
vibe-base/
├── main.py                应用入口：FastAPI app + 中间件 + 全局异常处理
├── settings.py            YAML 配置加载（config.{ENV}.yaml → app_settings）
├── api/
│   ├── router.py          路由总聚合（include_router + tags）
│   ├── v1/                API v1 端点（按模块分文件，22 个模块）
│   │   ├── user.py        用户与认证
│   │   ├── chat.py        对话（SSE 流式）
│   │   ├── dialog.py      会话管理
│   │   ├── message.py     消息点赞/点踩
│   │   ├── history.py     对话历史
│   │   ├── recharge.py    充值与支付
│   │   ├── apikey.py      API Key 管理
│   │   ├── points.py      积分概览/流水
│   │   ├── ability.py     AI 能力定价
│   │   ├── analytics.py   用量分析
│   │   ├── profile.py     个人资料
│   │   ├── role.py        角色权限
│   │   ├── security.py    安全中心
│   │   ├── feedback.py    用户反馈
│   │   ├── ticket.py      工单
│   │   ├── accounts.py    子账号
│   │   ├── consume.py     消费记录
│   │   ├── announcement.py 公告
│   │   ├── console.py     控制台聚合
│   │   └── misc.py        其他杂项
│   ├── services/          业务服务层（业务逻辑编排）
│   │   ├── user.py        认证依赖、UserPayload、密码校验、签发 JWT
│   │   ├── chat.py        StreamingAgent：LLM 流式调用、降级
│   │   ├── dialog.py      会话 CRUD
│   │   ├── history.py     历史消息加载/持久化
│   │   └── message.py     消息互动
│   └── errcode/           错误码定义
├── database/
│   ├── models/            本端 ORM 模型（少量本端专用）
│   ├── dao/               数据访问层（纯 CRUD，无业务逻辑）
│   │   ├── point.py       积分账户与流水（add_points / consume_points）
│   │   ├── user.py        用户增删改查
│   │   ├── apikey.py / dialog.py / ticket.py / ...
│   └── init_data.py       种子数据（初始化角色、管理员、能力）
├── schema/                Pydantic 请求/响应模型
│   ├── schemas.py         UnifiedResponseModel、resp_200/400/404/500
│   └── chat.py            ConversationReq（对话请求）
├── config/                config.{dev,staging,production}.yaml
├── utils/                 工具（JWT、hash、constants）
│   └── JWT.py             ACCESS/REFRESH 过期时间、JWT_SECRET_KEY
└── vibe_common/           共享核心库（VibeBase 与 VibeAdmin 共用）
    ├── core/              配置（pydantic-settings 读 .env）
    ├── db/                数据库引擎（同步 + 异步）、Redis 客户端
    ├── models/            ORM 模型（20+ 张表，权威定义）
    ├── storage/           对象存储（S3/MinIO）
    └── security/          bcrypt 等通用安全工具
```

## 前端目录结构

```text
vibe-base-web/src/
├── apis/                  按模块组织的 API 调用（16 个模块）
│   ├── user/userApi.ts    用户相关接口
│   ├── chat/chatApi.ts    会话与消息
│   ├── points/            积分
│   ├── recharge/          充值
│   ├── apikey/            API Key
│   ├── ability / analytics / announcement / role / security / ...
│   └── (每个模块: {module}Api.ts 返回 axios Promise)
├── components/            组件（按职能分组）
│   ├── chat/              对话核心（Chat.vue 用 fetchEventSource 处理 SSE）
│   ├── console/           控制台业务组件
│   ├── ui/                shadcn-vue 基础组件（Button / Dialog / ...）
│   ├── login/ home/ sidebar/ settings/ layout/ user/ pricing/ icons/ demo/
├── composables/           组合式函数（useAuth / usePoints / useTable）
├── stores/                Pinia 仓库（19 个 store）
│   ├── authStore.ts       登录态、token
│   ├── userStore.ts       用户信息
│   ├── pointsStore.ts     积分
│   ├── rechargeStore.ts / consumeStore.ts / apiKeyStore.ts / ...
│   └── counter.ts         示例 store
├── views/                 页面级组件
│   ├── auth/              登录/注册
│   ├── chat/              对话页
│   ├── console/           控制台各子页（Dashboard/Recharge/ApiKey/...）
│   ├── user/              用户设置
│   ├── history/           历史会话
│   ├── legal/             协议条款
│   ├── error/             404/500
│   ├── HomeLayout.vue     首页外壳
│   ├── ConsoleLayout.vue  控制台外壳
│   └── LandingPage.vue    落地页
├── router/index.ts        路由配置（hash 模式 + meta.requiresAuth）
├── config/constants.ts    常量
├── types/                 TypeScript 类型定义
└── utils/                 工具（httpUtil / storage / markdown-parser）
```

## 三层架构

后端严格遵循 **Router → Service → DAO** 分层，这是阅读任何后端功能的主线：

```text
HTTP 请求
   │
   ▼
Router 层（api/v1/xxx.py）
   • 路径声明、HTTP 方法、tags 分组
   • 参数校验（Pydantic schema）
   • 认证依赖（Depends(get_login_user)）
   • 调用 Service，包装 resp_200 / resp_400
   │
   ▼
Service 层（api/services/xxx.py）
   • 业务逻辑编排：积分扣减、订单创建、流式调用
   • 跨 DAO 协作（如 chat 同时写 histories + api_logs）
   • 调用外部服务（LLM、支付网关）
   │
   ▼
DAO 层（database/dao/xxx.py）
   • 纯数据库 CRUD，不包含业务判断
   • 一个 DAO 类对应一张/一组表
   │
   ▼
Model 层（vibe_common/models/xxx.py）
   • SQLAlchemy ORM 模型（权威表结构定义）
```

::: warning 分层纪律
- **Router 不写业务逻辑**：只做参数校验、认证、响应包装
- **DAO 不写业务逻辑**：只做 `SELECT/INSERT/UPDATE/DELETE`，不做「余额够不够」「订单状态对不对」这类判断
- **Service 不直接返回 HTTP**：Service 抛异常或返回业务对象，由 Router 决定如何包装响应
:::

详见 [后端开发规范](./backend-conventions)。

## 前后端模块映射

一个功能在前端、后端各有一组对应的文件，下表是常见模块的对照：

| 功能域 | 前端 API 模块 | 前端 Store | 后端 Router | 后端 Service / DAO |
| --- | --- | --- | --- | --- |
| 用户与认证 | `apis/user/userApi.ts` | `authStore.ts`、`userStore.ts` | `api/v1/user.py` | `services/user.py`、`dao/user.py` |
| 对话（SSE） | `apis/chat/chatApi.ts` | `authStore` + 组件内 fetchEventSource | `api/v1/chat.py` | `services/chat.py`、`services/history.py` |
| 会话管理 | `apis/chat/chatApi.ts` | — | `api/v1/dialog.py` | `services/dialog.py`、`dao/dialog.py` |
| 积分 | `apis/points/` | `pointsStore.ts` | `api/v1/points.py` | `dao/point.py` |
| 充值 | `apis/recharge/` | `rechargeStore.ts` | `api/v1/recharge.py` | `dao/point.py`（加积分） |
| 消费记录 | `apis/` | `consumeStore.ts` | `api/v1/consume.py` | `dao/*` |
| API Key | `apis/apikey/` | `apiKeyStore.ts` | `api/v1/apikey.py` | `dao/apikey.py` |
| 用量分析 | `apis/analytics/` | `analyticsStore.ts` | `api/v1/analytics.py` | — |
| 角色 | `apis/role/` | `roleStore.ts` | `api/v1/role.py` | `dao/user_role.py` |
| 工单 | `apis/` | `ticketStore.ts` | `api/v1/ticket.py` | `dao/ticket.py` |
| 子账号 | `apis/account/` | `accountStore.ts` | `api/v1/accounts.py` | `dao/sub_account.py` |

::: tip 命名映射规律
后端模块名是 Python 文件名（`apikey.py`），前端 API 模块目录是对应的 camelCase/全小写（`apis/apikey/apikeyApi.ts`），前端 Store 是 `apiKeyStore.ts`（PascalCase 拼接 `Store`）。
:::

## vibe_common：共享核心库

`vibe_common/` 是 **VibeBase 与 VibeAdmin 共用的核心库**，目的是避免两套后端重复定义模型与基础设施。

| 子包 | 职责 | 关键内容 |
| --- | --- | --- |
| `core/` | 配置加载 | `config.py`（pydantic-settings 读 `.env`：`DATABASE_URL`、`REDIS_URL`、`SECRET_KEY`、`S3_*`、`OPENAI_*`、`PAYMENT_NOTIFY_SECRET`） |
| `db/` | 数据库与缓存 | 同步/异步 SQLAlchemy 引擎、`redis.py`（限流 `rate_limit_sync`、Token 黑名单 `bl:{token}`） |
| `models/` | ORM 模型（权威） | 20+ 张表：users / point_accounts / recharge_orders / abilities / api_logs / ... |
| `storage/` | 对象存储 | S3 / MinIO 封装（头像、上传文件） |
| `security/` | 安全工具 | bcrypt 哈希（VibeAdmin 种子数据用） |

::: info 为什么 DAO 同步、模型共享
DAO 层以**同步 SQLAlchemy Session** 为主（`database/dao/*`），简单直观；`vibe_common` 同时暴露了异步引擎供 VibeAdmin 等异步场景使用。同步 DAO 通过自动改写连接串（`+asyncpg` → `+psycopg2`）复用 `vibe_common/models` 中的同一组模型定义。
:::

## 共享数据库架构

VibeBase 与 VibeAdmin **连接同一个 PostgreSQL 实例**，共享 `users`、`roles`、`point_accounts`、`recharge_orders`、`api_logs`、`operation_logs` 等核心业务表。这意味着：

- VibeAdmin 后台修改的用户余额、订单状态，VibeBase 用户端立即可见
- VibeBase 用户注册产生的数据，VibeAdmin 后台可直接运营

各表完整字段见 [数据模型](./data-models)。

## 接下来

- [后端开发规范](./backend-conventions) — 如何新增一个后端端点
- [前端开发规范](./frontend-conventions) — 如何新增一个前端页面
- [认证机制](./authentication) — JWT 双 Token 与依赖注入
- [数据模型](./data-models) — 全部表的字段参考
