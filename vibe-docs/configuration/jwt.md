# JWT 与认证密钥

VibeBase 的认证基于 **HS256 对称加密的 JWT**，采用**双 Token 机制**（access + refresh），并通过 Redis 维护**黑名单**实现主动登出。本页讲解密钥体系、Token 结构、认证依赖流程、密码双格式哈希与跨服务互通。

源码位置：`utils/JWT.py`、`api/services/user.py`、`vibe_common/core/config.py`。

## 算法与密钥

```python
# vibe_common/core/config.py
SECRET_KEY: str = "change-me-in-production"
ALGORITHM: str = "HS256"
```

| 项 | 值 | 说明 |
| --- | --- | --- |
| 算法 | `HS256` | HMAC-SHA256，对称加密（签发与校验同一密钥） |
| 密钥来源 | `settings.SECRET_KEY` | 对应环境变量 `SECRET_KEY` |
| 开发默认 | `change-me-in-production` | 仅开发可用 |
| `.env.example` 示例 | `vibe-dev-shared-secret-change-in-prod` | 提示需替换 |

`utils/JWT.py` 显式引用共享密钥，避免硬编码：

```python
JWT_SECRET_KEY = _app_settings.SECRET_KEY
```

::: danger 生产必须替换 SECRET_KEY
开发默认值是公开的，任何人都能伪造 Token。生产部署前**必须**在 `.env` 中设置一个高熵随机字符串：

```bash
# 生成 32 字节随机密钥
python -c "import secrets; print(secrets.token_urlsafe(32))"
```
:::

## 双 Token 机制

VibeBase 同时签发 access 与 refresh 两种 Token，结构与有效期不同：

```python
# utils/JWT.py
ACCESS_TOKEN_EXPIRE_TIME  = 7 * 24 * 3600    # 7 天
REFRESH_TOKEN_EXPIRE_TIME = 30 * 24 * 3600   # 30 天
```

| Token | 有效期 | 用途 |
| --- | --- | --- |
| access | 7 天 | 业务接口鉴权 |
| refresh | 30 天 | access 过期后用它换新 access |

### Payload 结构

两种 Token 携带相同的字段集合，靠 `type` 区分：

```json
{
  "user_name": "alice",
  "user_id": "u_123",
  "role": "user",
  "jti": "唯一标识",
  "type": "access",
  "exp": 1753000000
}
```

| 字段 | 说明 |
| --- | --- |
| `user_name` | 用户名 |
| `user_id` | 用户 ID |
| `role` | 角色信息 |
| `jti` | JWT ID，唯一标识该 Token |
| `type` | `access` 或 `refresh` |
| `exp` | 过期时间戳（秒） |

::: warning refresh Token 不能直接用于业务接口
`get_login_user` 依赖会**拒绝 `type=refresh` 的 Token** 访问业务端点（详见下文流程）。refresh Token 只能用于「换发新 access Token」这一个场景。
:::

## Token 传递

通过 HTTP 头：

```text
Authorization: Bearer <token>
```

前端（axios / fetch）需配置：

```ts
// axios 示例
axios.defaults.headers.common['Authorization'] = `Bearer ${token}`;
```

跨域时还需配合 CORS `allow_credentials=True`（见 [CORS 与跨端](./cors)）。

## 认证依赖流程

`api/services/user.py` 提供 `get_login_user(request)` 依赖，所有需要登录的接口都通过它拿当前用户。完整流程：

```text
┌──────────────────────────────────────────────────────────┐
│ 1. 白名单检查                                             │
│    request.state.is_whitelisted == True ?                │
│    → 是：直接放行（视为已登录管理员）                       │
└──────────────────────────────────────────────────────────┘
                          │ 否
                          ▼
┌──────────────────────────────────────────────────────────┐
│ 2. 取 Bearer Token                                        │
│    从 Authorization 头解析 "Bearer xxx"                    │
│    → 缺失/格式错：401                                     │
└──────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────┐
│ 3. Redis 黑名单检查                                       │
│    is_token_blacklisted(token) ?                          │
│    → 命中：401（已登出/吊销）                              │
└──────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────┐
│ 4. 解码 JWT                                                │
│    jwt.decode(token, SECRET_KEY, algorithms=["HS256"])   │
│    → 过期/签名错：401                                     │
└──────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────┐
│ 5. 拒绝 refresh 类型                                      │
│    payload.type == "refresh" ?                            │
│    → 是：401（refresh 不能用于业务端点）                   │
└──────────────────────────────────────────────────────────┘
                          │
                          ▼
                返回 UserPayload（当前用户）
```

::: tip 步骤 5 的意义
refresh Token 有效期更长（30 天），如果它能直接访问业务接口，等于「弱化了双 Token 的安全收益」。强制业务接口只用 access Token，refresh 仅用于换发，泄露后的影响面更小。
:::

## Token 黑名单

黑名单用于实现「立即登出」与「主动吊销」，详见 [Redis 配置 → Token 黑名单](./redis#token-黑名单)。

要点回顾：

| 项 | 值 |
| --- | --- |
| Redis Key | `bl:{token}` |
| TTL | Token 剩余有效期 |
| 写入时机 | 登出 / `revoke_token` |
| 校验时机 | `get_login_user` 步骤 3 |

登出流程：调用 `revoke_token(token)` → 解码 `exp` 算剩余时间 → `blacklist_token(token, 剩余秒数)`。之后该 Token 在任何接口都会被步骤 3 拦截。

::: warning Redis 不可用时的安全降级
黑名单查询失败会被 fail-open（视同未命中）。这意味着 Redis 宕机期间，登出的旧 Token 暂时仍可用，直到自然过期。生产环境务必保证 Redis 可达。
:::

## 密码哈希（双格式）

VibeBase 兼容**两种密码哈希格式**，便于历史数据迁移与不同来源的用户：

| 密文前缀 | 算法 | 说明 |
| --- | --- | --- |
| `$2`（含 `$2a$`、`$2b$`、`$2y$`） | **bcrypt** | 现代标准，带盐带 cost |
| 其他 | **SHA-256 hex** | 旧版/简单哈希 |

校验伪代码：

```python
def verify_password(plain: str, hashed: str) -> bool:
    if hashed.startswith("$2"):
        return bcrypt.checkpw(plain.encode(), hashed.encode())
    else:
        return hashlib.sha256(plain.encode()).hexdigest() == hashed
```

::: info 为什么保留两种
- bcrypt 是新用户的默认，安全性高（自带盐、抗暴力破解）。
- SHA-256 用于兼容 VibeAdmin 早期或导入的存量用户，避免一次性迁移。
- 通过 `$2` 前缀自动路由，无需在数据库额外存「算法类型」字段。
:::

::: danger SHA-256 不带盐不安全
纯 `sha256(password)` 易被彩虹表破解。**新建用户务必走 bcrypt**；存量 SHA-256 用户应在下次登录时静默升级为 bcrypt。
:::

## UserPayload 与 is_admin

认证通过后，依赖返回 `UserPayload` 对象：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `user_id` | str | 用户 ID |
| `user_name` | str | 用户名 |
| `user_role` | str/obj | 角色 |

### is_admin 判定

```python
class UserPayload:
    user_id: str
    user_name: str
    user_role: ...

    def is_admin(self) -> bool:
        # 检查是否为 AdminRole（role id == 1）
        ...
```

`is_admin()` 检查用户角色是否为 `AdminRole`（角色 ID 为 `1`）。需要管理员权限的接口用它做二次校验。

## 跨服务互通

VibeBase 与 VibeAdmin **共享同一个 `SECRET_KEY`**，使得两端的 JWT 互相可校验：

```text
VibeAdmin 签发的 Token ──┐
                         ├──► 用相同 SECRET_KEY 校验 ──► 都通过
VibeBase 签发的 Token ────┘
```

::: tip 跨服务互通的好处
- 用户在 VibeAdmin 后台登录后，Token 可直接用于 VibeBase 接口（反之亦然），无需二次登录或单点登录中间件。
- 配合共享的 PostgreSQL 数据库（见 [数据库配置](./database)），用户、订单、积分数据零孤岛。
:::

::: warning 共享密钥 = 共享信任域
任一服务泄露了 `SECRET_KEY`，另一个服务也立即沦陷（攻击者可伪造跨服务 Token）。请把 `.env` 严格纳入密钥管理，不要进 git。
:::

## 安全建议

| 建议 | 说明 |
| --- | --- |
| 生产替换 `SECRET_KEY` | 用高熵随机串，绝不留默认值 |
| 缩短 access 有效期 | 7 天偏长，生产可考虑缩短到几小时，配合 refresh 刷新 |
| 全站 HTTPS | 否则 Bearer Token 在传输中可被窃听 |
| Redis 高可用 | 黑名单依赖 Redis，宕机会导致登出失效 |
| 定期轮换 `SECRET_KEY` | 轮换后所有旧 Token 立即失效（用户需重新登录） |
| 密码用 bcrypt | 新用户强制 bcrypt，逐步淘汰 SHA-256 |
| 限制 refresh Token 复用 | refresh 也应记录是否被使用过，防止被盗用 |

::: danger 换密钥的副作用
`SECRET_KEY` 一旦变更，**所有已签发的 Token 立即失效**，全部用户需要重新登录。线上操作请选低峰期，并提前公告。
:::

## 排障

| 症状 | 排查 |
| --- | --- |
| 401 未授权 | Authorization 头缺失 / 格式错（必须 `Bearer ` 前缀） |
| 401 Token 已失效 | Token 过期，或命中 Redis 黑名单（已登出） |
| 401 但 Token 看着没过期 | Redis 黑名单命中；或 `SECRET_KEY` 被改过 |
| refresh Token 调业务接口 401 | 正常行为，refresh 只能换 access，不能直接访问业务端点 |
| 登出后 Token 仍可用 | Redis 未启动 / `is_token_blacklisted` fail-open；确认 Redis 可达 |
| VibeAdmin 的 Token 在 VibeBase 不认 | 两端 `SECRET_KEY` 不一致；同步 `.env` |
| 密码对却登录失败 | 历史用户哈希格式问题；确认 `$2` 前缀路由逻辑正确 |
| 换了 SECRET_KEY 后所有用户掉线 | 正常现象；旧 Token 全部失效 |

::: details 如何区分「过期」与「黑名单」
两者都返回 401，但原因不同：
- 过期：JWT 解码阶段抛 `ExpiredSignatureError`。
- 黑名单：JWT 本身有效，但 Redis `bl:{token}` 命中。

排查时看后端日志：如果日志先出现黑名单命中提示，再判定为黑名单；如果直接是签名/过期异常，则是 Token 本身问题。
:::

## 相关文档

- [Redis 配置](./redis) — 黑名单的实现细节
- [CORS 与跨端](./cors) — Authorization 头的跨域传递
- [后端配置](./backend) — 白名单路径机制
- [数据库配置](./database) — 与 VibeAdmin 共享用户表
