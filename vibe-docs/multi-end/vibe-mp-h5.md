# Vibe-Mp-H5 小程序

Vibe-Mp-H5 是 Vibe 体系的**小程序 / H5 端**，基于 uni-app 构建。一套代码可同时编译出微信小程序与 H5 网页，覆盖微信生态用户。

## 定位

Vibe-Mp-H5 解决的是**微信生态获客**问题：

- 微信小程序：即用即走、可分享、可投放
- H5：可嵌公众号、可外部分享
- 复用 VibeBase 的用户体系与计费体系

```
微信用户
   │
   ├─▶ 微信小程序（扫码 / 搜索 / 分享）
   │
   └─▶ H5 网页（公众号 / 外部分享）
            │
            ▼
      Vibe-Mp-H5（uni-app）
            │
            ▼
      VibeBase API (:8081)
```

## 技术栈

```text
框架      uni-app
语言      Vue 3 SFC（<script setup>）
样式      Tailwind 优先
构建      Vite (pnpm)
测试      Vitest + jsdom
语法检查  ESLint
```

::: info 编码规范
按 AGENTS.md：Uni/Vue 文件 SFC 块顺序为 `script`、`template`、style`。
:::

## 一套代码多端编译

uni-app 的核心价值：同一份源码编译到多端：

| 目标 | 命令 | 产物 |
| --- | --- | --- |
| 微信小程序 | `pnpm dev:mp` | 小程序代码（用微信开发者工具打开） |
| H5 | `pnpm dev:h5` | Web 页（浏览器访问 :5174） |
| 小程序生产 | `pnpm build:mp` | 可上传的发布包 |
| H5 生产 | `pnpm build:h5` | 静态站点 |

## 与 VibeBase 的关系

与 VibeApp 一样，Vibe-Mp-H5 **不维护独立后端**，复用 VibeBase API：

- 同一套账号登录（微信登录需后端额外对接微信 OAuth）
- 同一套积分与充值
- 同一套对话能力

::: warning 小程序特殊限制
- **域名白名单** — 微信小程序要求后端域名在小程序管理后台配置 request 合法域名（且必须 HTTPS）
- **SSE 兼容** — 微信小程序对 SSE 支持有限，可能需要用 WebSocket 或轮询适配对话流
- **支付** — 小程序内支付需用微信小程序支付（与 VibeBase 的模拟回调不同，需对接微信支付 SDK）
:::

## 开发命令

```bash
cd Vibe-Mp-H5
pnpm install
pnpm dev:h5           # H5 开发（http://localhost:5174）
pnpm dev:mp           # 小程序开发（产物在 dist/dev/mp，用微信开发者工具打开）
pnpm build:h5         # H5 生产构建
pnpm test:run         # 运行测试
pnpm lint             # ESLint
```

::: tip 端口约定
Vibe-Mp-H5 开发端口为 **5174**，已在 VibeBase 后端 CORS 白名单中。
:::

## 微信小程序对接清单

上线微信小程序需完成：

| 事项 | 说明 |
| --- | --- |
| 注册小程序账号 | 在 [mp.weixin.qq.com](https://mp.weixin.qq.com) 注册 |
| 配置 request 域名 | 小程序后台 → 开发管理 → 服务器域名 → 配置 VibeBase API 域名（HTTPS） |
| 微信登录对接 | 后端需实现 `code2session` 换取 openid，绑定到 users 表 |
| 微信支付对接 | 如需小程序内付费，对接微信小程序支付（V3 API） |
| 审核 | 提交代码包审核（涉及 AI 类目需相应资质） |

::: danger AI 类目资质
微信小程序对「AI 服务」类目有资质要求（可能需 ICP 证、算法备案等）。上架前务必查阅微信最新的类目资质要求。
:::

## 目录结构

```
Vibe-Mp-H5/
└── src/
    ├── pages/         # 页面（每个页面一个 .vue）
    ├── components/    # 组件
    ├── api/           # 接口调用
    ├── store/         # 状态管理
    ├── utils/         # 工具
    └── static/        # 静态资源
```

## H5 部署

H5 构建产物是静态站点，部署方式与 VibeBase 前端一致：

```bash
pnpm build:h5
# 产物在 dist/build/h5，部署到 Nginx
```

## 相关文档

- [多端概览](./overview)
- [产品矩阵](../introduction/product-matrix)
- [API 概览](../api/overview)
- [域名与 HTTPS](../deployment/domain-https)
- [ICP 备案](../deployment/icp-filing)
