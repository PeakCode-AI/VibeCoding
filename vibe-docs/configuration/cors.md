# CORS 与跨端

VibeBase 后端通过 FastAPI 的 `CORSMiddleware` 控制跨源访问。本页讲解前端端口白名单（含各端口分配）、为什么不用 `*`、`allow_credentials` 的含义、如何添加生产域名、Vite 开发代理的作用，以及典型的 CORS 错误排障。

源码位置：`main.py` → `register_middleware()`。

## 允许的来源（白名单）

VibeBase 显式列出所有允许的前端开发端口，**不使用通配符 `*`**：

```python
# main.py → register_middleware
origins = [
    'http://localhost:5173', 'http://127.0.0.1:5173',   # VibeAdmin 前端
    'http://localhost:5174', 'http://127.0.0.1:5174',   # Vibe-Mp-H5 前端
    'http://localhost:5175', 'http://127.0.0.1:5175',   # VibeBase 前端
    'http://localhost:5176', 'http://127.0.0.1:5176',   # VibeApp(Flutter web 预留)
]
```

### 端口分配

每个 Vibe 系产品占用一个独立的 Vite 默认端口，避免本地同时开发时冲突：

| 端口 | 产品 | 说明 |
| --- | --- | --- |
| `5173` | **VibeAdmin** | 后台管理前端 |
| `5174` | **Vibe-Mp-H5** | 小程序 / H5 前端 |
| `5175` | **VibeBase** | VibeBase 主前端 |
| `5176` | **VibeApp** | Flutter web 预留 |

::: tip 同时放行 localhost 和 127.0.0.1
浏览器把 `localhost` 和 `127.0.0.1` 视为**不同的源**（origin）。用户可能用任一形式访问，所以两者都要列。漏掉一个会出现「用 localhost 能登录、用 IP 登录报 CORS」的诡异现象。
:::

### 后端端口对应

后端段也按约定划分：`8080` 给 VibeAdmin，`8081` 给 VibeBase。CORS 白名单只关心**前端**端口，后端端口不影响跨源判断。

## 为什么不用 `*`

FastAPI/Starlette 的 `CORSMiddleware` 配置：

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)
```

| 选项 | 取值 | 说明 |
| --- | --- | --- |
| `allow_origins` | 显式列表 | **不能用 `*`** |
| `allow_credentials` | `True` | 允许携带 Cookie / Authorization |
| `allow_methods` | `['*']` | 所有 HTTP 方法 |
| `allow_headers` | `['*']` | 所有请求头 |

::: danger `*` 与 credentials 互斥
浏览器规范规定：当 `Access-Control-Allow-Credentials: true` 时，`Access-Control-Allow-Origin` **不能**是 `*`，必须是一个具体域名。如果同时设置 `*` 和 `credentials=true`，浏览器会**直接拒绝响应**，所有带凭证的请求全部失败。
:::

VibeBase 需要支持 Cookie / `Authorization: Bearer` 跨端传递，因此必须 `allow_credentials=True`，从而**被迫**用显式白名单。

::: info 允许 `*` 的代价
若关掉 `allow_credentials`，可以用 `*`，但前端就无法跨域携带 Cookie 和自定义凭证头，跨端登录态会丢失。VibeBase 选择了「凭证优先 + 白名单」的方案。
:::

## allow_credentials 的含义

设为 `True` 后，响应头会包含：

```text
Access-Control-Allow-Credentials: true
```

这告诉浏览器：跨源请求可以携带 **Cookie、Authorization 头、客户端 SSL 证书**。VibeBase 的 Token 走 `Authorization: Bearer`，前端通过 `fetch(..., {credentials: 'include'})` 或 axios `withCredentials: true` 时才能正确带上。

## 添加生产域名

白名单**写死在 `main.py`**，添加生产域名需编辑源码：

```python
# main.py → register_middleware()
origins = [
    # 开发环境
    'http://localhost:5173', 'http://127.0.0.1:5173',
    'http://localhost:5174', 'http://127.0.0.1:5174',
    'http://localhost:5175', 'http://127.0.0.1:5175',
    'http://localhost:5176', 'http://127.0.0.1:5176',
    # 生产环境（新增 ↓）
    'https://vibase.example.com',
    'https://admin.example.com',
]
```

::: warning 改完要重启
CORS 配置在应用启动时注册到中间件，热重载代码可能生效，但最稳妥的做法是**重启后端**。
:::

::: tip 协议必须匹配
`https://vibase.example.com` 与 `http://vibase.example.com` 是两个不同的源。生产环境通常全站 HTTPS，写 `https://` 即可；如果存在混合协议，需都列出。
:::

::: details 改成从环境变量读取（可选）
如果想把生产域名做成可配置，可以这样改造：

```python
import os
_extra = [o.strip() for o in os.getenv("EXTRA_CORS_ORIGINS", "").split(",") if o.strip()]
origins = [...默认开发端口...] + _extra
```

然后在 `.env` 配置：

```bash
EXTRA_CORS_ORIGINS=https://vibase.example.com,https://admin.example.com
```
:::

## Vite 开发代理

开发环境下，VibeBase 前端通过 **Vite dev server 的代理**转发 `/api` 请求到后端 `:8081`，可以**完全绕开 CORS**。

`vibe-base-web/vite.config.ts` 中：

```ts
server: {
  proxy: {
    '/api': {
      target: 'http://localhost:8081',
      changeOrigin: true,
    },
  },
}
```

工作流程：

```text
浏览器 (localhost:5175)
    │  fetch('/api/v1/...')
    ▼
Vite dev server (localhost:5175)   ← 同源，无 CORS
    │  proxy 转发
    ▼
VibeBase 后端 (localhost:8081)
```

::: tip 代理让请求「同源」
浏览器看到的请求目标是 `localhost:5175/api/...`（前端自己的域），由 Vite 服务端转发到后端。服务端到服务端的转发不受 CORS 限制，所以**开发期通常不会遇到 CORS 错误**。

CORS 错误大多出现在：
- 前端没走代理，直接请求 `http://localhost:8081`
- 前端域名不在白名单（典型：生产部署后忘加域名）
- 用了 `127.0.0.1` 而白名单只有 `localhost`（或反之）
:::

## 生产环境部署

生产环境通常有两种部署模式：

### 模式一：同源部署（推荐）

前端和后端通过 Nginx 反向代理合并到同一域名：

```text
https://vibase.example.com/         → 前端静态资源
https://vibase.example.com/api/     → 后端 FastAPI
```

这种模式下**不存在跨源**，CORS 配置可以保持开发白名单不动。

### 模式二：跨域部署

前端与后端各自独立域名（如 `vibase-web.example.com` + `vibase-api.example.com`），则必须把前端域名加到 `main.py` 白名单。

## CORS 错误的表现

浏览器拦截 CORS 请求时，前端会看到：

```text
Access to fetch at 'http://localhost:8081/api/v1/...' from origin
'http://localhost:5175' has been blocked by CORS policy:
No 'Access-Control-Allow-Origin' header is present on the requested resource.
```

或预检请求（OPTIONS）失败：

```text
... has been blocked by CORS policy:
Response to preflight request doesn't pass access control check:
It does not have HTTP ok status.
```

::: warning CORS 错误的迷惑性
- 后端代码可能正常执行了，但浏览器**不把响应交给 JS**。
- Network 面板里可能看到「(failed)」或状态码 `(blocked:cors)`。
- 服务端日志往往没有错误，因为请求其实到达了后端。
:::

## 排障指南

| 症状 | 排查 |
| --- | --- |
| 开发期 CORS 错误 | 前端是否走代理？检查 `vite.config.ts` 的 proxy；前端代码是否硬编码了 `http://localhost:8081` |
| 用 `localhost` 行、`127.0.0.1` 不行 | 白名单漏了一边；两者都要 |
| 生产部署后 CORS 失败 | 前端域名没加到 `main.py` 白名单；重启后端 |
| 预检 OPTIONS 失败 | `allow_methods`/`allow_headers` 是否覆盖；通常是带自定义头（如 `Authorization`）触发预检 |
| 带 Cookie 跨域失败 | `allow_credentials` 是否为 True；前端是否设了 `withCredentials`；`Allow-Origin` 是否为具体域名（非 `*`） |
| 报错说「credentials 模式下 origin 不能为 *」 | 误把 origins 设成了 `['*']`；改回显式列表 |
| 改了白名单不生效 | 中间件在启动时注册；`uvicorn --reload` 有时不会重新执行，手动重启 |

::: details 检查响应头的快速方法
```bash
curl -i -X OPTIONS http://localhost:8081/api/v1/user/login \
  -H "Origin: http://localhost:5175" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: authorization,content-type"
```
合法响应应包含：
```text
Access-Control-Allow-Origin: http://localhost:5175
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: ...
```
:::

## 相关文档

- [后端配置](./backend) — 中间件注册时机
- [前端配置](./frontend) — Vite 代理与环境变量
- [JWT 与认证密钥](./jwt) — Authorization 头的传递
