# 认证机制

VibeBase 采用 **JWT 双 Token + Redis 黑名单** 的认证方案：access token 用于业务鉴权，refresh token 用于无感续签，Redis 黑名单弥补 JWT 无法服务端踢人的缺陷。本页覆盖完整流程，源码在 `api/services/user.py` 与 `utils/JWT.py`。

![JWT 双 Token 认证流程](/diagrams/auth-flow.svg)

## 双 Token 机制

登录成功后，`get_user_jwt()` 同时签发两个 token，二者共享同一 `jti`（便于关联与吊销）：

| Token | type 字段 | 有效期 | 用途 |
| --- | --- | --- | --- |
| access | `access` | **7 天**（`ACCESS_TOKEN_EXPIRE_TIME = 7 * 24 * 3600`） | 业务接口鉴权 |
| refresh | `refresh` | **30 天**（`REFRESH_TOKEN_EXPIRE_TIME = 30 * 24 * 3600`） | 换取新的 access token |

```python
# api/services/user.py
def get_user_jwt(db_user: UserTable):
    jti = secrets.token_hex(16)
    now = datetime.utcnow()
    common = {
        'user_name': db_user.user_name,
        'user_id': db_user.user_id,
        'role': role,
        'jti': jti,
    }
    access_payload  = {**common, 'type': 'access',  'exp': now + timedelta(seconds=ACCESS_TOKEN_EXPIRE_TIME)}
    refresh_payload = {**common, 'type': 'refresh', 'exp': now + timedelta(seconds=REFRESH_TOKEN_EXPIRE_TIME)}
    access_token  = jwt.encode(access_payload,  JWT_SECRET_KEY, algorithm='HS256')
    refresh_token = jwt.encode(refresh_payload, JWT_SECRET_KEY, algorithm='HS256')
    return access_token, refresh_token, role
```

::: info 关键参数
- **算法**：HS256（对称加密，密钥为 `JWT_SECRET_KEY`，源自 `.env` 的 `SECRET_KEY`）
- **type 字段**：区分 access / refresh，业务接口拒绝 refresh 类型
- **jti**：随机 32 位 hex，作为 token 的唯一标识，便于关联
:::

## get_login_user 依赖：完整流程

`get_login_user(request)` 是 FastAPI 依赖，所有受保护端点通过 `Depends(get_login_user)` 注入。完整流程（来自 `api/services/user.py`）：

```text
请求进入 get_login_user(request)
        │
        ▼
1. 白名单检查
   request.state.is_whitelisted == True?
   （由 main.py 的 mark_whitelist_paths 中间件提前标记）
        │ 是
        ├──────────────────► 返回 UserPayload(user_id="1", user_name="Admin")
        │                     （视为管理员，放行）
        │ 否
        ▼
2. 提取 Bearer Token
   Authorization: Bearer <token>？
        │ 缺失/格式错
        ├──────────────────► 401 "Missing or invalid token"
        │ 存在
        ▼
3. Redis 黑名单检查
   is_token_blacklisted(token)？  （key: bl:{token}）
        │ 命中（已登出/已吊销）
        ├──────────────────► 401 "Token has been revoked"
        │ 未命中（Redis 异常时降级放行）
        ▼
4. 解码 JWT
   jwt.decode(token, JWT_SECRET_KEY, algorithms=['HS256'])
        │ 过期
        ├──────────────────► 401 "Token has expired"
        │ 非法
        ├──────────────────► 401 "Invalid authentication credentials"
        │ 有效
        ▼
5. 拒绝 refresh 类型
   payload['type'] == 'refresh'?
        │ 是（refresh 不能直接调业务接口）
        ├──────────────────► 401 "Invalid token type"
        │ 否（type=access）
        ▼
6. 返回 UserPayload(**payload)
   user_id / user_name / user_role 可用
```

::: warning Redis 降级策略
第 3 步的黑名单检查，若 Redis 不可用，会**降级放行**（不阻断鉴权），保证服务可用性。代价是：Redis 宕机期间「主动登出」不会立即生效，要等 access token 自然过期（最多 7 天）。
:::

## UserPayload 与角色

`UserPayload` 是认证后注入到端点的身份对象：

```python
class UserPayload:
    def __init__(self, **kwargs):
        self.user_id = kwargs.get('user_id')
        self.user_role = kwargs.get('role')
        if self.user_role != 'admin':
            roles = UserRoleDao.get_user_roles(self.user_id)
            self.user_role = [one.role_id for one in roles]
        self.user_name = kwargs.get('user_name')

    def is_admin(self):
        if self.user_role == 'admin':
            return True
        if isinstance(self.user_role, list):
            for one in self.user_role:
                if one.role_id == AdminRole:   # AdminRole = 1
                    return True
        return False
```

### 角色常量

定义在 `database/models/role.py`：

| 常量 | 值 | 含义 |
| --- | --- | --- |
| `SystemRole` | 0 | 系统管理员角色 |
| `AdminRole` | 1 | 超级管理员角色 |
| `DefaultRole` | 2 | 默认普通用户角色 |

用户标识常量：

| 常量 | 值 | 含义 |
| --- | --- | --- |
| `SystemUser` | `"0"` | 系统用户 |
| `AdminUser` | `"1"` | 管理员用户（白名单返回的 user_id） |

### is_admin() 判定

`is_admin()` 在两种情况下返回 `True`：
- `user_role == 'admin'`（JWT payload 直接带 admin 角色）
- `user_role` 是列表且包含 `role_id == AdminRole`（即 `1`）

## Redis Token 黑名单

黑名单用于实现「主动撤销」（登出、踢人），弥补 JWT 一旦签发就无法服务端回收的缺陷。

| 操作 | 函数 | 行为 |
| --- | --- | --- |
| 加入黑名单 | `blacklist_token(token, expire_seconds)` | `r.set(f"bl:{token}", "1", ex=ttl)` |
| 查询是否拉黑 | `is_token_blacklisted(token)` | `r.exists(f"bl:{token}")` |
| 吊销当前 token | `revoke_token(token)` | 解析 `exp`，按**剩余有效期**设置 TTL，过期后自动清除 |

```python
# vibe_common/db/redis.py
async def blacklist_token(token: str, expire_seconds: int) -> None:
    await r.set(f"bl:{token}", "1", ex=expire_seconds)

async def is_token_blacklisted(token: str) -> bool:
    return bool(await r.exists(f"bl:{token}"))
```

::: tip TTL 为什么取剩余有效期
`revoke_token` 把 TTL 设为 token 的剩余有效期，这样 token 自然过期后 Redis 里的黑名单记录也会被清除，避免黑名单无限增长。
:::

登出流程：前端调 `/api/v1/user/logout` → 后端 `revoke_token(access_token)`（可能连带吊销关联的 refresh）→ 后续请求带该 token 命中黑名单 → 401。

## 密码：双格式哈希

`UserService.verify_password` 同时兼容两种哈希格式，以兼容 VibeBase 自注册用户与 VibeAdmin 种子数据：

```python
@staticmethod
def verify_password(password: str, encrypted_password: str):
    if not encrypted_password:
        return False
    # bcrypt 哈希（$2a$ / $2b$ / $2y$）—— VibeAdmin seed_data 用 vibe_common.security 生成
    if encrypted_password.startswith('$2'):
        return bcrypt.checkpw(password.encode(), encrypted_password.encode())
    # SHA256 hex —— VibeBase register / set-password 生成
    return encrypt_sha256_password(password) == encrypted_password
```

| 哈希格式 | 前缀 | 来源 |
| --- | --- | --- |
| bcrypt | `$2`（`$2a$`/`$2b$`/`$2y$`） | VibeAdmin 种子数据（`vibe_common.security`） |
| SHA-256 hex | （无 `$2` 前缀） | VibeBase `register` / `set-password` |

::: warning SHA-256 不是最佳实践
VibeBase 自注册用户的密码用 SHA-256（无盐）存储，安全性弱于 bcrypt。若对安全要求高，建议统一迁移到 bcrypt。详见 [安全建议](#安全建议)。
:::

## 白名单机制

`config.{ENV}.yaml` 的 `whitelist_paths` 是**字符串前缀列表**，由 `main.py` 的 `mark_whitelist_paths` 中间件检查：

```python
@app.middleware("http")
def mark_whitelist_paths(request: Request, call_next):
    request.state.is_whitelisted = any(
        request.url.path.startswith(prefix) for prefix in app_settings.whitelist_paths
    )
    return call_next(request)
```

默认白名单（`config.dev.yaml`）：

```yaml
whitelist_paths:
  - /health
  - /api/v1/user/login
  - /api/v1/user/register
  - /api/v1/user/dev-login
  - /api/v1/recharge/notify
```

::: warning 白名单 ≠ 公开
白名单路径跳过的是 **JWT 认证**，不代表完全公开。例如 `/api/v1/recharge/notify` 虽在白名单，但仍有 HMAC-SHA256 签名校验（见 [充值与支付](./recharge-payment)）。白名单请求在 `get_login_user` 中会被视为 `user_id="1"` 的管理员。
:::

## dev-login 后门

为方便开发自测，`POST /api/v1/user/dev-login` 提供免密登录，固定返回 `dev_001` / `dev_user`（admin 身份）：

```python
@router.post('/user/dev-login')
async def dev_login():
    env = os.getenv("ENVIRONMENT", "dev")
    if env == "production":
        raise HTTPException(status_code=403, detail="dev-login 已在生产环境禁用")
    # 返回 user_id='dev_001', user_name='dev_user', role='admin'
```

::: danger 生产必须关闭
`dev-login` 仅在 `ENVIRONMENT != "production"` 时可用。部署到生产时务必设置 `ENVIRONMENT=production`，否则任何人都能免密以 admin 身份登录。建议同时从 `whitelist_paths` 移除 `/api/v1/user/dev-login`。
:::

`dev_001` 还享受对话免扣费的特权（见下一节）。

## 免扣费与特权账号

对话积分扣费时，以下 `user_id` **跳过扣费**，便于开发与测试：

```python
# api/v1/chat.py
if is_llm_configured() and login_user.user_id and login_user.user_id not in ("1", "dev_001"):
    consume_points(...)
```

| user_id | 身份 | 特权 |
| --- | --- | --- |
| `"1"` | 管理员（白名单请求返回） | 对话免扣费 |
| `"dev_001"` | dev-login 用户 | 对话免扣费 |

详见 [积分系统](./points-system)。

## 如何保护一个端点

两种依赖可选（详见 [后端开发规范](./backend-conventions#认证依赖)）：

```python
from api.services.user import UserPayload, get_login_user, UserService

# 方式 1：只需身份，不查库（轻量）
@router.get("/xxx")
async def handler(login_user: UserPayload = Depends(get_login_user)):
    # login_user.user_id / .user_name / .is_admin() 可用
    ...

# 方式 2：需要读用户字段（查库）
@router.get("/profile")
async def profile(user: UserTable = Depends(UserService.get_current_user)):
    # user.user_id / .user_name / .balance 都可用
    # 若 token 有效但用户已被删除 → 401 "登录状态已失效，请重新登录"
    ...

# 方式 3：仅需管理员
@router.get("/admin/xxx")
async def admin_handler(login_user: UserPayload = Depends(get_login_user)):
    if not login_user.is_admin():
        raise HTTPException(status_code=403, detail="需要管理员权限")
    ...
```

## 刷新 Token 流程

access token 过期后，前端用 refresh token 调刷新接口换取新 access token：

```python
# api/services/user.py
async def get_user_by_refresh_token(refresh_token: str) -> dict:
    payload = jwt.decode(refresh_token, JWT_SECRET_KEY, algorithms=['HS256'])
    if payload.get('type') != 'refresh':
        raise HTTPException(status_code=401, detail="Invalid token type")
    if await is_token_blacklisted(refresh_token):
        raise HTTPException(status_code=401, detail="Refresh token has been revoked")
    return payload
```

刷新接口同样会拒绝 access 类型、检查黑名单，保证旧 refresh token 在轮换后立即失效。

## 安全建议

::: warning 生产部署清单
- **`SECRET_KEY`**：必须改为高强度随机值（≥32 字节），绝不入库
- **`ENVIRONMENT=production`**：关闭 dev-login 后门
- **从白名单移除 dev-login**：`/api/v1/user/dev-login` 不应出现在生产 `whitelist_paths`
- **HTTPS**：JWT 明文传输，必须走 HTTPS
- **密码迁移到 bcrypt**：逐步把 SHA-256 哈希迁移到带盐 bcrypt
- **密钥轮换预案**：换 `SECRET_KEY` 会让所有旧 token 失效，需提前公告
- **Redis 高可用**：黑名单依赖 Redis，Redis 宕机会导致登出延迟生效
:::

## 排障

| 症状 | 排查 |
| --- | --- |
| 401 "Token has been revoked" | 该 token 已登出/吊销，重新登录 |
| 401 "Invalid token type" | 用 refresh token 调了业务接口，应改用 access token |
| 401 "Token has expired" | access token 超过 7 天，用 refresh token 换新 |
| 换密钥后全员掉线 | 正常现象，`SECRET_KEY` 变更使旧 token 全部失效 |
| dev-login 403 | `ENVIRONMENT=production` 已禁用后门（符合预期） |

## 接下来

- [后端开发规范](./backend-conventions) — 如何在端点注入认证依赖
- [积分系统](./points-system) — `dev_001` 等免扣费账号的来源
- [配置 · JWT 与认证密钥](../configuration/jwt) — 密钥配置
- [安全中心](../guide/security) — 用户侧安全功能
