# 错误码

VibeBase 后端的错误处理约定：HTTP 状态码、统一响应错误格式、业务错误码与常见错误场景。

## HTTP 状态码

| 状态码 | 含义 | 典型场景 |
| --- | --- | --- |
| 200 | 成功 | 正常业务响应 |
| 400 | 请求错误 | 参数非法、业务校验失败（如套餐不存在、优先级取值非法、角色名已存在） |
| 401 | 未认证 | Token 缺失 / 过期 / 被撤销、登录状态失效 |
| 402 | 积分不足 | 对话扣费时余额不够 |
| 403 | 无权限 | 账号被禁用、签名校验失败、生产环境调用 dev-login |
| 404 | 资源不存在 | 查询对象不存在（公告 / 工单 / 密钥 / 角色 / 子账号等） |
| 409 | 冲突 | 用户名已存在 |
| 422 | 参数校验失败 | Pydantic 校验不通过（请求体结构错误） |
| 429 | 请求过频 | 触发限流 |
| 500 | 服务器错误 | 未捕获异常（兜底为「服务器内部错误，请稍后重试」） |

## 统一错误响应格式

非限流场景下，所有错误都通过全局异常处理器统一为 `UnifiedResponseModel`：

```json
{
  "status_code": 402,
  "status_message": "积分余额不足，请充值后再试",
  "data": null,
  "detail": "积分余额不足，请充值后再试"
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `status_code` | int | 业务状态码（HTTP 语义） |
| `status_message` | string | 状态描述（错误文案） |
| `data` | any \| null | 业务数据（错误时通常为 `null`） |
| `detail` | string | 兼容旧前端字段（通常与 `status_message` 一致） |

::: tip 前端读取约定
前端优先读 `status_code` 判断成功（`200` 为成功），错误提示文案读 `status_message` 或 `detail`。
:::

## 全局异常处理器

后端在 `main.py` 注册了三个全局异常处理器：

| 异常 | HTTP 状态码 | 说明 |
| --- | --- | --- |
| `RequestValidationError` | 422 | 参数校验失败，message 聚合所有字段错误 |
| `HTTPException` | 原 status | 业务主动抛出的异常（最常见） |
| `Exception`（兜底） | 500 | `"服务器内部错误，请稍后重试"`，堆栈不外泄 |

::: warning 实际约定
代码库中存在 `BaseErrorCode` 及其子类（见下文），但**绝大多数端点实际使用的是原始 `HTTPException(status_code=..., detail=...)`**，由全局异常处理器统一转换为 `UnifiedResponseModel`。也就是说，**事实上的错误契约是「全局异常处理器」而非 `BaseErrorCode` 类**。
:::

## 业务错误码（用户模块）

用户模块定义了一组 `106xx` 业务错误码（位于 `api/errcode/user.py`）：

| 错误码 | 类名 | 文案 |
| --- | --- | --- |
| 10600 | `UserValidateError` | 账号或密码错误 |
| 10601 | `UserPasswordExpireError` | 您的密码已过期，请及时修改 |
| 10602 | `UserNotPasswordError` | 用户尚未设置密码，请先联系管理员重置密码 |
| 10603 | `UserPasswordError` | 当前密码错误 |
| 10604 | `UserLoginOfflineError` | 您的账户已在另一设备上登录，此设备上的会话已被注销。如果这不是您本人的操作，请尽快修改您的账户密码。 |
| 10605 | `UserNameAlreadyExistError` | 用户名已存在 |
| 10606 | `UserNeedGroupAndRoleError` | 用户组和角色不能为空 |
| 10610 | `UserGroupNotDeleteError` | 用户组内还有用户，不能删除 |

## 错误码命名约定

::: details 错误码分段规则
`BaseErrorCode` 注释明确：**错误码前三位代表具体功能模块，后两位表示模块内部具体的报错**。

```
10605
└┬┘└┬┘
 │  └─ 05：模块内具体错误（用户名已存在）
 └─── 106：用户模块
```

常见模块号：

| 前缀 | 模块 |
| --- | --- |
| `106` | 用户模块 |
| `403` | 通用无权限（`UnAuthorizedError`） |
| `404` | 通用资源不存在（`NotFoundError`） |
:::

## BaseErrorCode 类层级

```python
# api/errcode/base.py
class BaseErrorCode:
    Code: int
    Msg: str

    @classmethod
    def return_resp(cls, msg=None, data=None) -> UnifiedResponseModel: ...
    @classmethod
    def http_exception(cls, msg=None) -> HTTPException: ...

class UnAuthorizedError(BaseErrorCode):  # 403 暂无操作权限
class NotFoundError(BaseErrorCode):      # 404 资源不存在

# api/errcode/user.py
class UserValidateError(BaseErrorCode):         # 10600
class UserPasswordExpireError(BaseErrorCode):   # 10601
class UserNotPasswordError(BaseErrorCode):      # 10602
class UserPasswordError(BaseErrorCode):         # 10603
class UserLoginOfflineError(BaseErrorCode):     # 10604
class UserNameAlreadyExistError(BaseErrorCode): # 10605
class UserNeedGroupAndRoleError(BaseErrorCode): # 10606
class UserGroupNotDeleteError(BaseErrorCode):   # 10610
```

::: warning 类存在但多数未实际使用
这些 `BaseErrorCode` 子类**存在于代码库中**，但当前各业务端点主要直接抛 `HTTPException`。上述 `106xx` 错误码更多作为「保留契约」与文档参考。对接时应以全局异常处理器返回的 `status_code` + `status_message` 为准。
:::

## 429 限流的特殊格式

::: danger 限流响应不走统一格式
限流响应**不**走 `UnifiedResponseModel`，而是直接的：

```json
{"detail": "请求过于频繁，请稍后重试"}
```

前端必须**兼容此特殊格式**，不能假设所有错误响应都有 `status_code` 字段。
:::

限流规则：

| 规则 | 值 |
| --- | --- |
| 维度 | `(client_ip, path)` |
| 上限 | 120 次 / 60 秒 |
| 超限响应 | `429` `{"detail": "请求过于频繁，请稍后重试"}` |

## 常见错误场景

| 场景 | status_code | 典型文案 |
| --- | --- | --- |
| 未携带 / Token 失效 | 401 | 登录状态已失效，请重新登录 |
| 对话积分不足 | 402 | 积分余额不足，请充值后再试 |
| 账号被禁用 | 403 | 账号已被禁用 |
| 支付回调验签失败 | 403 | 签名校验失败 |
| 生产环境调用 dev-login | 403 | — |
| 公告 / 工单 / 密钥 / 角色不存在 | 404 | 公告不存在 / 工单不存在 / 密钥不存在 / 角色不存在 |
| 用户名已存在（注册） | 409 | 用户名已存在 |
| 请求体结构错误 | 422 | （聚合的字段校验信息） |
| 触发限流 | 429 | 请求过于频繁，请稍后重试（`detail` 格式） |
| 图片理解调用失败 | 500 | 图片理解调用失败: <错误> |
| 未捕获异常 | 500 | 服务器内部错误，请稍后重试 |

## 相关文档

- [API 概览](./overview) — 通用约定、认证、限流
- [用户与认证 API](./user) — 401 / 403 场景
- [对话 API](./chat) — 402 积分不足场景
- [充值 API](./recharge) — 403 验签失败场景
