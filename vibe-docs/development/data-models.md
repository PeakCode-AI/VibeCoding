# 数据模型

本页是 VibeBase 数据库表的**完整字段参考**。所有表定义在 `vibe_common/models/`，由 VibeBase 与 VibeAdmin 共享同一个 PostgreSQL 实例。共 22 张表，按业务域分组：用户体系、计费体系、对话体系、运营体系、开发体系。

## 共享数据库架构

```text
┌──────────────────────────────────────────────────────────────┐
│                   PostgreSQL（共享实例）                       │
│                                                              │
│  ┌─── 用户体系 ───┐  ┌─── 计费体系 ───┐  ┌── 对话体系 ──┐   │
│  │ users          │  │ point_accounts  │  │ dialogs       │   │
│  │ roles          │  │ point_transactions│ │ histories    │   │
│  │ user_roles     │  │ recharge_orders │  │ message_likes │   │
│  │ admin_users    │  │ abilities       │  │ message_downs │   │
│  │ admin_roles    │  │ api_logs        │  └───────────────┘   │
│  └────────────────┘  └─────────────────┘                      │
│                                                              │
│  ┌─── 运营体系 ───┐  ┌─── 开发体系 ───┐                      │
│  │ announcements  │  │ api_keys        │                      │
│  │ tickets        │  │ sub_accounts    │                      │
│  │ feedbacks      │  │ tasks           │                      │
│  │ operation_logs │  │ system_config   │                      │
│  └────────────────┘  └─────────────────┘                      │
└──────────────────────────────────────────────────────────────┘
        ▲                                  ▲
        │              共享读写             │
┌───────┴──────────┐              ┌────────┴─────────┐
│  VibeBase API    │              │  VibeAdmin API   │
│  （用户端 :8081） │              │ （运营后台 :8080）│
└──────────────────┘              └──────────────────┘
```

::: tip 一次定义，两端共享
VibeBase 与 VibeAdmin 连接同一个 PostgreSQL，共用 `vibe_common/models` 中的 ORM 模型。VibeAdmin 后台改的余额/订单/角色，VibeBase 用户端立即可见，反之亦然。
:::

## 通用约定

- **主键**：除 `roles`（自增整型）、`system_config`（固定整型）外，业务表主键均为 `String(36)` 的 UUID
- **业务编号前缀**：`RC`=订单、`TK`=工单、`LOG`=日志、`AB`=能力、`ANN`=公告、`A`=管理员、`TASK-`=任务
- **金额字段**：`Numeric(12, 2)`（如 `balance`、`amount`、`consume_limit`），避免浮点误差
- **时间字段**：`created_at` / `create_time`（默认 `func.now()`），部分表有 `updated_at` / `update_time`（`onupdate=func.now()`）

## 用户体系

### users — 用户主表

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `user_id` | String(36) | **PK**, 默认 uuid4 | 用户唯一 ID |
| `user_name` | String(50) | unique, index, not null | 用户名 |
| `user_email` | String(100) | index | 邮箱 |
| `user_phone` | String(20) | index | 手机号 |
| `user_avatar` | String(255) | | 头像 URL |
| `user_description` | String(255) | 默认 "" | 个人简介 |
| `user_password` | String(255) | | 密码哈希（bcrypt `$2` 或 SHA-256 hex） |
| `delete` | Boolean | 默认 False | 软删除标记 |
| `balance` | Numeric(12,2) | 默认 0.00 | 钱包余额（金额，区别于积分） |
| `status` | String(20) | not null, 默认 ACTIVE | 用户状态 |
| `create_time` | DateTime | not null | 创建时间 |
| `update_time` | DateTime | not null | 更新时间 |

::: warning balance vs points
`users.balance` 是钱包金额（`Numeric(12,2)`），与积分系统无关。AI 对话扣的是**积分**（`point_accounts.points`），不是 `balance`。详见 [积分系统](./points-system)。
:::

### roles — 角色表

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | Integer | **PK**, autoincrement | 角色 ID |
| `role_name` | String(50) | unique, index, not null | 角色名（前端展示） |
| `remark` | String(255) | | 备注 |
| `group_id` | Integer | index | 角色组 ID |
| `create_time` | DateTime | not null | 创建时间 |
| `update_time` | DateTime | not null | 更新时间 |

角色 ID 常量（`database/models/role.py`）：

| 常量 | 值 | 含义 |
| --- | --- | --- |
| `SystemRole` | 0 | 系统管理员 |
| `AdminRole` | 1 | 超级管理员 |
| `DefaultRole` | 2 | 默认普通用户 |

### user_roles — 用户-角色关联

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | String(36) | **PK**, 默认 uuid4 | |
| `user_id` | String(36) | index, not null | → `users.user_id` |
| `role_id` | Integer | index, not null | → `roles.id` |
| `create_time` | DateTime | not null | |
| `update_time` | DateTime | not null | |

### admin_users — 管理员用户（VibeAdmin）

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | String(36) | **PK**, 默认 uuid4 | |
| `admin_id` | String(20) | unique, index, not null | 管理员编号（如 `A001`） |
| `username` | String(50) | unique, index, not null | 用户名 |
| `email` | String(100) | unique, index, not null | 邮箱 |
| `first_name` | String(50) | 默认 "" | 名 |
| `last_name` | String(50) | 默认 "" | 姓 |
| `password_hash` | String(255) | not null | 密码哈希（bcrypt） |
| `avatar` | String(512) | | 头像 |
| `role` | String(20) | not null, 默认 SUPER_ADMIN | 管理员角色 |
| `status` | String(20) | not null, 默认 ACTIVE | 状态 |
| `is_active` | Boolean | not null, 默认 True | 是否启用 |
| `last_login` | DateTime | | 最后登录时间 |
| `created_at` | DateTime | not null | |
| `updated_at` | DateTime | not null | |

### admin_roles — 管理员角色

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | String(36) | **PK**, 默认 uuid4 | |
| `name` | String(30) | unique, index, not null | 角色标识 |
| `display_name` | String(50) | not null | 展示名 |
| `description` | String(255) | | 描述 |
| `permissions` | JSON | 默认 list | 权限列表 |
| `created_at` | DateTime | not null | |
| `updated_at` | DateTime | not null | |

## 计费体系

### point_accounts — 积分账户

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | String(36) | **PK** | |
| `user_id` | String(36) | unique, index, not null | 用户 ID（一对一） |
| `points` | Integer | not null, 默认 0 | 当前可用积分 |
| `total_earned` | Integer | not null, 默认 0 | 累计获得（充值/赠送） |
| `total_consumed` | Integer | not null, 默认 0 | 累计消耗 |
| `created_at` | DateTime | not null | |
| `updated_at` | DateTime | not null | |

详见 [积分系统](./points-system)。

### point_transactions — 积分流水

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | String(36) | **PK**, 默认 uuid4 | |
| `user_id` | String(36) | index, not null | 用户 ID |
| `type` | String(20) | not null | 类型：`recharge`/`consume`/`refund`/`gift` |
| `amount` | Integer | not null | 变动额：正=增加，负=扣减 |
| `balance_after` | Integer | not null | 本次变动后余额（审计用） |
| `ability` | String(50) | | 消费时关联的 AI 能力（如 `AB001`） |
| `source_type` | String(30) | | 来源表：`recharge_order`/`api_log` |
| `source_id` | String(36) | | 来源记录 ID |
| `remark` | String(255) | | 备注（如「充值套餐: 专业版月卡」） |
| `created_at` | DateTime | not null | |

::: tip 凭流水可追溯
`source_type` + `source_id` 可定位积分变动的来源记录，形成完整证据链。
:::

### recharge_orders — 充值订单

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | String(36) | **PK**, 默认 uuid4 | 订单主键 |
| `order_no` | String(40) | unique, index, not null | 订单号（`RC` + 时间戳 + hex） |
| `user_id` | String(36) | index, not null | 用户 ID |
| `username` | String(50) | not null | 用户名（冗余便于查询） |
| `plan` | String(50) | not null | 套餐名 |
| `amount` | Numeric(12,2) | not null | 金额（元） |
| `points` | Integer | not null | 本单积分 |
| `pay_method` | String(20) | not null | 支付方式：`wechat`/`alipay`/`bank` |
| `status` | String(20) | not null, 默认 pending | 状态：`pending`/`completed`/`refunded` |
| `created_at` | DateTime | not null | |

详见 [充值与支付](./recharge-payment)。

### abilities — AI 能力定价

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | String(36) | **PK**, 默认 uuid4 | |
| `ability_id` | String(20) | unique, index, not null | 能力编号（如 `AB001`） |
| `name` | String(50) | not null | 能力名 |
| `category` | String(20) | not null | 类别：`nlp`/`multimodal`/`voice`/`vision` |
| `point_price` | Integer | 默认 0 | 单次调用积分单价 |
| `status` | String(20) | not null, 默认 up | 上下架：`up`/`down` |
| `call_count` | Integer | 默认 0 | 累计调用次数 |
| `created_at` | DateTime | not null | |

::: info 默认对话能力
对话扣费默认走 `AB001`（5 积分）。若 `abilities` 查不到对应能力或 `status != "up"`，回退到默认值 `(AB001, 5)`，保证对话链路始终可用。
:::

### api_logs — API 调用日志

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | String(36) | **PK**, 默认 uuid4 | |
| `log_id` | String(40) | unique, index, not null | 日志编号（`LOG` + 时间戳 + hex） |
| `user_id` | String(36) | index, not null | 用户 ID |
| `username` | String(50) | not null | 用户名 |
| `api_key` | String(60) | not null | 调用所用 API Key（JWT 鉴权时为 `-`） |
| `ability` | String(50) | not null | 调用的能力 |
| `called_at` | DateTime | not null | 调用时间 |
| `response_ms` | Integer | 默认 0 | 响应耗时（毫秒） |
| `points_cost` | Integer | 默认 0 | 积分消耗 |
| `status` | String(20) | not null, 默认 success | 状态：`success`/`failed` |

## 对话体系

### dialogs — 会话

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `dialog_id` | String(36) | **PK**, 默认 uuid4 | 会话 ID |
| `name` | String(255) | not null | 会话名 |
| `agent_id` | String(36) | not null | 关联的 Agent ID |
| `agent_type` | String(50) | 默认 Agent | Agent 类型：`Agent`/`MCPAgent` |
| `user_id` | String(36) | index, not null | 所属用户 |
| `is_favorite` | Boolean | 默认 False | 是否收藏 |
| `is_important` | Boolean | 默认 False | 是否重要 |
| `create_time` | DateTime | not null | |
| `update_time` | DateTime | not null | |

### histories — 消息历史

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | String(36) | **PK**, 默认 uuid4 | |
| `content` | Text | | 消息内容 |
| `dialog_id` | String(36) | index, not null | → `dialogs.dialog_id` |
| `role` | String(20) | not null | 角色：`assistant`/`system`/`user` |
| `events` | JSON | 默认 list | SSE 事件原始数据（仅 assistant） |
| `create_time` | DateTime | not null | |
| `update_time` | DateTime | not null | |

::: tip events 字段
`events` 存储该 assistant 消息产生过程中的 SSE 事件 JSON（`llm_start`/`response_chunk`/`llm_end` 等），便于回放与审计。PostgreSQL 的 JSONB 让该字段高效可查。
:::

### message_likes — 消息点赞

记录用户对 AI 回复的点赞。主键 `id`（String(36)），含 `user_id`、消息标识字段等。

### message_downs — 消息点踩

记录用户对 AI 回复的点踩。结构与 `message_likes` 对称。

::: info 互动表
`message_likes` / `message_downs` 用于收集用户对 AI 回复的偏好反馈，辅助模型质量评估与微调数据筛选。
:::

## 运营体系

### announcements — 公告

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | String(36) | **PK**, 默认 uuid4 | |
| `announce_id` | String(20) | unique, index, not null | 公告编号（如 `ANN012`） |
| `title` | String(200) | not null | 标题 |
| `type` | String(20) | not null, 默认 system | 类型：`system`/`feature`/`price` |
| `content` | Text | | 正文 |
| `status` | String(20) | not null, 默认 published | 状态：`published`/`offline` |
| `pinned` | Boolean | 默认 False | 是否置顶 |
| `published_at` | DateTime | not null | 发布时间 |

### tickets — 工单

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | String(36) | **PK**, 默认 uuid4 | |
| `ticket_no` | String(40) | unique, index, not null | 工单号（`TK` + 时间戳 + hex） |
| `user_id` | String(36) | index, not null | 提交用户 |
| `username` | String(50) | not null | 用户名 |
| `title` | String(200) | not null | 标题 |
| `content` | Text | | 内容 |
| `status` | String(20) | not null, 默认 pending | 状态：`pending`/`processing`/`resolved`/`closed` |
| `priority` | String(20) | not null, 默认 medium | 优先级：`high`/`medium`/`low` |
| `created_at` | DateTime | not null | |
| `updated_at` | DateTime | not null | |

### feedbacks — 用户反馈

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | String(36) | **PK**, 默认 uuid4 | |
| `user_id` | String(36) | index | 提交用户（可匿名） |
| `content` | Text | not null | 反馈内容 |
| `contact` | String(100) | | 联系方式 |
| `status` | String(20) | not null, 默认 pending | 状态：`pending`/`handled` |
| `created_at` | DateTime | not null | |

### operation_logs — 操作日志

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | String(36) | **PK**, 默认 uuid4 | |
| `user_id` | String(36) | index, not null | 操作人 |
| `action` | String(100) | not null | 动作描述（如「登录成功」） |
| `type` | String(20) | not null, 默认 info | 类型：`success`/`info`/`warning`/`error` |
| `ip` | String(64) | 默认 "" | IP |
| `browser` | String(50) | 默认 "" | 浏览器 |
| `os` | String(50) | 默认 "" | 操作系统 |
| `device` | String(50) | 默认 "" | 设备 |
| `created_at` | DateTime | not null, index | |

## 开发体系

### api_keys — API Key

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | String(36) | **PK**, 默认 uuid4 | |
| `user_id` | String(36) | index, not null | 所属用户 |
| `name` | String(100) | not null, 默认「默认密钥」 | 密钥名 |
| `api_key` | String(64) | unique, index, not null | 密钥值（`vb-` 前缀） |
| `status` | String(20) | not null, 默认 active | 状态：`active`/`disabled` |
| `created_at` | DateTime | not null | |
| `last_used_at` | DateTime | | 最后使用时间 |

::: tip vb- 前缀
API Key 以 `vb-` 开头（VibeBase 缩写），便于在日志、配置中一眼识别，也方便前端正则校验格式。
:::

### sub_accounts — 子账号

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | String(36) | **PK**, 默认 uuid4 | |
| `owner_id` | String(36) | index, not null | 主账号 `user_id` |
| `username` | String(50) | not null | 子账号用户名 |
| `nickname` | String(50) | 默认 "" | 昵称 |
| `password` | String(255) | | 密码（可选，预留独立登录） |
| `consume_limit` | Numeric(12,2) | 默认 0.00 | 消费上限 |
| `status` | String(20) | not null, 默认 normal | 状态：`normal`/`disabled` |
| `created_at` | DateTime | not null | |

### tasks — 任务（VibeAdmin 内部）

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | String(20) | **PK** | 任务编号（`TASK-XXXX`） |
| `title` | String(255) | not null | 标题 |
| `description` | String(1000) | | 描述 |
| `status` | Enum(TaskStatus) | not null, 默认 TODO | 状态（枚举） |
| `priority` | Enum(TaskPriority) | not null, 默认 MEDIUM | 优先级（枚举） |
| `label` | Enum(TaskLabel) | not null, 默认 FEATURE | 标签（枚举） |
| `assigned_to` | String(36) | FK → `admin_users.id` | 指派给 |
| `created_by` | String(36) | FK → `admin_users.id`, not null | 创建人 |
| `created_at` | DateTime | not null | |
| `updated_at` | DateTime | not null | |
| `completed_at` | DateTime | | 完成时间 |

### system_config — 系统配置

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | Integer | **PK**, 默认 1 | 单行配置表 |
| `platform_name` | String(100) | 默认 VibeAdmin | 平台名 |
| `support_email` | String(100) | 默认 support@vibeadmin.com | 客服邮箱 |
| `icp_no` | String(50) | 默认 "" | ICP 备案号 |
| `rate_limit_per_min` | Integer | 默认 60 | 每分钟限流 |
| `max_concurrency` | Integer | 默认 50 | 最大并发 |
| `two_factor_enabled` | Boolean | 默认 True | 是否开启二次验证 |
| `ip_whitelist_enabled` | Boolean | 默认 False | 是否开启 IP 白名单 |
| `wechat_mch_id` | String(50) | 默认 "" | 微信商户号 |
| `wechat_key` | String(100) | 默认 "" | 微信密钥 |
| `alipay_mch_id` | String(50) | 默认 "" | 支付宝商户号 |
| `bank_account` | String(100) | 默认 "" | 银行账户 |

::: info 单行配置表
`system_config` 固定 `id=1` 单行，VibeAdmin 后台「系统设置」页直接读写这一行，无需额外配置文件。
:::

## 表关系总览

```text
users ──┬──< user_roles >── roles
        ├──< point_accounts (1:1)
        ├──< point_transactions
        ├──< recharge_orders
        ├──< api_logs
        ├──< dialogs ──< histories
        ├──< api_keys
        ├──< sub_accounts (owner_id)
        ├──< tickets
        ├──< feedbacks
        └──< operation_logs

admin_users ──< tasks (assigned_to / created_by)
admin_roles ── permissions(JSON)

message_likes / message_downs → histories（互动）
```

## 自动建表

应用启动时，`database/init_data.py` 的 `init_database()` 执行 `Base.metadata.create_all()` 自动建表，并写入种子数据（默认角色、管理员、`AB001` 能力等）。详见 [配置 · 数据库配置](../configuration/database)。

::: warning 建表不等于迁移
`create_all()` 只会**新增**不存在的表，不会修改已有表结构。表结构变更需手动执行 DDL 或接入 Alembic 迁移工具。
:::

## 接下来

- [项目结构](./structure) — DAO 与 Model 的目录关系
- [积分系统](./points-system) — `point_accounts` / `point_transactions` 的业务用法
- [充值与支付](./recharge-payment) — `recharge_orders` 的状态流转
- [聊天与流式](./chat-streaming) — `histories.events` 如何产生
- [配置 · 数据库配置](../configuration/database) — 连接与建表
