# Vibe — 全终端 AI 对话产品体系

Vibe 是一套面向 **AI 对话产品商业化** 的完整解决方案，覆盖 **管理端 / 用户端 / App / 小程序+H5 / 支付中台** 五个终端。五大子项目工程独立、技术栈多样、业务数据共享，并补齐了**支付这一关键商业闭环**——直接可用于上线运营、收钱分账。

> 💡 已部署服务入口：[支付中台 VibePay](https://pay.vibeadmin.cn/) · 运营后台 VibeAdmin · 用户端 VibeBase

---

## 一、架构总览

### 用户视角：两入口体系

```
┌─────────────────────────────────────────────────────────────────┐
│                        最终用户                                  │
│              (使用AI对话、充值、管理API Key)                       │
└───────┬──────────────────────┬──────────────────────┬────────────┘
        │                      │                      │
   ┌────▼──────┐        ┌─────▼──────┐       ┌───────▼────────┐
   │ VibeApp   │        │ Vibe-Mp-H5 │       │   VibeBase     │
   │ Flutter   │        │ 小程序+H5  │       │   Web 端       │
   │ iOS/Android│       │ (微信/H5)  │       │(桌面/浏览器)    │
   └────┬──────┘        └─────┬──────┘       └───────┬────────┘
        │                     │                       │
        └─────────────────────┼───────────────────────┘
                              │
                      ┌────────▼────────┐
                      │   VibeBase 后端 │
                      │  (用户端 API)   │
                      │  FastAPI(:8081) │
                      └────────┬────────┘
                               │
                      ┌────────▼────────┐
                      │   VibeAdmin 后端│
                      │ (运营管理 API)   │
                      │  FastAPI(:8080) │
                      └────────┬────────┘
                               │
                      ┌────────▼────────┐
                      │   VibePay 支付  │
                      │  中台 (免签支付) │
                      │ Spring Boot(:8080)│
                      │ pay.vibeadmin.cn│
                      └────────┬────────┘
                               │
                      ┌────────▼────────┐
                      │ PostgreSQL+Redis│
                      │ (共享数据库)     │
                      └─────────────────┘
 ```

> VibePay 是补齐商业化闭环的**支付中台**：提供免签约的个人收款能力（微信 / 支付宝），通过安卓监控端实时监听收款通知并异步回调 VibeBase，让充值订单「支付即到账」。详见 [VibePay/README.md](VibePay/vibePay/README.md) 与已部署站点 [https://pay.vibeadmin.cn/](https://pay.vibeadmin.cn/)。

```
┌─────────────────────────────────────────────────────────────────┐
│                        运营人员/管理员                            │
│             (管理用户、订单、角色、系统设置)                       │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                      ┌────────▼────────┐
                      │   VibeAdmin Web │
                      │  管理后台前端    │
                      │  Vue3 + shadcn  │
                      │  浏览器 :5173    │
                      └────────┬────────┘
                               │
                      ┌────────▼────────┐
                      │  VibeAdmin 后端 │
                      │  运营管理 API    │
                      │  FastAPI(:8080)  │
                      └────────┬────────┘
                               │
                      ┌────────▼────────┐
                      │ PostgreSQL+Redis │
                      │  (同一共享数据库) │
                      └─────────────────┘
```

### 数据流：四端共享一套数据库

```
用户端入口（3个）：                             运营端入口（1个）：
VibeApp ──┐                                    VibeAdmin ──┐
Vibe-Mp-H5 ──┤                                    │
VibeBase Web ──┘                                  │
       │                                        │
       └── VibeBase 后端 (:8081)                └── VibeAdmin 后端 (:8080)
                 │                                        │
                 └── 同一 PostgreSQL + Redis ──────────────┘

 共享数据：
   users / roles / user_roles         ← C端用户（Base 产品 + Admin 运营都操作同一张表）
   recharge_orders / api_logs         ← 充值/日志（Base 产生数据，Admin 查看统计）
   dialogs / histories                ← 对话记录（Base 产生，Admin 可查看）
   admin_users / admin_roles          ← 管理员账号（仅 Admin 使用，与 C端用户分离）

 支付闭环：
   VibeBase 下单 → VibePay 生成收款二维码 → 用户微信/支付宝付款
   → 安卓监控端监听通知栏 → VibePay 回调 VibeBase /notify → 积分入账
 ```

---

## 二、项目矩阵

| 项目 | 面向 | 定位 | 技术栈 |
| --- | --- | --- | --- |
| **VibeAdmin** | 运营/管理员 | B 端管理后台 | Vue 3.5 + Vite 7 + FastAPI + PostgreSQL/Redis |
| **VibeBase** | 最终用户 | C 端 AI 对话 Web 产品 | Vue 3 + FastAPI + PostgreSQL/Redis |
| **VibeApp** | 移动用户 | Flutter 跨端 App | Flutter 3.7+ + Riverpod + GoRouter |
| **Vibe-Mp-H5** | 移动/微信用户 | 小程序 + H5 跨端 | uni-app + Vue 3 + TS + UnoCss + Wot UI |
| **VibePay** | 运营/商户 | 支付中台（免签收款） | Spring Boot 2.1 + PostgreSQL + 安卓监控端 |

### 功能对照

| 功能 | VibeAdmin | VibeBase | VibeApp | Vibe-Mp-H5 |
| --- | :---: | :---: | :---: | :---: |
| AI 智能对话 | — | ✅ | ✅* | ✅* |
| 用户注册/登录 | — | ✅ | ✅* | ✅* |
| 积分充值 | — | ✅ | ✅* | ✅* |
| API Key 管理 | — | ✅ | — | — |
| 帮助中心 | — | ✅ | — | — |
| 用户管理 | ✅ | — | — | — |
| 管理员管理 | ✅ | — | — | — |
| 角色权限 (RBAC) | ✅ | — | — | — |
| 充值订单管理 | ✅ | — | — | — |
| 收入统计看板 | ✅ | — | — | — |
| AI 能力配置 | ✅ | — | — | — |
| API 调用日志 | ✅ | — | — | — |
| 工单处理 | ✅ | — | — | — |
| 公告管理 | ✅ | — | — | — |
| 系统配置 | ✅ | — | — | — |
| 仪表盘趋势图 | ✅ | — | — | — |
| 免签约收款（微信/支付宝） | ✅ | ✅* | ✅* | ✅* |
| 支付订单 / 回调入账 | ✅ | — | — | — |
| 收款二维码管理 | ✅ | — | — | — |
| 多租户 / 应用接入 | ✅ | — | — | — |

> ✅* = VibeApp 和 Vibe-Mp-H5 当前处于脚手架阶段，业务页面待开发，但技术栈和目录已就位；其充值流程最终由 VibePay 支付中台统一承接。

---

## 四、快速启动

### 运营人员/管理员（想看看后台长什么样）

```bash
# 一键启动 VibeAdmin（前后端 + 数据库）
cd VibeAdmin && docker compose up -d --build
# 浏览器打开 http://localhost 即可访问后台
# 默认管理员：admin@example.com / admin123
```

### 最终用户体验（想看看用户产品）

```bash
# 1) 中间件（PostgreSQL + Redis）
docker compose -f docker-compose.middleware.yml up -d
# 2) VibeBase 后端 + 前端（见各项目详细说明）
cd VibeBase/vibe-base && .venv/bin/uvicorn main:app --port 8081 --reload &
cd VibeBase/vibe-base-web && npm run dev
# 浏览器打开 http://localhost:5175 即可体验 AI 对话
```

### 开发者启动（各端独立开发）

```
VibeAdmin:  cd VibeAdmin/vibe-admin-web && pnpm dev    → :5173
            cd VibeAdmin/vibe-admin    && python run_server.py → :8080

VibeBase:   cd VibeBase/vibe-base-web && npm run dev → :5175
            cd VibeBase/vibe-base      && python main.py → :8081

VibeApp:    cd VibeApp && flutter run

Vibe-Mp-H5: cd Vibe-Mp-H5 && pnpm dev:h5 → :5174
            cd Vibe-Mp-H5 && pnpm dev:mp → 微信开发者工具
```

---

## 五、每个项目详细说明

<details>
<summary><strong>VibeAdmin</strong> — B 端运营管理后台（点击展开）</summary>

### 定位

通用后台管理脚手架 + AI 能力运营后台示例。适合运营人员管理用户、订单、工单、公告、系统配置；也适合开发者作为二次开发底座改造为自己的 SaaS 后台。

### 技术栈

| 层 | 选型 |
| --- | --- |
| 前端框架 | Vue 3.5 + Vite 7 + TypeScript 5.8 |
| UI 组件 | shadcn-vue（基于 Reka UI，~200 组件） |
| 样式 | Tailwind CSS 4 + 暗色主题 + 自定义主题色 |
| 状态管理 | Pinia 3 + TanStack Query 5 |
| 路由 | 文件路由（unplugin-vue-router 自动生成） |
| 表单 | vee-validate 4 + zod 3 |
| 表格 | @tanstack/vue-table 8 |
| 图表 | @unovis/vue + vue-chrts |
| 国际化 | vue-i18n 11（中/英文） |
| HTTP | axios + 自动 Token 注入/刷新 |
| 后端 | FastAPI + Uvicorn + SQLAlchemy 2.0 |
| 数据库 | PostgreSQL 16（与 VibeBase 共享同一 `vibe` 库） |
| 认证 | JWT + bcrypt |

### 内置业务功能（可直接上线运营）

**通用底座：**
- JWT 认证（登录/注册/找回密码/OTP 验证）
- RBAC 权限引擎（4 预置角色：super_admin / operation / cs / finance）
- 全局命令面板（Cmd+K 搜索导航）
- 明暗主题切换 + 自定义主题色
- 中英文国际化
- 响应式布局（支持桌面/平板/手机）
- NProgress 页面加载进度条

**示例业务模块：**

| 模块 | 路由 | 核心字段/操作 |
| --- | --- | --- |
| 管理概览 | `/dashboard` | 注册用户数、今日新增、充值收入、API 调用量、趋势图、任务状态分布 |
| 用户管理 | `/users` | ID / 用户名 / 邮箱 / 余额 / 状态；禁用启用、重置密码、列表导出 |
| 管理员管理 | `/admins` | 管理员账号、角色分配、重置密码、启用/禁用 |
| 角色权限 | `/roles` | 4 预置角色 + 权限矩阵（JSON）；新建/编辑/删除自定义角色 |
| 充值订单 | `/recharge-orders` | 订单号 / 套餐 / 金额 / 积分 / 支付方式 / 状态；取消待支付订单 |
| 收入统计 | `/income` | 总收入 / 本月 / 今日 / 待结算；趋势图、支付方式占比 |
| AI 能力配置 | `/abilities` | 能力 ID / 名称 / 分类 / 积分单价 / 调用量；上架/下架、定价编辑 |
| API 调用日志 | `/api-logs` | 用户 / API Key / 能力 / 耗时 / 积分消耗 / 状态；分页筛选 |
| 工单处理 | `/tickets` | 状态流转：待处理→处理中→已解决→已关闭；优先级标记 |
| 公告管理 | `/announcements` | 标题 / 类型（system/feature/price）/ 发布 / 置顶 / 下线 |
| 系统设置 | `/settings/system` | 平台名称、客服邮箱、ICP 备案、频率限制、并发数、2FA、支付配置 |
| 智能体 | `/agents` | 任务分析 / 数据分析 / 报告生成三类 Agent 演示 |
| AI 对话 | `/ai-talk` | 对话界面示例（待对接流式输出） |

### 启动方式

```bash
# Docker 一键启动（推荐）
cd VibeAdmin && docker compose up -d --build
# 前端: http://localhost
# API: http://localhost:8080
# 默认管理员: admin@example.com / admin123

# 本地开发
cd VibeAdmin/vibe-admin && pip install -r requirements.txt && python setup_database.py && python run_server.py
cd VibeAdmin/vibe-admin-web && corepack enable && pnpm install && pnpm dev
```

### 商业授权

¥5,599 / 套，完整源码交付。详见 `VibeAdmin/doc/商业授权.md`。

</details>

<details>
<summary><strong>VibeBase</strong> — C 端用户 AI 对话产品（点击展开）</summary>

### 定位

面向最终用户的 AI 智能对话平台 Web 端。用户可以在浏览器中与 AI 对话、管理账户、充值积分、管理 API Key、查看用量统计。

### 技术栈

| 层 | 选型 |
| --- | --- |
| 前端框架 | Vue 3 + TypeScript + Vite |
| 样式 | Tailwind CSS 4 |
| 状态管理 | Pinia（18 个 store） |
| UI 组件 | shadcn-vue（Reka UI） |
| 网络 | axios |
| Markdown | marked + highlight.js |
| 富文本 | Tiptap + Image 扩展 |
| 后端 | FastAPI（venv + requirements.txt，Python ≥ 3.10） |
| 数据库 | PostgreSQL（与 VibeAdmin 共享 `vibe` 库） |
| AI 集成 | OpenAI SDK + LangChain Core |

### 功能模块

| 功能 | 路由 | 说明 |
| --- | --- | --- |
| 登录/注册 | `/login`, `/register` | 邮箱/用户名注册登录 |
| AI 对话 | `/chat` | 多 Agent 切换（Agent / MCPAgent），Markdown 渲染 |
| 控制台概览 | `/console` | 积分余额、用量概览 |
| 用量分析 | `/console/analytics` | API 调用趋势图、消耗统计 |
| 个人设置 | `/user/profile` | 昵称、头像、简介 |
| 安全中心 | `/user/security` | 修改密码 |
| 充值套餐 | `/recharge` | 多档积分套餐选择（微信/支付宝） |
| 充值记录 | `/recharge/records` | 历史充值订单 |
| 积分消费记录 | `/recharge/points` | 积分使用明细 |
| AI 能力列表 | `/ability` | 查看 AI 能力详情 |
| API Key 管理 | `/apikey` | 创建/删除/禁用 API Key |
| 系统公告 | `/announcement` | 平台通知列表 |
| 帮助中心 | `/help` | 使用帮助文档 |
| 角色权限 | `/role` | 查看自己的角色和权限 |

### 设计原型

`ui/pages/` 下包含 14 个 HTML 设计原型，可直接在浏览器中打开查看产品的视觉风格：
- 登录/注册、控制台概览、充值套餐、充值记录、积分消费记录
- 账号管理、个人设置、安全中心、API 能力列表、API Key 管理
- 角色权限管理、系统公告、帮助中心、用量分析

### 启动方式

```bash
# 1) 先启动共享中间件（PostgreSQL :5433 + Redis :6379）
docker compose -f docker-compose.middleware.yml up -d

# 2) 后端（已自带 .venv + .env）
cd VibeBase/vibe-base && .venv/bin/uvicorn main:app --host 0.0.0.0 --port 8081 --reload

# 3) 前端
cd VibeBase/vibe-base-web && npm install && npm run dev
# 默认直连真实后端；需要假数据时设置 VITE_ENABLE_MOCK=true
```

> ⚠️ VibeBase 与 VibeAdmin 共用同一 PostgreSQL（`vibe` 库，端口 5433），
> 启动后端前请确保中间件已运行。详细排障见 `STARTUP.md`。

### 与 VibeAdmin 的关系

VibeBase 和 VibeAdmin 共用同一套 PostgreSQL，VibeBase 产生的用户数据、充值订单、对话记录等，管理员在 VibeAdmin 后台中可以直接查看和运营。

</details>

<details>
<summary><strong>VibeApp</strong> — Flutter 移动端 App（点击展开）</summary>

### 定位

Flutter 跨端移动 App。当前是脚手架阶段，内置了 40+ UI 组件的演示页面和完整主题系统，可直接在其上开发 AI 对话、充值等业务功能。

### 技术栈

| 类别 | 选型 |
| --- | --- |
| 框架 | Flutter 3.7+ / Dart 3.0+ |
| 状态管理 | flutter_riverpod + riverpod_annotation |
| 路由 | GoRouter + ShellRoute（底部导航持久化） |
| UI 组件 | tdesign_flutter |
| 屏幕适配 | flutter_screenutil |
| 网络 | Dio |
| 存储 | shared_preferences |
| 代码生成 | build_runner + riverpod_generator |

### 内置功能

**底部导航 4 Tab：**
| Tab | 说明 |
| --- | --- |
| 基础 | 8 种基础设计元素：颜色/图标/按钮/字体/阴影/边框/弹性布局/标题 |
| 组件 | 14 种业务组件：表单/导航/数据展示/反馈/加载/覆盖层/布局/通知栏/数字输入/FAB/验证码/粘性布局/滑动操作/索引列表 |
| 模板 | 页面模板（可直接填充业务逻辑） |
| 关于 | 版本信息 |

**主题系统：**
- 浅色/深色双主题
- 主色：绿色 `#00A870`，辅色：蓝色 `#1E9FFF`
- 6 组渐变配色
- 12 级灰度体系
- Material 3 设计系统
- 完整 TextTheme、ButtonTheme、InputDecorationTheme

**颜色体系（236 行完整定义）：**
- 主色/辅色/成功/警告/危险/信息
- 背景/卡片/模态背景
- 文本主要/次要/辅助/反白
- 边框/分割线/遮罩
- 6 组渐变 + 工具方法动态取色

### 启动方式

```bash
cd VibeApp
flutter pub get
flutter run
dart run build_runner build   # 代码生成
```

</details>

<details>
<summary><strong>Vibe-Mp-H5</strong> — 微信小程序 + H5 端（点击展开）</summary>

### 定位

基于 unibest 框架（uniapp 生态）的小程序 + H5 跨端应用。一套代码同时运行于微信小程序和浏览器 H5，可扩展至支付宝/百度/抖音/快手小程序。

### 技术栈

| 类别 | 选型 |
| --- | --- |
| 框架 | uni-app + Vue 3 + TypeScript |
| 构建 | Vite + @dcloudio/vite-plugin-uni |
| 样式 | UnoCss（原子化 CSS） |
| 状态管理 | Pinia |
| 路由 | 约定式路由（@uni-helper/vite-plugin-uni-pages） |
| HTTP | alova（@alova/adapter-uniapp） |
| UI 组件 | Wot UI |
| 列表 | z-paging |
| 国际化 | vue-i18n |
| 类型校验 | vue-tsc |
| 单元测试 | vitest + jsdom |

### 平台兼容

| H5 | iOS | 安卓 | 微信 | 字节 | 快手 | 支付宝 | 百度 |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

### 目录结构

```
src/
├── api/            # 接口定义
├── components/     # 公共组件
├── hooks/          # 组合式函数
├── http/           # alova 请求封装（请求/响应拦截）
├── layouts/        # 布局组件
├── pages/          # 页面（约定式路由）
├── router/         # 路由配置
├── service/        # 业务服务层
├── store/          # Pinia 状态
├── styles/         # 样式
├── tabbar/         # 底部导航栏
├── types/          # TypeScript 类型
└── utils/          # 工具函数
```

### 启动方式

```bash
cd Vibe-Mp-H5
pnpm install

# H5 开发（浏览器打开 http://localhost:9000）
pnpm dev:h5

# 微信小程序开发（导入 dist/dev/mp-weixin 到微信开发者工具）
pnpm dev:mp

# 生产构建
pnpm build:h5      # H5 → dist/build/h5
pnpm build:mp      # 小程序 → dist/build/mp-weixin
```

</details>

<details>
<summary><strong>VibePay</strong> — 支付中台（免签收款，点击展开）</summary>

### 定位

Vibe 商业闭环的**支付中台**。为个人开发者、自媒体、电商店主提供**免签约、免营业执照**的微信 / 支付宝收款能力，资金直接到账你的个人账户，不经过任何第三方托管。通过安卓监控端实时监听收款通知栏消息，自动确认订单并异步回调业务系统（VibeBase），让「充值即到账」成为现实。

已部署线上站点：[https://pay.vibeadmin.cn/](https://pay.vibeadmin.cn/)

### 为什么需要 VibePay

| 痛点 | VibePay 解法 |
| --- | --- |
| 个人没有营业执照，无法签约微信/支付宝商户 | 免签约，用个人收款码即可收款 |
| 资金被第三方平台托管，提现慢、有风险 | 收款即时到账你的微信/支付宝，不经过中间账户 |
| 自己写支付对接成本高、要对账 | 安卓监控端自动监听通知、自动确认订单，免去人工对账 |
| 多业务、多商户要隔离 | 多租户 + 应用接入模型，按 `corporateId` / `appId` 隔离 |

### 技术栈

| 分类 | 技术 |
| --- | --- |
| 后端框架 | Spring Boot 2.1.1 (Spring MVC / JPA) |
| 数据库 | PostgreSQL（多租户 `tenant_id` 行级隔离） |
| 二维码生成 | ZXing (core / javase) |
| 监控端 | 安卓 App（监听通知栏 + 上报服务端，见 `vibePay-App/`） |
| 运行环境 | Java 8（WAR 包，可直接 `java -jar`） |
| 部署 | Docker / Docker Compose（内置多阶段构建） |

### 核心功能

- **免签约收款**：无需营业执照、无需繁琐签约，个人用户即可快速接入支付宝、微信收款。
- **智能通知栏监控**：安卓监控端实时监听支付到账通知，自动确认订单状态，无需手动对账。
- **开放 API**：创建订单 / 查询订单 / 订单状态 / 关闭订单 / 异步回调，完整覆盖接入场景。
- **安全可靠**：通讯密钥签名验证、订单超时机制、异步回调确认，多层保障资金安全。
- **二维码管理**：批量上传微信、支付宝收款二维码，支持固定金额与自动识别。
- **数据可视化**：管理后台展示订单数据、收入统计、来源占比。
- **多租户 SaaS**：按 `tenant_id` 行级隔离，每个租户独立通讯密钥、通知地址与收款码；进一步支持「公司级（Corporate）+ 应用级（App）」两层接入模型。

### 与 Vibe 体系的关系

```
VibeBase 下单充值
   │  调用 VibePay /createOrder
   ▼
VibePay 生成收款二维码 / 收银台链接
   │  用户微信/支付宝扫码付款
   ▼
安卓监控端监听通知栏 → 上报 VibePay
   │  VibePay 匹配订单 + 异步回调
   ▼
VibeBase /api/v1/recharge/notify → 积分入账
```

VibeBase 的充值模块（`api/v1/recharge.py`）对接 VibePay 的异步回调，实现「支付成功 → 积分自动到账」的完整商业闭环。

### 启动方式

```bash
# Docker 一键启动（推荐，内置 PostgreSQL）
cd VibePay/vibePay && docker compose up -d
# 访问 https://pay.vibeadmin.cn/

# 本地运行
cd VibePay/vibePay
mvn clean package
java -jar target/mq-0.0.1-SNAPSHOT.war
# 默认管理账号：admin / admin（首次启动随机生成 appKey，请务必修改）
```

### 文档与资源

- 项目文档：`VibePay/vibePay/README.md`
- 多租户 SaaS 设计：`VibePay/vibePay/docs/multi-tenant-design.md`
- 安卓监控端源码：`VibePay/vibePay-App/`
- 线上站点：[https://pay.vibeadmin.cn/](https://pay.vibeadmin.cn/)

</details>

---

## 六、目录结构全览

```
VibeCoding/
├── README.md                   # 本文件：项目总览
│
├── docs/                       # 统一文档
│   ├── README.md               #   文档索引
│   ├── architecture/
│   │   └── system-overview.md  #   四端架构设计
│   └── guides/
│       ├── getting-started.md   #   快速开始
│       └── deployment.md       #   部署指南
│
├── vibe_common/                # 共享 Python 库
│   ├── core/                   #   配置 + 安全（JWT/bcrypt）
│   ├── db/                     #   数据库引擎 + Redis 封装
│   ├── models/                 #   16 张表的 ORM 模型
│   └── README.md
│
├── VibeAdmin/                  # B 端 — 运营管理后台
│   ├── vibe-admin-web/         #   前端（Vue 3 + shadcn-vue）
│   │   ├── src/pages/          #     文件路由：12 个业务模块
│   │   ├── src/components/ui/ #     ~50 个 shadcn 组件
│   │   └── src/services/api/   #     16 个 API 封装
│   ├── vibe-admin/             #   后端（FastAPI + SQLAlchemy）
│   │   ├── app/api/v1/         #     API v1 端点
│   │   └── vibe_common/        #     vendored 共享库
│   ├── doc/                    #   6 份文档（需求/架构/技术/部署/数据库/授权）
│   ├── docker-compose.yml
│   └── Makefile
│
├── VibeBase/                   # C 端 — 用户 AI 对话产品
│   ├── vibe-base-web/          #   前端（Vue 3 + Tailwind）
│   │   ├── src/apis/           #     16 个 API 模块
│   │   ├── src/views/          #     14+ 页面视图
│   │   └── src/stores/         #     18 个状态 Store
│   ├── vibe-base/              #   后端（FastAPI + Poetry）
│   │   ├── api/v1/             #     API 接口
│   │   ├── database/           #     ORM 模型 + DAO
│   │   └── vibe_common/        #     vendored 共享库
│   ├── ui/                     #   14 个 HTML 设计原型
│   └── start_dev.sh
│
├── VibeApp/                    # 移动端 — Flutter App
│   ├── lib/
│   │   ├── app/                #   入口 + 路由（GoRouter）
│   │   ├── core/               #   主题（236 色）+ 颜色常量
│   │   └── features/           #   功能模块（40+ 组件演示）
│   └── pubspec.yaml
│
└── Vibe-Mp-H5/                 # 移动端 — 小程序 + H5
    ├── src/
    │   ├── pages/              #   页面（约定式路由）
    │   ├── api/                #   接口
    │   ├── components/         #   组件
    │   └── store/              #   状态
    ├── env/                    #   环境变量
    └── scripts/                #   辅助脚本

└── VibePay/                    # 支付中台 — 免签收款（商业闭环关键一环）
    ├── vibePay/                #   Spring Boot 服务端 + 管理后台前端 + 收银台
    │   ├── src/main/java/com/vone/mq/  #   多租户 SaaS 后端
    │   ├── src/main/resources/static/  #   管理后台 + 收银台页面
    │   ├── src/main/webapp/    #   落地页 / 登录 / API 文档 / 收银台
    │   ├── Dockerfile          #   多阶段构建（Maven + JRE）
    │   ├── docker-compose.yml  #   一键部署（含 PostgreSQL）
    │   └── docs/               #   多租户 SaaS 设计文档
    └── vibePay-App/            #   安卓监控端（监听收款通知 + 上报）
 ```

---

## 七、数据库体系

| 表名 | 所属 | 用途 | 共享范围 |
| --- | --- | --- | --- |
| `users` | C 端 | 用户账号、余额 | Admin + Base |
| `roles` | C 端 | 角色定义 | Admin + Base |
| `user_roles` | C 端 | 用户-角色关联 | Admin + Base |
| `admin_users` | B 端 | 管理员账号 | 仅 Admin |
| `admin_roles` | B 端 | 管理员角色+权限 | 仅 Admin |
| `dialogs` | C 端 | AI 对话会话 | Base 产生 |
| `histories` | C 端 | 对话消息 | Base 产生 |
| `message_likes/downs` | C 端 | 反馈 | Base 产生 |
| `recharge_orders` | 共享 | 充值订单 | Base 产生，Admin 管理 |
| `abilities` | 共享 | AI 能力配置 | Admin 配置，Base 消费 |
| `api_logs` | 共享 | API 调用日志 | Base 产生，Admin 查看 |
| `announcements` | 共享 | 系统公告 | Admin 发布，Base 展示 |
| `tickets` | 共享 | 用户工单 | Base 提交，Admin 处理 |
| `tasks` | 共享 | 运营任务 | 仅 Admin |
| `system_config` | 共享 | 系统设置 | 仅 Admin |

**VibePay（独立 PostgreSQL 库 `vibepay`）：**

| 表名 | 用途 | 共享范围 |
| --- | --- | --- |
| `tenant` / `tenant_monitor` | 商户(租户) / 监控端状态 | 每租户隔离 |
| `pay_order` | 支付订单 | 每租户隔离 |
| `pay_qrcode` | 收款二维码 | 每租户隔离 |
| `pay_app` | 应用级接入配置 | 每公司隔离 |
| `tmp_price` / `ticket` | 金额去重 / 工单 | 每租户隔离 |

> VibePay 使用独立的 PostgreSQL 实例（`vibepay` 库），与 VibeBase/VibeAdmin 的业务库解耦；二者通过 VibePay 的异步回调接口（`/notify`）与 VibeBase 充值模块对接，实现跨系统记账。

> 详见 `vibe_common/models/` 下的 16 个模型文件（VibeBase/VibeAdmin）。

---

## 八、端口速查

| 服务 | 端口 | 说明 |
| --- | --- | --- |
| VibeAdmin 前端（开发） | 5173 | `pnpm dev` |
| VibeAdmin 前端（Docker） | 80 | `docker compose up` |
| VibeAdmin 后端 | 8080 | FastAPI 接口 + `/docs` |
| VibeBase 前端（Docker） | 80 | `docker-compose up` |
| VibeBase 后端 | 8081 | FastAPI 接口 + `/docs` |
| VibePay 后端 | 8080 | Spring Boot（线上 `pay.vibeadmin.cn`） |
| VibePay PostgreSQL | 5432 | 支付库 `vibepay`（独立实例） |
| Vibe-Mp-H5（H5 开发） | 5174 | `pnpm dev:h5` |
| PostgreSQL | 5432 | 共享数据库（VibeBase/VibeAdmin） |
| Redis | 6379 | 缓存/限流 |

---

## 九、文档导航

### 顶层文档

| 文档 | 内容 |
| --- | --- |
| `README.md` | ← 你现在看的这个 |
| `docs/README.md` | 文档中心索引 |

### 架构与指南

| 文档 | 内容 |
| --- | --- |
| `docs/architecture/system-overview.md` | 四端分层架构、技术栈对照、数据流、部署拓扑 |
| `docs/guides/getting-started.md` | 四端快速启动命令全集 |
| `docs/guides/deployment.md` | Docker / 小程序 / App Store 部署要点 |

### 各项目详细文档

| 项目 | 文档 | 适合读者 |
| --- | --- | --- |
| VibeAdmin | `VibeAdmin/README.md` + `doc/*.md` + `vibe-admin-web/README.md` + `vibe-admin/README.md` | 运营人员 / 管理员 / 后端开发者 / 前端开发者 |
| VibeBase | `VibeBase/README.md` + `vibe-base-web/README.md` + `vibe-base/README.md` | 最终用户 / 前端开发者 / 后端开发者 |
| VibeApp | `VibeApp/README.md` | Flutter 开发者 / 移动端产品人员 |
| Vibe-Mp-H5 | `Vibe-Mp-H5/README.md` | 小程序开发者 / H5 开发者 |
| VibePay | `VibePay/vibePay/README.md` + `VibePay/vibePay/docs/multi-tenant-design.md` | 商户 / 支付集成开发者（线上 [pay.vibeadmin.cn](https://pay.vibeadmin.cn/)） |
| vibe_common | `vibe_common/README.md` | Python 后端开发者（模型维护者） |

---

## 十、许可证

| 项目 | 许可证 |
| --- | --- |
| VibeAdmin | 商业源代码授权（¥5,599/套），详见 `VibeAdmin/LICENSE` |
| VibeBase | MIT License |
| VibeApp | 详见 `VibeApp/` 内许可说明 |
| Vibe-Mp-H5 | MIT License（基于 unibest） |
| VibePay | MIT License（免签支付中台，线上 [pay.vibeadmin.cn](https://pay.vibeadmin.cn/)） |
| vibe_common | MIT License |