# 前端配置

VibeBase 前端（`vibe-base-web`）基于 Vite + Vue3 构建。本页讲解环境变量、Vite 开发代理、Mock 模式覆盖范围、主题与语言配置、聊天常量限制、构建模式与 Docker 部署。

源码位置：`vibe-base-web/.env`、`vibe-base-web/vite.config.ts`。

## 环境变量

在 `vibe-base-web/.env` 中配置：

```bash
# 后端 API 地址
VITE_API_BASE_URL=http://localhost:8081

# 是否启用 Mock（很多接口用本地假数据）
VITE_ENABLE_MOCK=false
```

### VITE_API_BASE_URL

| 项 | 说明 |
| --- | --- |
| 含义 | 后端 API 的根地址 |
| 开发默认 | `http://localhost:8081` |
| 生产 | 部署后的后端域名，或同源相对路径 |

::: tip 开发期可以留空走代理
如果前端代码用相对路径（如 `/api/v1/...`）请求接口，开发期可以不设 `VITE_API_BASE_URL`，让 Vite proxy 转发到后端（见下文）。生产期同源部署同理。
:::

### VITE_ENABLE_MOCK

打开后，大量接口会**用前端本地假数据响应**，不请求后端。主要用于：

- 后端尚未开发完成时，前端独立联调
- 演示 / Demo 场景

::: warning Mock 不覆盖全部
Mock 仅覆盖一部分接口（详见下文清单）。LLM 模型列表、登录等关键链路不随此开关变化。
:::

## Vite 开发代理

`vite-base-web/vite.config.ts` 中配置了 `/api` 转发：

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
    │  fetch('/api/v1/user/login')    ← 相对路径
    ▼
Vite dev server (localhost:5175)       ← 同源，浏览器无 CORS 拦截
    │  代理转发到 target
    ▼
VibeBase 后端 (localhost:8081)
```

::: tip 代理的两大好处
1. **绕开 CORS**：浏览器看到的请求都是 `localhost:5175`，不跨源。
2. **统一前缀**：前端代码统一用 `/api/...`，无需区分环境。

详见 [CORS 与跨端 → Vite 开发代理](./cors#vite-开发代理)。
:::

::: warning 代理仅在 dev 生效
`vite build` 产物里**没有**代理逻辑。生产部署必须通过 Nginx 反向代理或显式设置 `VITE_API_BASE_URL` 指向后端。
:::

## Mock 模式

`VITE_ENABLE_MOCK=true` 时，以下接口由前端 Mock 数据驱动：

| 模块 | 是否 Mock |
| --- | --- |
| 积分（points） | ✅ |
| 充值（recharge） | ✅ |
| 角色（roles） | ✅ |
| 数据分析（analytics） | ✅ |
| 安全（security） | ✅ |
| 控制台（console） | ✅ |
| 能力（ability） | ✅ |
| 提示词（prompt） | ✅ |
| LLM（llm） | ✅ |

### LLM 模型列表始终是静态 Mock

注意一个特例：**LLM 模型下拉列表**（如 GPT-4、GPT-3.5 Turbo、DeepSeek）**永远是前端写死的静态列表**，与 `VITE_ENABLE_MOCK` 开关无关。

```text
LLM 模型下拉 = ["GPT-4", "GPT-3.5 Turbo", "DeepSeek"]   ← 写死
```

::: danger 前端模型 ≠ 后端实际模型
前端选了 GPT-4，后端实际调用的还是 `OPENAI_MODEL`（默认 `qwen-plus`）。前端这个下拉只是 UI 占位，**不会**影响后端真实模型。详见 [LLM 模型配置](./llm#前端模型列表是写死的)。
:::

## 主题配置

| 项 | 值 |
| --- | --- |
| 支持主题 | `light` / `dark` / `system`（跟随系统） |
| localStorage Key | `vibase-theme` |
| 切换开关 | 受 `ENABLE_TOGGLE` 环境变量控制 |

::: tip system 模式
选 `system` 时，前端监听浏览器的 `prefers-color-scheme`，自动跟随操作系统的明暗模式。
:::

::: warning ENABLE_TOGGLE 的作用
主题切换按钮的显示由 `ENABLE_TOGGLE` 控制（env-gated）。关闭后用户无法手动切换主题，适用于需要锁定品牌色的场景。
:::

## 语言配置

| 项 | 值 |
| --- | --- |
| localStorage Key | `vibase-language` |

切换语言后，选择会持久化在 `vibase-language` 中，下次访问自动恢复。

## 聊天常量

对话页面有几个硬编码的前端限制：

| 常量 | 值 | 说明 |
| --- | --- | --- |
| 最大消息长度 | **4000 字符** | 单条消息输入上限 |
| 最大历史条数 | **100 条** | 本地保留的对话历史数 |
| 自动保存间隔 | **5 秒** | 草稿/会话自动保存周期 |

::: info 前后端的窗口差异
- 前端本地最多保留 **100 条**历史。
- 后端发给 LLM 的上下文只用最近 **10 条**（见 [LLM 模型配置 → 历史窗口](./llm#历史窗口)）。
- 两者不冲突：100 条是「展示与留存」，10 条是「喂给模型的窗口」。
:::

::: warning 4000 字符是前端校验
超过 4000 字符前端会直接拦截，不会发请求。后端可能有自己的长度限制，但前端这个值是第一道闸。
:::

## 构建模式

前端支持多种环境构建：

```bash
# 开发（带 HMR、proxy）
npm run dev

# 测试环境构建
npm run build:test

# 生产构建
npm run build
```

| 模式 | 命令 | 用途 |
| --- | --- | --- |
| dev | `npm run dev` | 本地开发，启动 Vite dev server（端口 5175） |
| test | `npm run build:test` | 构建测试环境产物（通常读 `.env.test`） |
| prod | `npm run build` | 构建生产产物（读 `.env.production`） |

::: tip 多环境 .env
Vite 会按当前模式加载对应的 `.env` 文件：

- `.env` — 所有模式共享
- `.env.development` — `npm run dev`
- `.env.test` — `npm run build:test`
- `.env.production` — `npm run build`

把 `VITE_API_BASE_URL` 在不同文件里设不同值，即可实现「dev 打 8081、prod 打生产域名」。
:::

::: warning 只有 `VITE_` 前缀的变量会暴露给前端
Vite 仅把以 `VITE_` 开头的环境变量注入到 `import.meta.env`。**切勿**把后端密钥（`OPENAI_API_KEY`、`SECRET_KEY` 等）放在前端 `.env` 中并以 `VITE_` 前缀暴露——这些会被打包进静态资源，任何人都能在浏览器里看到。
:::

## Docker 构建

前端通常用多阶段 Dockerfile 构建：

```dockerfile
# 阶段 1：构建静态资源
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build         # 产物在 /app/dist

# 阶段 2：用 Nginx 托管
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
```

### Nginx 反向代理 `/api`

生产部署最常见的模式是把前端静态资源和后端 API 放在同一域名下：

```nginx
server {
    listen 80;
    server_name vibase.example.com;

    # 前端静态资源
    location / {
        root /usr/share/nginx/html;
        try_files $uri $uri/ /index.html;
    }

    # 后端 API 反向代理（相当于生产版的 Vite proxy）
    location /api/ {
        proxy_pass http://backend:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

::: tip 同源部署的优势
这种模式下前端和后端同域（`https://vibase.example.com`），**不存在 CORS**，后端的 CORS 白名单甚至不用动。详见 [CORS 与跨端 → 生产环境部署](./cors#生产环境部署)。
:::

## 排障

| 症状 | 排查 |
| --- | --- |
| 开发期接口 404 | `vite.config.ts` 的 proxy target 是否正确；后端是否在 8081 |
| 开发期 CORS 错误 | 前端是否走了代理；是否硬编码了 `http://localhost:8081` 绕开代理 |
| 生产 404 / 接口打不到 | `VITE_API_BASE_URL` 未配；或 Nginx 未配 `/api` 反向代理 |
| 改了 `.env` 不生效 | Vite 启动时读一次；重启 `npm run dev` |
| 切换主题无效果 | `ENABLE_TOGGLE` 关闭；或 localStorage `vibase-theme` 值异常 |
| Mock 数据还在出现 | `VITE_ENABLE_MOCK` 未关；或读到了错误的 `.env.*` 文件 |
| 选 GPT-4 实际还是 qwen-plus | 正常现象，前端模型列表是静态 mock；后端实际模型由 `OPENAI_MODEL` 决定 |
| 历史超过 100 条后丢失 | 前端只保留最近 100 条；如需更长历史，后端持久化 + 分页加载 |
| 浏览器密钥泄露 | 检查 `.env` 是否把后端密钥误用 `VITE_` 前缀 |

::: details 检查实际生效的环境变量
在浏览器控制台执行：

```js
console.log(import.meta.env)
```
能看到所有注入的 `VITE_` 变量。如果某个变量没出现，多半是拼写没加 `VITE_` 前缀，或没有重启 dev server。
:::

## 相关文档

- [CORS 与跨端](./cors) — 前端端口白名单与代理
- [LLM 模型配置](./llm) — 前端模型列表与后端实际模型的关系
- [后端配置](./backend) — 后端的 `.env` 与 `config.yaml`
- [部署指南](../deployment/docker) — 生产环境完整部署
