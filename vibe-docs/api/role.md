# 角色权限 API

角色（Role）的增删改查。角色用于用户分组与权限管理，每个角色附带成员数量与图标配色。

## 接口总览

| 方法 | 路径 | 认证 | 说明 |
| --- | --- | --- | --- |
| GET | `/roles` | Bearer | 列出所有角色（含成员数） |
| POST | `/roles` | Bearer | 创建角色 |
| PUT | `/roles/{role_id}` | Bearer | 更新角色 |
| DELETE | `/roles/{role_id}` | Bearer | 删除角色 |

## 角色常量

种子数据中预置以下系统角色（`group_id` 标识分组）：

| 角色名 | group_id | 说明 |
| --- | --- | --- |
| `system` | 0 | 系统角色（SystemRole=0） |
| `admin` | 1 | 管理员角色（AdminRole=1） |
| `default` | 2 | 普通用户（DefaultRole=2） |
| `vip` | 2 | VIP 用户 |
| `beta` | 2 | 内测用户 |

::: info 权限序列化
当前实现中，`permissions` 字段固定序列化为空对象 `{}`（权限模型预留，未实际填充）。
:::

## 图标配色

`icon_color` 在列表接口中按角色顺序循环取自色板：

```python
["blue", "indigo", "emerald", "amber", "rose"]
```

即第 1 个角色为 `blue`，第 2 个为 `indigo`，依此类推，超过 5 个则循环。

## 列出角色

```
GET /api/v1/roles
```

**认证：** Bearer

**说明：** 返回所有角色，并聚合每个角色的成员数（`user_roles` 表中该 `role_id` 的用户数）。`icon_color` 按角色在列表中的索引循环取色。

**响应示例：**

```json
{
  "status_code": 200,
  "data": [
    {
      "id": "1",
      "name": "system",
      "description": "系统角色",
      "member_count": 0,
      "permissions": {},
      "icon_color": "blue"
    },
    {
      "id": "2",
      "name": "admin",
      "description": "管理员角色",
      "member_count": 1,
      "permissions": {},
      "icon_color": "indigo"
    }
  ]
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | string | 角色 ID（字符串化的主键） |
| `name` | string | 角色名 |
| `description` | string | 描述（取自 `remark`） |
| `member_count` | int | 成员数 |
| `permissions` | object | 权限（当前固定为 `{}`） |
| `icon_color` | string | 图标配色 |

## 创建角色

```
POST /api/v1/roles
```

**认证：** Bearer

**请求体：**

```json
{
  "name": "editor",
  "description": "内容编辑",
  "member_count": 0,
  "permissions": {},
  "icon_color": "blue"
}
```

| 字段 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `name` | string | — | 角色名（必填，唯一） |
| `description` | string | `""` | 描述 |
| `member_count` | int | 0 | 成员数（仅入参，实际以聚合为准） |
| `permissions` | object | `{}` | 权限（预留） |
| `icon_color` | string | `blue` | 图标配色 |

**响应示例：**

```json
{
  "status_code": 200,
  "data": {
    "id": "6",
    "name": "editor",
    "description": "内容编辑",
    "member_count": 0,
    "permissions": {},
    "icon_color": "blue"
  }
}
```

::: tip 创建返回的配色
创建接口返回的 `icon_color` 固定取色板第 0 项（`blue`），因为新角色此时不在列表索引中。列表接口会按实际索引重新取色。
:::

**错误：**

| status_code | 说明 |
| --- | --- |
| 400 | 角色名已存在 |

## 更新角色

```
PUT /api/v1/roles/{role_id}
```

**认证：** Bearer

**路径参数：**

| 参数 | 说明 |
| --- | --- |
| `role_id` | 角色 ID（整数主键） |

**请求体：** 所有字段可选。

```json
{
  "name": "editor_v2",
  "description": "高级内容编辑"
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `name` | string | 新角色名 |
| `description` | string | 新描述 |
| `member_count` | int | 成员数（预留） |
| `permissions` | object | 权限（预留） |
| `icon_color` | string | 配色（预留） |

::: warning 仅 name/description 实际生效
后端 `RoleUpdate` 虽然接收全部字段，但**只有 `name` 与 `description` 会被写入数据库**（`member_count` / `permissions` / `icon_color` 为序列化侧的派生字段）。
:::

**错误：** 404 角色不存在。

## 删除角色

```
DELETE /api/v1/roles/{role_id}
```

**认证：** Bearer

**说明：** 物理删除角色。

**响应：**

```json
{
  "status_code": 200,
  "data": null
}
```

**错误：** 404 角色不存在。

## curl 示例

```bash
# 列出角色
curl http://localhost:8081/api/v1/roles \
  -H "Authorization: Bearer eyJ..."

# 创建角色
curl -X POST http://localhost:8081/api/v1/roles \
  -H "Authorization: Bearer eyJ..." \
  -H "Content-Type: application/json" \
  -d '{"name": "editor", "description": "内容编辑"}'

# 更新角色
curl -X PUT http://localhost:8081/api/v1/roles/6 \
  -H "Authorization: Bearer eyJ..." \
  -H "Content-Type: application/json" \
  -d '{"description": "高级内容编辑"}'

# 删除角色
curl -X DELETE http://localhost:8081/api/v1/roles/6 \
  -H "Authorization: Bearer eyJ..."
```

## 相关文档

- [子账号 API](./accounts) — 主账号下的成员管理
- [用户与认证 API](./user) — 用户与角色绑定
- [API 概览](./overview)
- [错误码](./error-codes)
