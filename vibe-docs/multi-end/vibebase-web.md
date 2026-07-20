# VibeBase 用户 Web

VibeBase 用户 Web 是面向最终用户的前端界面，也是 VibeBase 的主体。本页是该端的概览说明（详细功能见 [功能指南](../guide/dashboard)）。

## 技术栈

```text
框架      Vue 3.5 + TypeScript 5.8
构建      Vite 6
样式      Tailwind CSS 4
状态      Pinia 3 + pinia-plugin-persistedstate
UI        shadcn-vue (基于 Reka UI)
路由      Vue Router 4 (hash 模式)
HTTP      axios
SSE       @microsoft/fetch-event-source
富文本    Tiptap 3
Markdown  marked + highlight.js
图标      lucide-vue-next + @iconify/vue
动画      @vueuse/motion
```

## 目录结构

```
vibe-base-web/src/
├── apis/          # API 调用（18 个模块）
├── components/    # 组件
│   ├── chat/      #   对话（Chat, ChatBubble, ModelSelector...）
│   ├── console/   #   控制台（ConsoleHeader, ConsoleSidebar...）
│   ├── home/      #   Landing 页各 section
│   ├── login/     #   登录注册
│   ├── sidebar/   #   导航（ConsoleNav, ChatSidebar...）
│   ├── ui/        #   shadcn-vue 基础组件
│   ├── settings/  #   设置组件
│   └── ...
├── composables/   # 组合式函数（useAuth, usePoints, useTable）
├── config/        # 常量（constants.ts）
├── stores/        # Pinia（19 个 store）
├── types/         # TypeScript 类型
├── utils/         # 工具（http, storage, markdown-parser）
├── views/         # 页面（auth, console, user, legal, error）
└── router/        # 路由配置
```

## 路由结构

VibeBase Web 用 hash 路由：

| 路由 | 页面 | 说明 |
| --- | --- | --- |
| `/` | LandingPage | 营销首页（公开） |
| `/app` | HomeLayout | 登录后壳（redirect 到 dashboard） |
| `/app/console/dashboard` | 控制台概览 | [指南](../guide/dashboard) |
| `/app/console/points-consume` | 积分消费 | [指南](../guide/points) |
| `/app/console/recharge-record` | 充值记录 | [指南](../guide/recharge) |
| `/app/console/recharge-package` | 充值套餐 | [指南](../guide/recharge) |
| `/app/console/api-key` | API Key | [指南](../guide/apikey) |
| `/app/console/api-ability` | 能力列表 | [指南](../guide/apikey) |
| `/app/console/analytics` | 用量分析 | [指南](../guide/analytics) |
| `/app/console/security` | 安全中心 | [指南](../guide/security) |
| `/app/console/my-tickets` | 我的工单 | [指南](../guide/ticket) |
| `/app/console/help` | 帮助中心 | FAQ |
| `/app/console/settings` | 个人设置 | [指南](../guide/settings) |
| `/auth/sign-in` | 登录 | 公开 |
| `/auth/sign-up` | 注册 | 公开 |
| `/auth/set-password` | 设置密码 | 登录后 |
| `/legal/terms` | 服务协议 | 公开 |
| `/legal/privacy` | 隐私协议 | 公开 |

::: tip 路由守卫
`router.beforeEach` 检查登录态：未登录访问受保护页 → 跳转登录；已登录访问 `/auth/*` → 跳转 `/app`。
:::

## Landing 页结构

营销首页由多个 section 组成：

1. **HeroSection** — 主标题「能收钱、能运营的 AI 产品」+ CTA
2. **StatsBar** — 数据展示
3. **ProductMatrix** — 四端矩阵介绍
4. **FeatureShowcase** — 三大维度特性（赚钱 / 省心 / 做稳）
5. **ArchitectureSection** — 业务架构图
6. **UseCaseGrid** — 适用场景
7. **WhyChooseUs** — 六大优势
8. **PricingSection** — 三档授权定价
9. **FaqSection** — 常见问题
10. Closing CTA

## 启动与开发

```bash
cd VibeBase/vibe-base-web
npm install
npm run dev          # http://localhost:5175

# 构建
npm run build:prod   # 产物在 dist/
```

详见 [快速开始](../quickstart/local-startup)。

## 与后端的连接

前端通过 axios 调用后端：

- **开发环境** — Vite proxy 把 `/api` 转发到 `:8081`，无跨域
- **生产环境** — Nginx 反向代理 `/api` 到后端

`VITE_API_BASE_URL` 配置后端地址（开发可留空走代理）。

## 主题与国际化

- **主题** — light / dark / system，存储于 `vibase-theme`
- **语言** — `vibase-language` 存储键（目前主要中文）

## Mock 模式

`VITE_ENABLE_MOCK` 开启后，以下 API 走本地 mock（便于离线演示）：

points、recharge、roles、analytics、security、console、ability、prompt、llm。

::: warning LLM 模型列表始终 mock
模型选择器目前是静态 mock（GPT-4 / GPT-3.5 / DeepSeek），与 `VITE_ENABLE_MOCK` 无关。
:::

## 相关文档

- [功能指南](../guide/dashboard) — 各页面操作说明
- [前端配置](../configuration/frontend) — 环境变量
- [前端开发规范](../development/frontend-conventions)
- [快速开始](../quickstart/local-startup)
