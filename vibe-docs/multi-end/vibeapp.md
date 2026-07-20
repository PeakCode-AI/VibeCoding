# VibeApp Flutter

VibeApp 是 Vibe 体系的**移动 App 端**，基于 Flutter 构建，提供 iOS / Android 原生体验。它复用 VibeBase 的全部后端 API，只是换了 Flutter 的 UI 壳。

## 定位

VibeApp 的目标是覆盖**移动端原生用户**：

- 比 Web 更好的触达（桌面图标、推送通知）
- 比 H5 更流畅的原生体验
- 复用 VibeBase 的用户体系与计费体系（同一套账号、同一套积分）

## 技术栈

```text
框架      Flutter
语言      Dart
构建      build_runner（代码生成）
测试      Flutter widget / unit tests
```

## 与 VibeBase 的关系

VibeApp **不维护独立后端**，所有数据请求都打到 VibeBase API（`:8081`）：

```
VibeApp (Flutter)
    │
    │  HTTP / SSE (JWT Bearer)
    ▼
VibeBase API (:8081)
    │
    ▼
统一 PostgreSQL（与 Web 端共享）
```

这意味着：

- Web 端注册的用户，App 端可直接登录
- App 端的充值、消费与 Web 端共享同一积分账户
- App 端的对话历史与 Web 端共享（同一 `dialogs` / `histories`）

## 核心能力（复用 VibeBase）

VibeApp 可对接 VibeBase 的全部能力，包括：

- 用户注册 / 登录 / 邀请码
- AI 对话（SSE 流式）
- 积分查询与消费
- 充值下单
- 工单 / 反馈
- 公告接收

::: tip 移动端适配要点
对接 VibeBase API 时注意：
- **SSE 流式** — Flutter 需用支持 stream 的 HTTP 客户端（如 `dio` + `ResponseType.stream`）处理对话流
- **Token 存储** — 用 `flutter_secure_storage` 安全存储 JWT
- **图片上传** — 多部分表单上传到 `/api/v1/upload`
:::

## 目录结构

```
VibeApp/
├── lib/
│   ├── features/
│   │   └── .../presentation/    # 小 widget 组织在 features 下
│   └── ...
├── test/                        # widget / unit 测试
└── pubspec.yaml
```

::: info 编码规范
按 AGENTS.md：Flutter 用 `flutter analyze` 检查；优先在 `lib/features/.../presentation/` 下组织小 widget。
:::

## 开发命令

```bash
cd VibeApp
flutter pub get           # 安装依赖
flutter run               # 运行（选模拟器或真机）
dart run build_runner build   # 代码生成
flutter analyze           # 静态分析
```

## 对接 VibeBase API 的配置

VibeApp 需配置 VibeBase 后端地址。通常在 `lib/` 的配置文件或环境变量中：

```dart
// 示例：配置 API base URL
const String apiBaseUrl = 'https://your-domain.com/api/v1';
```

::: warning CORS
Flutter 原生 App **不受** CORS 限制（CORS 是浏览器策略）。所以 VibeApp 直连后端无需在 CORS 白名单加 App，但 Flutter Web 预留端口（5176）已在白名单中。
:::

## 上架

VibeApp 作为移动 App，上架需要：

| 平台 | 要求 |
| --- | --- |
| iOS App Store | Apple 开发者账号、应用审核 |
| Google Play | Google 开发者账号、应用审核 |
| 国内 Android | 各应用市场（华为 / 小米 / OPPO 等）审核 |

::: tip 参考文档
VibeBase 的 `vibe-docs` 部署章节中的 [ICP 备案](../deployment/icp-filing) 同样适用于 App 的后端服务备案。移动端本身的上架规范见各平台官方文档。
:::

## 相关文档

- [多端概览](./overview)
- [产品矩阵](../introduction/product-matrix)
- [API 概览](../api/overview) — VibeApp 对接的接口
- [技术架构](../introduction/architecture)
