# 文档中心

本目录汇总 Vibe 产品体系的统一文档，按「架构」与「指南」两大类组织。各子项目自身也保留独立文档（如 `VibeAdmin/doc/`、`VibeBase/README.md`），本目录用于跨项目的整体梳理与索引。

## 架构（Architecture）

| 文档 | 说明 |
| --- | --- |
| [system-overview.md](architecture/system-overview.md) | 四端（B/C/App/小程序+H5）整体架构、职责划分、技术栈与数据流 |

## 指南（Guides）

| 文档 | 说明 |
| --- | --- |
| [getting-started.md](guides/getting-started.md) | 各子项目的本地/源码运行方式 |
| [deployment.md](guides/deployment.md) | Docker / 容器化部署要点与端口对照 |
| [verify_proxy.md](verify_proxy.md) | OpenAI 兼容代理端点端到端验证（curl + Python/Dart SDK 示例） |
| [STATUS.md](STATUS.md) | 各后端接口实现状态 + 未实现功能待办清单（TODO） |

## 子项目文档入口

- VibeAdmin：`VibeAdmin/README.md`（项目总览、商业授权）→ `VibeAdmin/doc/`（需求/架构/技术/部署/数据库/商业授权）→ `VibeAdmin/vibe-admin-web/README.md`（前端详细文档）→ `VibeAdmin/vibe-admin/README.md`（后端详细文档）
- VibeBase：`VibeBase/README.md`（项目总览）→ `VibeBase/vibe-base-web/README.md`（前端详细文档）→ `VibeBase/vibe-base/README.md`（后端详细文档）
- VibeApp：`VibeApp/README.md`
- Vibe-Mp-H5：`Vibe-Mp-H5/README.md`
- VibePay：`VibePay/vibePay/README.md`（支付中台总览）→ `VibePay/vibePay/docs/multi-tenant-design.md`（多租户 SaaS 设计）→ 线上站点 [https://pay.vibeadmin.cn/](https://pay.vibeadmin.cn/)
- vibe_common：`vibe_common/README.md`（共享库模型/DB/Redis/安全）
