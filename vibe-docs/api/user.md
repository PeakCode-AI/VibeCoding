# 用户与认证 API

用户注册、登录、Token 管理、个人信息、安全相关接口。涵盖 `/api/v1/user`、`/api/v1/security` 前缀。

## 接口总览

| 方法 | 路径 | 认证 | 说明 |
| --- | --- | --- | --- |
| POST | `/user/register` | 公开 | 注册 |
| POST | `/user/login` | 公开 | 登录 |
| POST | `/user/dev-login` | 公开 | 开发快捷登录 |
| POST | `/user/refresh` | 公开 | 刷新 Token |
| POST | `/user/logout` | Bearer | 登出 |
| GET | `/user/info` | Bearer | 当前用户信息 |
| PUT | `/user/update` | — | 更新用户（按 body 中的 user_id） |
| GET | `/user/icons` | — | 默认头像列表 |
| POST | `/user/set-password` | Bearer | 设置 / 修改密码 |
| GET | `/security/operation-logs` | Bearer | 操作日志 |
| GET | `/security/devices` | Bearer | 登录设备列表 |
| DELETE | `/security/devices/{device_id}` | Bearer | 下线设备 |

## 注册

```
POST /api/v1/user/register
```

**认证：** 公开（白名单）

**请求体：**

```json
{
  "user_name": "demo_user",
  "user_email": "demo@example.com",
  "user_password": "123456"
}
```

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `user_name` | string | ✅ | 用户名，≤20 字符，唯一 |
| `user_email` | string | ❌ | 邮箱 |
| `user_password` | string | ✅ | 密码 |

**响应：** 注册成功会**自动登录**，返回双 Token：

```json
{
  "status_code": 200,
  "data": {
    "user_id": "abc-123",
    "access_token": "eyJ...",
    "refresh_token": "eyJ..."
  }
}
```

::: tip 首个用户即管理员
第一个注册的用户 user_id 为 `1`（AdminUser），拥有管理员权限。
:::

**错误：**

| status_code | 说明 |
| --- | --- |
| 409 | 用户名已存在 |
| 400 | 用户名超过 20 字符 |

## 登录

```
POST /api/v1/user/login
```

**认证：** 公开（白名单）

**请求体：**

```json
{
  "user_name": "demo_user",
  "user_password": "123456"
}
```

**响应：**

```json
{
  "status_code": 200,
  "data": {
    "user_id": "abc-123",
    "access_token": "eyJ...",
    "refresh_token": "eyJ..."
  }
}
```

登录成功会记录一条「登录成功」操作日志（含 IP、浏览器、操作系统）。

**错误：**

| status_code | 说明 |
| --- | --- |
| 401 | 用户名或密码错误（不区分用户名是否存在，防枚举） |
| 403 | 账号已被禁用（`delete=True`） |

::: warning 安全设计
登录失败统一返回「用户名或密码错误」，避免攻击者通过不同错误信息枚举有效用户名。
:::

## 开发快捷登录

```
POST /api/v1/user/dev-login
```

**认证：** 公开（白名单）

**说明：** 开发环境专用，直接签发 `dev_001` / `dev_user` 的管理员 Token。当 `ENVIRONMENT=production` 时返回 403。

```bash
# 快速获取开发 Token
curl -X POST http://localhost:8081/api/v1/user/dev-login
```

::: danger 生产环境禁用
此接口在 `ENVIRONMENT=production` 时返回 403。部署生产前务必确认 `ENVIRONMENT` 已正确设置。
:::

## 刷新 Token

```
POST /api/v1/user/refresh
```

**认证：** 公开（用 refresh_token 换取）

**请求体：**

```json
{
  "refresh_token": "eyJ..."
}
```

**响应：** 返回**全新**的双 Token（旧的 refresh token 会被撤销）：

```json
{
  "status_code": 200,
  "data": {
    "access_token": "eyJ...（新）",
    "refresh_token": "eyJ...（新）"
  }
}
```

::: info Token 轮转
每次刷新都会撤销旧的 refresh token，避免 refresh token 被重复使用。这是双 Token 机制的安全核心。
:::

**错误：** 403 账号被禁用 / refresh token 无效或已撤销。

## 登出

```
POST /api/v1/user/logout
```

**认证：** Bearer

**请求体：**

```json
{
  "refresh_token": "eyJ...（可选）"
}
```

**响应：** `200`。会将 access token 与 refresh token（若提供）加入 Redis 黑名单。

## 获取用户信息

```
GET /api/v1/user/info
```

**认证：** Bearer

**响应：**

```json
{
  "status_code": 200,
  "data": {
    "user_id": "abc-123",
    "user_name": "demo_user",
    "user_email": "demo@example.com",
    "user_phone": null,
    "user_avatar": "https://...",
    "user_description": "",
    "status": "active",
    "balance": 0.00,
    "create_time": "2026-01-01T00:00:00",
    "update_time": "2026-01-01T00:00:00"
  }
}
```

::: tip 安全序列化
`user_password` 与 `delete` 字段会被显式排除，永远不会出现在响应中。
:::

## 更新用户

```
PUT /api/v1/user/update
```

**请求体：**

```json
{
  "user_id": "abc-123",
  "user_avatar": "https://...",
  "user_description": "个人简介"
}
```

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `user_id` | string | ✅ | 要更新的用户 ID |
| `user_avatar` | string | ❌ | 头像 URL |
| `user_description` | string | ❌ | 个人简介 |

::: warning 注意
此接口直接以请求体中的 `user_id` 为准，调用方需自行确保传入正确的 user_id。
:::

## 默认头像列表

```
GET /api/v1/user/icons
```

**响应：** 返回 5 个 DiceBear 默认头像 URL：

```json
{
  "status_code": 200,
  "data": [
    "https://api.dicebear.com/...",
    "..."
  ]
}
```

## 设置 / 修改密码

```
POST /api/v1/user/set-password
```

**认证：** Bearer

**请求体：**

```json
{
  "old_password": "旧密码（首次设置可省略）",
  "user_password": "新密码",
  "confirm_password": "确认新密码"
}
```

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `old_password` | string | ❌ | 旧密码（已设置过密码时必填） |
| `user_password` | string | ✅ | 新密码，最短 6 位 |
| `confirm_password` | string | ✅ | 确认密码，需与上一致 |

::: tip 双格式密码兼容
后端 `verify_password` 同时兼容：
- bcrypt 哈希（以 `$2` 开头）—— VibeAdmin 种子数据
- SHA-256 哈希 —— VibeBase 注册 / 改密
:::

操作成功会记录「修改密码」操作日志。

**错误：**

| status_code | 说明 |
| --- | --- |
| 400 | 两次密码不一致 / 密码短于 6 位 |
| 401 | 旧密码错误 |

## 操作日志

```
GET /api/v1/security/operation-logs?limit=50
```

**认证：** Bearer

**查询参数：**

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `limit` | 50 | 返回条数上限 |

**响应：**

```json
{
  "status_code": 200,
  "data": [
    {
      "id": 1,
      "action": "登录成功",
      "ip": "192.168.1.1",
      "time": "2026-01-01T00:00:00",
      "type": "success",
      "browser": "Chrome"
    }
  ]
}
```

## 登录设备列表

```
GET /api/v1/security/devices
```

**认证：** Bearer

**响应：** 从「登录成功」日志聚合，按 `(ip, browser, os)` 去重，最近一次标记为 `is_current`：

```json
{
  "status_code": 200,
  "data": [
    {
      "device_id": "1",
      "ip": "192.168.1.1",
      "browser": "Chrome",
      "os": "macOS",
      "last_active": "2026-01-01T00:00:00",
      "is_current": true
    }
  ]
}
```

## 下线设备

```
DELETE /api/v1/security/devices/{device_id}
```

**认证：** Bearer

移除该设备的最近一条登录日志。404 表示未找到。

## 客户端识别

后端 `parse_client(request)` 从 User-Agent 解析：

| 维度 | 识别项 |
| --- | --- |
| IP | `X-Forwarded-For` 首段 |
| 浏览器 | Chrome / Edge / Firefox / Safari |
| 操作系统 | Windows / iOS / macOS / Android / Linux |

这些信息用于操作日志与设备聚合。

## 相关文档

- [个人资料 API](./profile) — 头像上传、资料编辑
- [开发指南 · 认证机制](../development/authentication) — JWT 原理
- [API 概览](./overview) — 通用约定
