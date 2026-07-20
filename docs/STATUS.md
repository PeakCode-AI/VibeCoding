# 项目实现状态与待办（STATUS / TODO）

> 本文档记录 VibeCoding 各子项目的**真实实现状态**，以及尚未完成的功能清单（待办）。
> 最后更新：2026-07-10（第七轮：产品 Demo 清零 + 架构硬化 + 两端业务页）
> 配套启动说明见根目录 `STARTUP.md`，架构总览见 `README.md`。

---

## 一、产品架构一览

| 子项目 | 角色 | 默认端口 |
| --- | --- | --- |
| VibeBase/vibe-base | C 端 API（FastAPI） | :8081 |
| VibeBase/vibe-base-web | C 端 Web 控制台 | Vite dev |
| VibeAdmin/vibe-admin | B 端运营 API | :8080 |
| VibeAdmin/vibe-admin-web | B 端管理前端 | Vite dev |
| Vibe-Mp-H5 | uni-app 移动端 H5/小程序 | — |
| VibeApp | Flutter 移动端 | — |
| VibePay/vibePay | 支付中台（Spring Boot，免签收款） | :8080（线上 `pay.vibeadmin.cn`） |
| VibePay/vibePay-App | 安卓监控端（监听收款通知上报） | — |

共享：PostgreSQL `vibe` 库 + Redis；`vibe_common` 双份 vendored（Base ↔ Admin，由 `scripts/check_vibe_common_sync.sh` 校验）。VibePay 使用**独立** PostgreSQL `vibepay` 库，通过 `/api/v1/recharge/notify` 回调与 VibeBase 充值模块对接，补齐「支付 → 入账」商业闭环。

---

## 二、已完成的后端接口（VibeBase，实测可用）

| 模块 | 接口 | 状态 | 说明 |
| --- | --- | :---: | --- |
| 认证 | `POST /user/register` `login` `refresh` `dev-login` | ✅ | 双 token；refresh 旋转 + 黑名单 |
| 用户 | `GET /user/info` `PUT /user/update` `icons` `set-password` | ✅ | **info 白名单序列化，无 `user_password`** |
| 资料 | `GET/PUT /user/profile` 与 `/settings/profile` 别名 | ✅ | 支持 `user_email` 更新；`to_dict(exclude=password)` |
| 对话 | `POST /chat` `upload` + dialog/message/history | ✅ | LLM 未配置时 SSE 降级不扣费 |
| 充值 | packages / order / records / callback / notify | ✅ | notify HMAC 幂等加积分 |
| 积分 | info / transactions / check / records | ✅ | |
| 控制台 | `GET /console/dashboard` | ✅ | 余额 + 今日消耗 + 最近流水 |
| 消费 | `GET /consume/records` | ✅ | |
| 工单 | `GET/POST /tickets` `GET /tickets/{id}` | ✅ | C 端提交，Admin 处理 |
| 反馈 | `POST /feedback` | ✅ | |
| 安全 | logout / operation-logs / devices | ✅ | 登录/改密埋点 |
| API Key / 公告 / 能力 / 分析 / 角色 / 子账号 | 对应 `/api/v1/*` | ✅ | |

VibeAdmin B 端核心模块（dashboard/users/tickets/agents/tasks/pricing…）此前轮次已接通，本轮未扩展范围。

---

## 三、Demo 清单（产品 vs 脚手架）

### 3.1 本轮已清零的**产品** Demo 缺口

| 表面 | 此前 | 现在 |
| --- | --- | --- |
| vibe-base-web 帮助工单 | **纯 mock**（无视 `isMockEnabled`） | mock 关闭时 `GET/POST /api/v1/tickets` |
| vibe-base-web 个人设置 | 路径/字段与后端错位风险 | 映射 `user_*` ↔ UI；真实 `/settings/profile` |
| vibe-base-web 控制台/消费 | mock-gated，默认真实 | 保持真实路径（smoke 已验） |
| Mp-H5 充值/积分/反馈 | **仅有 API 层，无页面** | `pages/recharge|points|feedback` + me 入口 |
| Flutter 充值/积分/反馈 | **仅有部分端点，无页面** | `features/recharge|points|support` + 路由 + 我的入口 |
| 双份 `vibe_common` | 不同步（缺 `operation_log`） | `check_vibe_common_sync.sh` exit 0 |
| `/user/info` 密码泄露 | STATUS 曾标记风险 | **白名单** `_USER_INFO_SAFE_KEYS` |

### 3.2 有意保留的脚手架 Demo（非产品缺口）

| 位置 | 说明 |
| --- | --- |
| Vibe-Mp-H5 `pages-sub/*`、`pages-fg/login/*`、`pages/about` 演示中心 | unibest 模板演示 |
| VibeApp `features/basic|component|template` | Flutter 组件画廊 |

### 3.3 明确延期（无后端产品 API / 需外部服务）

| 项 | 原因 |
| --- | --- |
| 提示词库 CRUD（`promptApi.ts`） | 无服务端 CRUD；UI 仅本地演示数据 |
| LLM 模型目录（`llmApi.ts`） | 无独立目录服务；对话走 `OPENAI_*` |
| 真实短信 OTP / TOTP 2FA | 需短信与 2FA 基础设施 |
| 官方支付网关 RSA/证书 | VibePay 支付中台已补齐免签收款 + 回调入账闭环；官方商户 RSA 验签可作为后续增强 |
| 邀请体系完善 | 前端有 invitation API 封装，非本轮目标 |
| 微信小程序原生 SSE 桥 | 非 H5 端需原生层 |

Mock 策略：`isMockEnabled()` 仅当 `VITE_ENABLE_MOCK=true`；**默认直连真实后端**。

---

## 四、本轮（第七轮 2026-07-10）变更摘要

### 架构
1. `rsync` 同步 Base → Admin `vibe_common`（含 `operation_log.py`）。
2. `UserService.get_user_info_by_id` 改为**字段白名单**输出，杜绝 `user_password`/`delete` 出站；`/user|settings/profile` 同步 exclude。
3. `PUT /user|settings/profile` 支持 `user_email`。
4. 注册 `user_id` 由 `len(users)+1` 改为 **UUID**，消除并发注册主键冲突。
5. 冒烟测试扩展：tickets / feedback / console / user/info 无密码 / profile（33 项全过）。

### vibe-base-web
1. `helpApi.ts`：工单真实 API；FAQ 保持静态内容。
2. `settingsApi.ts`：后端字段映射 + mock 门控。
3. 个人设置头像上传：带 Bearer、识别 `status_code`。
4. `promptApi` / `llmApi`：标注延期，避免伪装已落库。

### Vibe-Mp-H5
- 新增页：`pages/recharge`、`pages/points`、`pages/feedback`（对接既有 `@/api/*`）。
- `me` 菜单入口；`pages.json` 注册路由。
- 账号设置页此前已接通 profile/set-password。

### VibeApp
- 新增：`recharge` / `points` / `support` feature + 路由 `/recharge|/points|/feedback`。
- `ApiEndpoints` 补齐充值/工单等。
- `PointsInfo.fromJson` 兼容解包/整包。
- 测试：`test/product_api_wiring_test.dart`。

### 验证
- `scripts/check_vibe_common_sync.sh` → exit 0  
- `tests/smoke_test.py` → 含 `/recharge/callback` 对象 body 加积分 + notify 幂等  
- `tests/test_user_info_safe.py` → PASS  
- 客户端：源码结构检查（Mp-H5/Flutter 真实 `/api/v1/*` 路径与页面路由）  
- `flutter test test/product_api_wiring_test.dart`：本机 Flutter tester 因 SDK/HttpException 无法跑通，**不以 PASS 计**；以 `flutter analyze` + 结构断言为准（见 scratch `env_limit_flutter_test.txt`）  
- 充值 FE 路径：`POST /recharge/callback` body 为 `{"order_id":"..."}`（已修复早期 Body 裸字符串 422）  

---

## 五、剩余可选待办（非阻断）

| # | 项 | 优先级 |
| --- | --- | --- |
| O1 | 提示词库后端化 | P2 |
| O2 | 2FA/短信 OTP | P2 |
| O3 | VibePay 官方商户 RSA 验签增强（当前为免签监控 + HMAC） | P2 |
| O4 | 发布共享 `vibe_common` 包替代双拷贝 | P2 |
| O5 | 两端 App 图标 PNG 重制 / 小程序 SSE | P3 |

---

## 六、历史轮次回顾（摘要）

- 第一～三轮：analytics 500 修复、Mock 默认关、统一响应、错误中文、支付 notify、安全中心、Agents 联调。  
- 第四～五轮：双 token、两端登录与「我的」页。  
- 第六轮：品牌统一、全量接口层、对话核心页。  
- **第七轮（本轮）**：产品 Demo 工单/设置/移动充值积分反馈闭环 + vibe_common 同步 + user/info 白名单。
