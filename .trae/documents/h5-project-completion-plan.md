# H5 项目补全计划：基础功能 + Demo + 注册登录

## Context

H5 项目（Vibe-Mp-H5）基于 uni-app + Vue3 + UnoCSS，当前仅完成了核心 AI 对话流程，但多个基本页面仍是空壳或功能缺失。对比 Flutter 端（VibeApp），H5 缺少：独立注册页、完整关于页、我的页面菜单项、账号设置、意见反馈、以及全部 Demo 演示页面。需要补全这些基本功能，保持与项目现有风格一致。

## 现状分析

| 页面 | 状态 | 问题 |
|------|------|------|
| 首页 | ✅ 已实现 | - |
| 登录 | ⚠️ 部分实现 | 无注册入口，仅有"自动创建"提示 |
| 我的 | ⚠️ 部分实现 | 菜单仅2项（账号设置→错误跳转、退出登录），缺少 AI对话/对话历史/意见反馈 |
| 关于 | ❌ 空壳 | 仅一行"关于页面"文字 |
| 注册 | ❌ 不存在 | - |
| 账号设置 | ❌ 不存在 | - |
| 修改密码 | ❌ 不存在 | - |
| 意见反馈 | ❌ 不存在 | - |
| Demo 页面 | ❌ 不存在 | Flutter 端有完整的基础/组件 Demo 体系 |

## 实施计划

### Phase 1: 基础设施

**1.1 token store 新增 register 方法**
- 文件：`src/store/token.ts`
- 从 `@/api/login` 额外导入 `register as _register`
- 新增 `register()` 方法，注册成功后复用 `_postLogin()` 写入 token
- return 中导出 `register`

**1.2 UnoCSS safelist 扩展**
- 文件：`uno.config.ts`
- 新增图标：`i-carbon-chat`, `i-carbon-history`, `i-carbon-feedback`, `i-carbon-settings`, `i-carbon-logout`, `i-carbon-color-palette`, `i-carbon-picture`, `i-carbon-button`, `i-carbon-text-font`, `i-carbon-border-all`, `i-carbon-shadow`, `i-carbon-grid`, `i-carbon-form`, `i-carbon-notification`, `i-carbon-renew`, `i-carbon-rocket`, `i-carbon-plug`, `i-carbon-admin`, `i-carbon-category`, `i-carbon-star`, `i-carbon-information`, `i-carbon-password`, `i-carbon-warning`, `i-carbon-checkmark`, `i-carbon-close`

### Phase 2: 核心业务页

**2.1 注册页** — 新建 `src/pages/register/index.vue`
- 品牌渐变背景 + 白色卡片布局（与登录页一致）
- 字段：用户名(必填)、邮箱(选填)、密码(必填)、确认密码(必填)
- 前端校验：非空、密码一致性、邮箱格式
- 调用 `tokenStore.register()`，成功跳转首页
- 底部"已有账号？去登录"链接

**2.2 登录页微调** — 修改 `src/pages/login/index.vue`
- 移除"未注册账号将自动创建"提示
- 新增"还没有账号？去注册"链接 → `/pages/register/index`

**2.3 意见反馈页** — 新建 `src/pages/feedback/index.vue`
- 多行文本框 + 联系方式(选填)
- 调用 `submitFeedback()` from `@/api/support`
- 提交成功 toast + 返回

**2.4 账号设置页** — 新建 `src/pages/settings/index.vue`
- 调用 `getProfile()` 展示用户资料
- 菜单项：头像、用户名、邮箱、个人描述（点击可编辑）
- 修改密码入口 → `/pages/settings/password`

**2.5 修改密码页** — 新建 `src/pages/settings/password.vue`
- 字段：旧密码、新密码、确认密码
- 调用 `setPassword()`

### Phase 3: 我的页面增强

**3.1 修改 `src/pages/me/me.vue`**
- 新增菜单项（在退出登录之前）：
  - AI 对话 → `/pages/chat/index`
  - 对话历史 → `/pages/dialog/list`
  - 意见反馈 → `/pages/feedback/index`
  - 账号设置 → `/pages/settings/index`（修正原 goLogin 错误跳转）
- 每个菜单项增加左侧图标（i-carbon-*）

### Phase 4: 关于页面重构

**4.1 修改 `src/pages/about/about.vue`**
- 上半部分：应用信息（品牌Logo、名称、版本标签）
- 核心能力卡片：快速启动、VibeBase集成、VibeAdmin对接、组件丰富、最佳实践
- 技术栈卡片：uni-app、Vue3、UnoCSS、TypeScript、Pinia
- 版本信息卡片
- Demo 入口区域：基础演示 + 组件演示 两个入口卡片
- 页脚：版权信息

### Phase 5: Demo 演示页面体系

**5.1 Demo 索引页** — 新建
- `src/pages/demo/basic.vue` — 基础演示列表（配色/图标/按钮/字体/边框/阴影/布局）
- `src/pages/demo/component.vue` — 组件演示列表（表单/反馈/加载/通知栏/验证码）

**5.2 Demo 子页面** — 新建 12 个文件

| 文件 | 标题 | 展示内容 |
|------|------|----------|
| `demo/color.vue` | 配色 | 品牌主色#018d71、功能色、中性色梯度、渐变 |
| `demo/icon.vue` | 图标 | i-carbon-* 系列、自定义图标、尺寸/颜色 |
| `demo/button.vue` | 按钮 | 主色/边框/文字/禁用/加载/不同尺寸 |
| `demo/typography.vue` | 字体 | H1-H6标题、正文、说明文字排版规范 |
| `demo/border.vue` | 边框与圆角 | 实线/虚线、rounded各尺寸、分割线 |
| `demo/shadow.vue` | 阴影 | shadow-sm/md/lg/xl/2xl/inner |
| `demo/flex.vue` | 布局 | Flex主轴/交叉轴、Grid、gap、常见布局 |
| `demo/form.vue` | 表单 | input/textarea/switch/radio/checkbox/picker |
| `demo/feedback.vue` | 反馈 | showToast/showModal/showActionSheet/showLoading |
| `demo/loading.vue` | 加载 | CSS spinner、骨架屏、进度条 |
| `demo/notice-bar.vue` | 通知栏 | 静态/滚动通知栏、info/warning/error类型 |
| `demo/verify-code.vue` | 验证码 | 60s倒计时按钮、获取验证码流程 |

## 设计规范（所有新页面统一遵循）

- **页面定义**: `definePage({ style: { navigationBarTitleText: '...' } })`
- **生命周期**: Tab页用 `onShow`，普通页用 `onLoad`，均从 `@dcloudio/uni-app` 导入
- **样式**: 优先 UnoCSS 工具类，复杂样式用 `<style scoped>`
- **品牌色**: 主色 `#018d71`，渐变 `linear-gradient(160deg, #018d71 0%, #06b89a 100%)`
- **背景**: 页面 `bg-[#f8fafc]`，卡片 `bg-white rounded-2xl shadow-sm`
- **按钮**: `bg-[#018d71] text-white rounded-[46rpx]`
- **输入框**: `bg-[#f5f6f8] rounded-xl px-4 h-[88rpx]`
- **API调用**: 统一从 `@/api` 导入，try/catch + uni.showToast 错误提示

## 验证方式

1. `pnpm dev:h5` 启动开发服务器
2. 验证注册/登录流程：注册新用户 → 自动登录 → 跳转首页
3. 验证我的页面：所有菜单项可点击跳转到对应页面
4. 验证关于页面：应用信息展示正常，Demo 入口可点击
5. 验证 Demo 子页面：每个 Demo 页内容正常渲染
6. 验证账号设置：资料展示、修改密码流程
7. 验证意见反馈：提交反馈功能
