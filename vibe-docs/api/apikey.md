# API Key API

用户 API Key 的创建、列表、启用、禁用与删除。每个 Key 以 `vb-` 前缀生成，可独立启用 / 禁用。

::: warning 当前未作为鉴权机制
API Key 已完整实现 CRUD 与存储（`api_keys` 表），但**当前对话等接口使用 JWT 鉴权，API Key 尚未作为鉴权方式接入**。该模块主要用于展示与预留后续程序化调用入口。
:::

## 接口总览

| 方法 | 路径 | 认证 | 说明 |
| --- | --- | --- | --- |
| GET | `/api-keys` | Bearer | 列出当前用户的 Key |
| POST | `/api-keys` | Bearer | 创建 Key |
| DELETE | `/api-keys/{key_id}` | Bearer | 删除 Key |
| POST | `/api-keys/{key_id}/disable` | Bearer | 禁用 Key |
| POST | `/api-keys/{key_id}/enable` | Bearer | 启用 Key |

## Key 格式

生成的 Key 格式为：

```
vb-<token_urlsafe(32)>
```

例如：`vb-AbCdEf...随机 43 字符`。`token_urlsafe(32)` 产生约 43 个 URL 安全字符。

## Key 状态

| 状态 | 说明 |
| --- | --- |
| `active` | 启用 |
| `disabled` | 禁用 |

## 列出 Key

```
GET /api/v1/api-keys
```

**认证：** Bearer

**响应示例：**

```json
{
  "status_code": 200,
  "data": [
    {
      "id": "key-uuid-1",
      "name": "默认密钥",
      "key": "vb-AbCdEf...",
      "full_key": "vb-AbCdEf...",
      "status": "active",
      "created_at": "2026-01-01T00:00:00",
      "last_used": null
    }
  ]
}
```

::: tip 完整 Key 始终可见
当前实现中 `key` 与 `full_key` 字段都返回完整 Key 值（未做掩码）。列表接口与创建接口一致。
:::

## 创建 Key

```
POST /api/v1/api-keys
```

**认证：** Bearer

**请求体：**

```json
{
  "name": "默认密钥"
}
```

| 字段 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `name` | string | `默认密钥` | Key 名称 |

**响应示例：**

```json
{
  "status_code": 200,
  "data": {
    "id": "key-uuid-2",
    "name": "生产环境",
    "key": "vb-xYzWqR...",
    "full_key": "vb-xYzWqR...",
    "status": "active",
    "created_at": "2026-07-15T12:00:00",
    "last_used": null
  }
}
```

::: warning 安全提示
Key 仅在创建时由后端随机生成。虽然当前列表接口也返回完整值，但出于安全习惯，**调用方应在创建后立即保存 Key**，避免频繁明文拉取。
:::

## 删除 Key

```
DELETE /api/v1/api-keys/{key_id}
```

**认证：** Bearer

**路径参数：**

| 参数 | 说明 |
| --- | --- |
| `key_id` | Key ID |

**说明：** 物理删除。仅删除属于当前用户的 Key，否则返回 404。

**响应：**

```json
{
  "status_code": 200,
  "data": null
}
```

**错误：**

| status_code | 说明 |
| --- | --- |
| 404 | 密钥不存在（或不属于当前用户） |

## 禁用 Key

```
POST /api/v1/api-keys/{key_id}/disable
```

**认证：** Bearer

**说明：** 将 Key 状态置为 `disabled`。返回更新后的 Key 对象。

**响应示例：**

```json
{
  "status_code": 200,
  "data": {
    "id": "key-uuid-1",
    "name": "默认密钥",
    "key": "vb-AbCdEf...",
    "full_key": "vb-AbCdEf...",
    "status": "disabled",
    "created_at": "2026-01-01T00:00:00",
    "last_used": null
  }
}
```

**错误：** 404 密钥不存在。

## 启用 Key

```
POST /api/v1/api-keys/{key_id}/enable
```

**认证：** Bearer

**说明：** 将 Key 状态置为 `active`。返回更新后的 Key 对象。响应结构与「禁用 Key」一致，`status` 为 `active`。

**错误：** 404 密钥不存在。

## curl 示例

```bash
# 列出 Key
curl http://localhost:8081/api/v1/api-keys \
  -H "Authorization: Bearer eyJ..."

# 创建 Key
curl -X POST http://localhost:8081/api/v1/api-keys \
  -H "Authorization: Bearer eyJ..." \
  -H "Content-Type: application/json" \
  -d '{"name": "生产环境"}'

# 禁用 Key
curl -X POST http://localhost:8081/api/v1/api-keys/key-uuid-1/disable \
  -H "Authorization: Bearer eyJ..."

# 删除 Key
curl -X DELETE http://localhost:8081/api/v1/api-keys/key-uuid-1 \
  -H "Authorization: Bearer eyJ..."
```

## 相关文档

- [用户与认证 API](./user) — JWT 登录鉴权（当前实际使用的鉴权方式）
- [API 概览](./overview) — 认证机制
- [错误码](./error-codes)
