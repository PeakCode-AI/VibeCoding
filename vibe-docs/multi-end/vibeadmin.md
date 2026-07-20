# VibeAdmin 运营后台

VibeAdmin 是 Vibe 体系的**运营后台**，面向运营人员和管理员，提供用户管理、订单管理、工单处理、收入统计等运营能力。它与 VibeBase 共享同一套数据库。

## 定位

```
最终用户 ──▶ VibeBase（用户 Web / App / 小程序）
                    │ 共享数据库
运营人员 ──▶ VibeAdmin（运营后台）
```

VibeAdmin 不直接服务最终用户，而是让运营方**管理** VibeBase 产生的数据：

| VibeBase（用户侧） | VibeAdmin（运营侧） |
| --- | --- |
| 用户注册 | 用户列表 / 封禁 / 角色分配 |
| 用户充值 | 订单管理 / 收入统计 |
| 用户对话 | 用量监控 / 成本分析 |
| 用户提工单 | 工单处理 / 状态流转 |
| 用户反馈 | 反馈查看 / 回复 |
| AI 能力调用 | 能力定价 / 上下架 |
| 接收公告 | 发布公告 |
| — | 后台管理员账号管理 |
| — | 系统配置 |

## 技术栈

VibeAdmin 与 VibeBase 技术栈高度一致：

```text
前端      Vue 3 + TypeScript + Vite
UI        @antfu/eslint-config（2 空格缩进）
后端      FastAPI + Python 3.12
端口      前端 5173 / 后端 8080
```

::: tip 差异点
VibeAdmin 前端用 `@antfu/eslint-config`（2 空格缩进），VibeBase 前端用 Prettier。两者 UI 组件库风格统一。
:::

## 数据库共享

VibeAdmin 与 VibeBase 连接**同一个 PostgreSQL 实例**，使用同一套 ORM 模型（`vibe_common/models/`）：

- VibeBase 的用户 = VibeAdmin 可运营的用户
- VibeBase 的订单 = VibeAdmin 收入统计的来源
- VibeBase 的工单 = VibeAdmin 工单处理模块的数据

::: tip 跨服务 Token 互通
只要 VibeAdmin 与 VibeBase 配置**相同的** `SECRET_KEY`，签发的 JWT 可跨服务互认。这意味着管理员可凭一个 Token 访问两个后端。
:::

## VibeAdmin 专属表

除了与 VibeBase 共享的表，VibeAdmin 还有专属表：

| 表 | 说明 |
| --- | --- |
| `admin_users` | 后台管理员账号（独立于 C 端 `users`） |
| `tasks` | 任务管理 |
| `system_config` | 系统配置 |

::: info admin_users 密码格式
`admin_users.password_hash` 用 **bcrypt**（`$2` 前缀）。VibeBase 的 `verify_password` 能兼容此格式，所以 VibeAdmin 的种子管理员账号也能在 VibeBase 侧验证。
:::

## 启动

```bash
# VibeAdmin 后端
cd VibeAdmin/vibe-admin
python run_server.py     # http://localhost:8080

# VibeAdmin 前端
cd VibeAdmin/vibe-admin-web
corepack enable && pnpm install
pnpm dev                 # http://localhost:5173
```

详见 `VibeAdmin/README.md`。

## 与 VibeBase 的协作场景

### 场景一：处理用户工单

1. 用户在 VibeBase 提交工单（`tickets` 表，status=pending）
2. 运营在 VibeAdmin 看到新工单
3. 运营处理并将 status 改为 processing → resolved
4. 用户在 VibeBase「我的工单」看到状态更新

### 场景二：调整 AI 能力定价

1. 运营在 VibeAdmin 修改 `abilities` 表某能力的 `point_price`
2. VibeBase 用户下次调用该能力时按新价格扣费

### 场景三：封禁违规用户

1. 运营在 VibeAdmin 将某用户 status 设为 disabled
2. 该用户在 VibeBase 登录时返回 403
3. 该用户的所有端立即无法访问

### 场景四：发布系统公告

1. 运营在 VibeAdmin 创建公告（`announcements` 表，status=published）
2. VibeBase 用户在「公告中心」实时看到新公告

## 部署

生产环境通常将 VibeAdmin 部署在独立子域（如 `admin.your-domain.com`），与 VibeBase（`your-domain.com`）分离：

```nginx
server {
    server_name your-domain.com;       # VibeBase 用户站
    # ...
}
server {
    server_name admin.your-domain.com; # VibeAdmin 运营后台
    # ...
}
```

::: tip 安全建议
VibeAdmin 后台建议加 IP 白名单访问限制，避免暴露在公网。
:::

## 相关文档

- [多端概览](./overview)
- [产品矩阵](../introduction/product-matrix)
- [JWT 与认证密钥](../configuration/jwt) — 跨服务 Token 互通
- [数据模型](../development/data-models) — 共享表结构
