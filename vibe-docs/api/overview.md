# API 概览

VibeBase 后端基于 FastAPI 构建，所有接口前缀为 `/api/v1`，另有两个顶层端点 `/health` 和 `/test`。本页是 API 的通用约定，具体接口见左侧目录各模块页。

## 基础信息

| 项 | 值 |
| --- | --- |
| Base URL | `http://localhost:8081`（开发） |
| API 前缀 | `/api/v1` |
| 协议 | HTTP/1.1 |
| 数据格式 | JSON（对话接口除外，用 SSE） |
| API 文档 | http://localhost:8081/docs （Swagger UI） |
| 健康检查 | `GET /health` → `{"status":"OK"}` |

## 统一响应格式

所有非流式接口都返回 `UnifiedResponseModel`：

```json
{
  "status_code": 200,
  "status_message": "SUCCESS",
  "data": { ... },
  "detail": "SUCCESS"
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `status_code` | int | 业务状态码（HTTP 语义） |
| `status_message` | string | 状态描述 |
| `data` | any \| null | 业务数据 |
| `detail` | string | 兼容旧前端读取的字段（与 status_message 通常一致） |

::: tip 前端读取约定
前端优先读 `status_code` 判断成功，错误提示文案读 `status_message` 或 `detail`。
:::

### 成功示例

```json
{
  "status_code": 200,
  "status_message": "SUCCESS",
  "data": {
    "user_id": "abc-123",
    "user_name": "demo_user"
  }
}
```

### 错误示例

```json
{
  "status_code": 402,
  "status_message": "积分余额不足",
  "data": null,
  "detail": "积分余额不足"
}
```

## 认证

除白名单与标注为「公开」的接口外，所有接口都需要在请求头携带 JWT：

```bash
Authorization: Bearer <access_token>
```

::: info 认证机制
详见 [开发指南 · 认证机制](../development/authentication)。核心依赖 `get_login_user` 会依次校验：白名单 → Bearer Token → Redis 黑名单 → JWT 解码。
:::

### 获取 Token

```bash
# 登录获取双 Token
curl -X POST http://localhost:8081/api/v1/user/login \
  -H "Content-Type: application/json" \
  -d '{"user_name":"demo","user_password":"123456"}'

# 响应
{
  "status_code": 200,
  "data": {
    "user_id": "abc-123",
    "access_token": "eyJ...",
    "refresh_token": "eyJ..."
  }
}
```

### Token 续签

access token 过期后，用 refresh token 换取新的双 Token：

```bash
curl -X POST http://localhost:8081/api/v1/user/refresh \
  -H "Content-Type: application/json" \
  -d '{"refresh_token":"eyJ..."}'
```

## 限流

后端通过 Redis 固定窗口限流：

| 规则 | 值 |
| --- | --- |
| 维度 | `(client_ip, path)` |
| 上限 | 120 次 / 60 秒 |
| 超限响应 | `429` `{"detail":"请求过于频繁，请稍后重试"}` |

::: warning 限流响应格式特殊
限流响应**不**走 `UnifiedResponseModel`，而是直接的 `{"detail": "..."}`，前端需兼容此格式。
:::

## 错误处理

### 全局异常处理器

后端在 `main.py` 注册了三个全局异常处理器，将所有异常统一为 `UnifiedResponseModel`：

| 异常 | HTTP 状态码 | 说明 |
| --- | --- | --- |
| `RequestValidationError` | 422 | 参数校验失败，message 聚合所有字段错误 |
| `HTTPException` | 原 status | 业务主动抛出的异常 |
| `Exception`（兜底） | 500 | `"服务器内部错误，请稍后重试"`，堆栈不外泄 |

### 常见 HTTP 状态码

| 状态码 | 含义 | 典型场景 |
| --- | --- | --- |
| 200 | 成功 | 正常业务响应 |
| 400 | 请求错误 | 参数非法、业务校验失败 |
| 401 | 未认证 | Token 缺失 / 过期 / 被撤销 |
| 402 | 积分不足 | 对话扣费时余额不够 |
| 403 | 无权限 | 账号被禁用、签名错误 |
| 404 | 资源不存在 | 查询对象不存在 |
| 409 | 冲突 | 用户名已存在 |
| 422 | 参数校验失败 | Pydantic 校验不通过 |
| 429 | 请求过频 | 触发限流 |
| 500 | 服务器错误 | 未捕获异常 |

详见 [错误码](./error-codes)。

## 白名单路径

以下路径无需认证（`config.dev.yaml` 的 `whitelist_paths`）：

| 路径 | 说明 |
| --- | --- |
| `/health` | 健康检查 |
| `/api/v1/user/login` | 登录 |
| `/api/v1/user/register` | 注册 |
| `/api/v1/user/dev-login` | 开发快捷登录（非 production） |
| `/api/v1/recharge/notify` | 支付回调（另有签名校验） |

::: warning 白名单 ≠ 完全公开
白名单仅跳过 JWT 认证，不代表完全无防护。例如 `/recharge/notify` 仍需 HMAC 签名校验。
:::

## 接口分组速览

| 模块 | 路径前缀 | 文档 |
| --- | --- | --- |
| 用户与认证 | `/api/v1/user`, `/api/v1/security` | [用户与认证](./user) |
| 对话 | `/api/v1/chat`, `/api/v1/dialog`, `/api/v1/message`, `/api/v1/history` | [对话](./chat) |
| 积分 | `/api/v1/points` | [积分](./points) |
| 充值 | `/api/v1/recharge` | [充值](./recharge) |
| API Key | `/api/v1/api-keys` | [API Key](./apikey) |
| AI 能力 | `/api/v1/ability` | [AI 能力](./ability) |
| 用量分析 | `/api/v1/analytics` | [用量分析](./analytics) |
| 个人资料 | `/api/v1/user/profile`, `/api/v1/settings` | [个人资料](./profile) |
| 角色权限 | `/api/v1/roles` | [角色权限](./role) |
| 公告 | `/api/v1/announcement` | [公告](./announcement) |
| 反馈 | `/api/v1/feedback` | [反馈](./feedback) |
| 工单 | `/api/v1/tickets` | [工单](./ticket) |
| 子账号 | `/api/v1/accounts` | [子账号](./accounts) |
| 消费记录 | `/api/v1/consume` | [消费记录](./consume) |
| 控制台 | `/api/v1/console` | [控制台](./console) |
| 图像理解 | `/api/v1/image` | [图像理解](./image) |

## 调用示例

### curl

```bash
# 带认证的 GET
curl http://localhost:8081/api/v1/user/info \
  -H "Authorization: Bearer eyJ..."

# POST 带 JSON
curl -X POST http://localhost:8081/api/v1/feedback \
  -H "Authorization: Bearer eyJ..." \
  -H "Content-Type: application/json" \
  -d '{"content":"这个产品很好用"}'
```

### JavaScript (fetch)

```javascript
const res = await fetch('http://localhost:8081/api/v1/user/info', {
  headers: { Authorization: `Bearer ${token}` }
})
const { status_code, data } = await res.json()
if (status_code === 200) {
  console.log(data)
}
```

### Python (requests)

```python
import requests

resp = requests.get(
    'http://localhost:8081/api/v1/user/info',
    headers={'Authorization': f'Bearer {token}'}
)
body = resp.json()
if body['status_code'] == 200:
    print(body['data'])
```

## 接下来

按需查阅各模块 API 文档。建议从 [用户与认证](./user) 和 [对话](./chat) 开始。

## 相关文档

- [错误码](./error-codes)
- [开发指南 · 认证机制](../development/authentication)
- [开发指南 · 聊天与流式](../development/chat-streaming)
