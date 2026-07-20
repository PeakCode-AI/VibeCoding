# 子账号 API

主账号下的子账号（成员 / 配额单元）管理。子账号本身不独立登录，仅作为主账号下的成员与配额管理单元。

## 接口总览

| 方法 | 路径 | 认证 | 说明 |
| --- | --- | --- | --- |
| GET | `/accounts` | Bearer | 列出主账号下的子账号 |
| POST | `/accounts` | Bearer | 创建子账号 |
| PUT | `/accounts/{account_id}` | Bearer | 更新子账号 |
| DELETE | `/accounts/{account_id}` | Bearer | 删除子账号 |
| POST | `/accounts/{account_id}/toggle-status` | Bearer | 切换启用状态 |

::: warning 子账号不独立登录
子账号（`sub_accounts` 表）归属某个 C 端主账号（`owner_id` 指向 `users.user_id`），**不独立登录**，仅作为主账号下的成员 / 配额管理单元。`password` 字段为可选预留，当前不用于登录。
:::

## 状态

| 状态 | 含义 |
| --- | --- |
| `normal` | 正常 |
| `disabled` | 禁用 |

`toggle-status` 接口在 `normal` ↔ `disabled` 之间切换。

## 列出子账号

```
GET /api/v1/accounts
```

**认证：** Bearer

**说明：** 返回当前用户（主账号）拥有的所有子账号。

**响应示例：**

```json
{
  "status_code": 200,
  "data": [
    {
      "id": "sub-uuid-1",
      "username": "alice_sub1",
      "nickname": "Alice 助手",
      "consume_limit": 100.0,
      "status": "normal"
    }
  ]
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `username` | string | 子账号用户名 |
| `nickname` | string | 昵称 |
| `consume_limit` | float | 消费限额 |
| `status` | string | `normal` / `disabled` |

## 创建子账号

```
POST /api/v1/accounts
```

**认证：** Bearer

**请求体：**

```json
{
  "username": "alice_sub3",
  "nickname": "数据采集",
  "consume_limit": 50.0,
  "password": "optional"
}
```

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `username` | string | ✅ | 用户名（非空且 ≤ 50 字符） |
| `nickname` | string | ❌ | 昵称，默认空字符串 |
| `consume_limit` | float | ❌ | 消费限额，默认 0 |
| `password` | string | ❌ | 密码（预留，当前不用于登录） |

**响应示例：**

```json
{
  "status_code": 200,
  "data": {
    "id": "sub-uuid-3",
    "username": "alice_sub3",
    "nickname": "数据采集",
    "consume_limit": 50.0,
    "status": "normal"
  }
}
```

::: tip 新建子账号状态
新建子账号的 `status` 固定为 `normal`。
:::

**错误：**

| status_code | 说明 |
| --- | --- |
| 400 | 用户名不合法（为空或超过 50 字符） |

## 更新子账号

```
PUT /api/v1/accounts/{account_id}
```

**认证：** Bearer

**路径参数：**

| 参数 | 说明 |
| --- | --- |
| `account_id` | 子账号 ID |

**请求体：** 所有字段可选。

```json
{
  "nickname": "新昵称",
  "consume_limit": 200.0,
  "status": "disabled"
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `nickname` | string | 新昵称 |
| `consume_limit` | float | 新消费限额 |
| `status` | string | 新状态（`normal` / `disabled`） |

**错误：** 404 子账号不存在（或不属于当前主账号）。

## 删除子账号

```
DELETE /api/v1/accounts/{account_id}
```

**认证：** Bearer

**说明：** 物理删除子账号。仅删除属于当前主账号的子账号。

**响应：**

```json
{
  "status_code": 200,
  "data": null
}
```

**错误：** 404 子账号不存在。

## 切换启用状态

```
POST /api/v1/accounts/{account_id}/toggle-status
```

**认证：** Bearer

**说明：** 在 `normal` ↔ `disabled` 之间切换。当前为 `normal` 则改为 `disabled`，反之改为 `normal`。

**响应示例：**

```json
{
  "status_code": 200,
  "data": {
    "id": "sub-uuid-1",
    "username": "alice_sub1",
    "nickname": "Alice 助手",
    "consume_limit": 100.0,
    "status": "disabled"
  }
}
```

**错误：** 404 子账号不存在。

## curl 示例

```bash
# 列出子账号
curl http://localhost:8081/api/v1/accounts \
  -H "Authorization: Bearer eyJ..."

# 创建子账号
curl -X POST http://localhost:8081/api/v1/accounts \
  -H "Authorization: Bearer eyJ..." \
  -H "Content-Type: application/json" \
  -d '{"username": "alice_sub3", "nickname": "数据采集", "consume_limit": 50.0}'

# 切换状态
curl -X POST http://localhost:8081/api/v1/accounts/sub-uuid-1/toggle-status \
  -H "Authorization: Bearer eyJ..."

# 删除子账号
curl -X DELETE http://localhost:8081/api/v1/accounts/sub-uuid-1 \
  -H "Authorization: Bearer eyJ..."
```

## 相关文档

- [角色权限 API](./role) — 角色管理
- [用户与认证 API](./user) — 主账号
- [API 概览](./overview)
- [错误码](./error-codes)
