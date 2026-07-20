# Redis 配置

Redis 在 VibeBase 中承担两个核心职责：**接口限流**与 **Token 黑名单**。它被设计成**可选组件**——即使 Redis 宕机，服务也会自动降级放行（fail-open），保证主链路可用。

源码位置：`vibe_common/db/redis.py`，中间件在 `main.py` 中注册。

## 连接配置

连接串通过环境变量配置：

```bash
# .env
REDIS_URL=redis://localhost:6379/0
```

| 部分 | 默认 | 说明 |
| --- | --- | --- |
| 主机 | `localhost` | 开发本机 |
| 端口 | `6379` | Redis 默认端口 |
| 库号 | `0` | 选用的 DB 编号 |

::: tip 带密码的连接串
生产环境 Redis 一般需要密码，连接串格式为：

```bash
REDIS_URL=redis://:<密码>@<主机>:<端口>/<库号>
```

由于密码中可能含有特殊字符（如 `@`、`/`），建议先做 URL 编码。
:::

### 客户端创建

```python
# vibe_common/db/redis.py
_redis_client = aioredis.from_url(settings.REDIS_URL, decode_responses=True)
```

- 使用 `redis.asyncio`（异步客户端）作为主力，另提供 `get_redis_sync()` 同步客户端供中间件使用。
- `decode_responses=True` 表示返回值自动解码为字符串，无需再手动 `bytes.decode()`。
- 客户端为单例（`_redis_client`），整个进程复用同一个连接。

## 限流机制

### 固定窗口算法

VibeBase 采用**固定窗口（fixed window）**限流，实现在 `rate_limit_sync()`：

```python
def rate_limit_sync(key: str, limit: int, period: int) -> bool:
    r = get_redis_sync()
    ts = int(r.time()[0])
    bucket = f"rl:{key}:{ts // period}"
    count = r.incr(bucket)
    if count == 1:
        r.expire(bucket, period)
    return count <= limit
```

工作原理：把时间按 `period` 切分为窗口，每个窗口一个 Redis Key（`rl:{key}:{窗口序号}`），`INCR` 累计请求数，第 1 个请求设置过期；窗口内 `count <= limit` 即放行。

### 默认参数

| 参数 | 值 | 说明 |
| --- | --- | --- |
| `limit` | `120` | 单窗口最大请求数 |
| `period` | `60`（秒） | 窗口长度 |
| key | `vbase:{client_ip}:{path}` | 按客户端 IP + 请求路径隔离 |

即：**同一 IP 访问同一接口，60 秒内最多 120 次**。

### 超限响应

超过限制时，中间件直接返回 `429`：

```python
# main.py → rate_limit_middleware
return JSONResponse(
    status_code=429,
    content={"detail": "请求过于频繁，请稍后再试"},
)
```

::: warning 注意 429 的格式
限流的 429 响应走的是 `JSONResponse`（不经全局异常处理器），所以响应体就是 `{"detail": "请求过于频繁，请稍后再试"}`，**不是** `UnifiedResponseModel` 的三段式结构。前端需要兼容这两种格式。
:::

## Fail-open（失败放行）

这是 VibeBase 限流最关键的设计：**Redis 出问题时，请求一律放行**。

```python
# main.py
@app.middleware("http")
def rate_limit_middleware(request: Request, call_next):
    try:
        allowed = rate_limit_sync(...)
        if not allowed:
            return JSONResponse(status_code=429, ...)
    except Exception:
        pass              # ← 任何异常都吞掉，继续放行
    return call_next(request)
```

::: info 为什么 fail-open
限流属于**风控 / 反爬**类功能，不是业务主链路。如果限流本身挂掉（Redis 不可用）反而把请求全部拒绝，会让所有用户无法访问，属于典型的「防护反向拖垮业务」。VibeBase 选择宁可放开限流，也要保证业务可用。
:::

## 为什么 Redis 是可选的

综合以上两点：

1. **限流 fail-open**：Redis 挂了，接口仍可访问，只是失去限流保护。
2. **Token 黑名单 fail-open**：Redis 挂了，黑名单查询异常会被吞掉（视同未命中），登出的 Token 暂时仍有效，直到自然过期。

因此开发环境即使不启动 Redis，VibeBase 也能正常登录、对话。但生产环境**强烈建议**部署 Redis，否则会失去限流保护与即时登出能力。

::: danger 生产必须开启 Redis
- 没有限流 → 接口容易被刷爆、被恶意调用 LLM 接口烧钱
- 没有黑名单 → 用户「退出登录」实际上无法立即生效，旧 Token 仍可使用直到自然过期（最长 7 天）
:::

## Token 黑名单

用于实现「立即登出」与「主动吊销 Token」。

### 黑名单结构

```python
async def blacklist_token(token: str, expire_seconds: int) -> None:
    r = await get_redis()
    await r.set(f"bl:{token}", "1", ex=expire_seconds)
```

| 字段 | 说明 |
| --- | --- |
| Redis Key | `bl:{token}` |
| Value | `"1"`（占位） |
| TTL | `expire_seconds`，等于 Token 的剩余有效期 |

::: tip 为什么 TTL 设为剩余有效期
黑名单的目的只是让 Token「提前失效」。Token 一旦自然过期（`exp` 到了），它本来就无法通过 JWT 校验，没必要继续保留黑名单。把 TTL 设为剩余有效期可以自动回收内存，避免黑名单无限膨胀。
:::

### 主动吊销：`revoke_token`

```python
async def revoke_token(token: str):
    # 解码 JWT 取出 exp，计算剩余有效期，写入黑名单
    payload = decode(token)
    expire_seconds = payload["exp"] - now()
    await blacklist_token(token, expire_seconds)
```

登出流程会调用它，把当前 Token 写入黑名单。

### 查询：`is_token_blacklisted`

```python
async def is_token_blacklisted(token: str) -> bool:
    r = await get_redis()
    return bool(await r.exists(f"bl:{token}"))
```

被 `get_login_user` 认证依赖调用，命中黑名单即拒绝。详见 [JWT 与认证密钥](./jwt)。

## 验证 Redis 是否正常

### 方法一：健康端点

Redis 不影响 `/health`（它只返回 `{"status":"OK"}`），所以无法用它判断 Redis。

### 方法二：直接连接

```bash
# 用 redis-cli 测试
redis-cli -h localhost -p 6379 -n 0 ping
# 期望输出: PONG

# 查看是否有限流 key
redis-cli -n 0 --scan --pattern 'rl:*' | head

# 查看是否有黑名单 key
redis-cli -n 0 --scan --pattern 'bl:*' | head
```

### 方法三：观察 429

正常配置限流后，短时间内连续请求同一接口超过 120 次会收到 429：

```bash
# 连续打 200 次
for i in $(seq 1 200); do
  curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8081/api/v1/health
done | sort | uniq -c
# 部分输出 200，之后出现 429，说明限流生效
```

::: warning 限流按 path 隔离
key 是 `vbase:{ip}:{path}`，所以 `/health` 与 `/api/v1/xxx` 是**独立计数**的。测试限流时务必打同一个接口。
:::

## 排障

| 症状 | 排查 |
| --- | --- |
| 后端日志无 429，但 Redis 未启动 | fail-open 生效，Redis 异常被吞掉；属于设计行为 |
| 登出后旧 Token 仍可用 | Redis 未启动或 `is_token_blacklisted` 抛错被吞；确认 Redis 可达 |
| 限流不生效 / 计数不准 | 检查是否打在不同 `path` 上；限流按 IP + 路径隔离 |
| `Connection refused` 在日志但服务正常 | Redis 地址或端口错误；fail-open 兜底，业务不受影响 |
| 429 响应体与业务错误格式不一致 | 见上文「注意 429 的格式」，限流响应不经过全局异常处理器 |

::: details 临时关闭限流
如需在测试中临时关闭限流，可注释 `main.py` 中 `rate_limit_middleware` 的注册；不建议在生产环境这样做。
:::

## 相关文档

- [JWT 与认证密钥](./jwt) — 黑名单在认证依赖中的使用
- [后端配置](./backend) — 配置体系总览
- [数据库配置](./database) — PostgreSQL 主库
