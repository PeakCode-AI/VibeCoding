# 个人资料 API

当前用户的个人资料查询与修改、头像上传。提供 `/user/profile` 与 `/settings/profile` 两组等价路径（前端不同页面共用同一实现）。

## 接口总览

| 方法 | 路径 | 认证 | 说明 |
| --- | --- | --- | --- |
| GET | `/user/profile` | Bearer | 获取个人资料 |
| GET | `/settings/profile` | Bearer | 同上（别名路径） |
| PUT | `/user/profile` | Bearer | 修改个人资料 |
| PUT | `/settings/profile` | Bearer | 同上（别名路径） |
| POST | `/user/avatar` | Bearer | 上传头像（multipart） |
| POST | `/settings/avatar` | Bearer | 同上（别名路径） |

::: tip 双路径别名
`/user/profile` 与 `/settings/profile` 是**同一处理函数**的两个路由（`@router.get` 装饰器叠加）。`/user/avatar` 与 `/settings/avatar` 同理。前端在不同页面（用户中心 / 设置页）调用不同路径，后端实现一致。
:::

## 获取个人资料

```
GET /api/v1/user/profile
GET /api/v1/settings/profile
```

**认证：** Bearer

**响应示例：**

```json
{
  "status_code": 200,
  "data": {
    "user_id": "abc-123",
    "user_name": "demo_user",
    "user_email": "demo@example.com",
    "user_phone": "13800001111",
    "user_avatar": "https://...",
    "user_description": "个人简介",
    "status": "active",
    "balance": 999.0,
    "create_time": "2026-01-01T00:00:00",
    "update_time": "2026-01-01T00:00:00"
  }
}
```

::: warning 安全序列化
响应通过 `to_dict(exclude={"user_password", "delete"})` 输出，**显式排除 `user_password` 与 `delete` 字段**，永远不会出现在响应中。
:::

## 修改个人资料

```
PUT /api/v1/user/profile
PUT /api/v1/settings/profile
```

**认证：** Bearer

**请求体：** 所有字段可选，仅传入的字段会被更新。

```json
{
  "user_name": "new_name",
  "user_avatar": "https://...",
  "user_description": "新的简介",
  "user_email": "new@example.com"
}
```

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `user_name` | string | ❌ | 用户名 |
| `user_avatar` | string | ❌ | 头像 URL |
| `user_description` | string | ❌ | 个人简介 |
| `user_email` | string | ❌ | 邮箱 |

**响应：** 返回更新后的完整资料（同样排除 `user_password` / `delete`），结构同「获取个人资料」。

**错误：**

| status_code | 说明 |
| --- | --- |
| 401 | 登录状态已失效，请重新登录（用户记录不存在） |

## 上传头像

```
POST /api/v1/user/avatar
POST /api/v1/settings/avatar
```

**认证：** Bearer

**请求格式：** `multipart/form-data`

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `file` | file | ✅ | 头像图片文件 |

**校验规则：**

| 规则 | 说明 |
| --- | --- |
| 文件类型 | `Content-Type` 必须以 `image/` 开头，否则 400 |
| 文件大小 | ≤ 5MB，否则 400 |
| 对象存储 | boto3 / S3 未配置时返回 503 |

**响应示例：**

```json
{
  "status_code": 200,
  "data": {
    "url": "http://localhost:9000/vibe-storage/avatars/abc-123.jpg"
  }
}
```

::: details S3 Key 格式
头像上传到 S3 的 Key 为：

```
{S3_AVATAR_PATH}/{user_id}.{ext}
```

- `S3_AVATAR_PATH` 默认为 `avatars`（见 `vibe_common/core/config.py`）。
- `{user_id}` 为当前登录用户 ID。
- `{ext}` 取自上传文件名后缀，无后缀时默认 `jpg`。

完整 Key 示例：`avatars/abc-123.jpg`。访问 URL 为 `{S3_PUBLIC_URL}/{key}`。
:::

::: danger 对象存储未配置时
若 boto3 或 S3 客户端无法导入，返回 `503 对象存储未配置，无法上传头像`。后端用延迟导入（`from vibe_common.storage import s3_client`）避免 boto3 未安装时拖垮整个用户模块（注册 / 登录 / 资料）。
:::

**错误：**

| status_code | 说明 |
| --- | --- |
| 400 | 只能上传图片文件 / 图片大小不能超过 5MB |
| 503 | 对象存储未配置 |

## curl 示例

```bash
# 获取资料
curl http://localhost:8081/api/v1/user/profile \
  -H "Authorization: Bearer eyJ..."

# 修改资料
curl -X PUT http://localhost:8081/api/v1/user/profile \
  -H "Authorization: Bearer eyJ..." \
  -H "Content-Type: application/json" \
  -d '{"user_description": "新的简介", "user_email": "new@example.com"}'

# 上传头像
curl -X POST http://localhost:8081/api/v1/user/avatar \
  -H "Authorization: Bearer eyJ..." \
  -F "file=@/path/to/avatar.png"
```

## 相关文档

- [用户与认证 API](./user) — 登录 / Token / `/user/info`
- [API 概览](./overview)
- [错误码](./error-codes)
