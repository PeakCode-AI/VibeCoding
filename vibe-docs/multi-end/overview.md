# 多端概览

VibeBase 是 Vibe 产品体系的用户端。完整的 Vibe 体系包含四个端，共享同一套用户、账本与经营数据。本页是多端协作的总览，各端详情见左侧目录。

## 四端一览

| 端 | 定位 | 技术栈 | 端口（开发） | 文档 |
| --- | --- | --- | --- | --- |
| **VibeBase** | C 端用户 Web | Vue 3 + FastAPI | 5175 / 8081 | [详情](./vibebase-web) |
| **VibeAdmin** | 运营后台 | Vue 3 + FastAPI | 5173 / 8080 | [详情](./vibeadmin) |
| **VibeApp** | 移动 App | Flutter | App | [详情](./vibeapp) |
| **Vibe-Mp-H5** | 小程序 / H5 | uni-app | 5174 | [详情](./vibe-mp-h5) |

![VibeBase 四端产品矩阵](/diagrams/product-matrix.svg)

## 协作模型

```
                 ┌─────────────────────────┐
                 │     最终用户（多端入口）   │
                 └────────────┬────────────┘
          ┌──────────────┬────┴────┬──────────────┐
          ▼              ▼         ▼              ▼
     ┌─────────┐   ┌─────────┐ ┌─────────┐  ┌──────────┐
     │VibeBase │   │VibeApp  │ │Vibe-Mp  │  │VibeAdmin │
     │  Web    │   │ Flutter │ │  -H5    │  │ 运营后台  │
     └────┬────┘   └────┬────┘ └────┬────┘  └────┬─────┘
          │             │           │            │
          └─────────────┴─────┬─────┴────────────┘
                              ▼
                   ┌─────────────────────┐
                   │  统一 API（FastAPI）  │
                   │  VibeBase :8081     │
                   │  VibeAdmin :8080    │
                   └──────────┬──────────┘
                              ▼
                   ┌─────────────────────┐
                   │  统一 PostgreSQL     │
                   │  + Redis            │
                   └─────────────────────┘
```

## 三个统一

四端能协作的核心，是共享三个「统一」：

### 1. 统一用户

所有端共用同一套 JWT 认证体系与 `users` 表。配合相同的 `SECRET_KEY`，VibeBase 与 VibeAdmin 的 Token 可跨服务互认。

- 一个用户在 Web 注册 → App / 小程序可直接登录
- 管理员在 VibeAdmin 封禁用户 → 所有端立即生效

### 2. 统一账本

积分、充值、消费记录全局唯一：

- 无论从哪个端充值，都进同一个 `point_accounts`
- 无论从哪个端对话，消费都记入 `api_logs` + `point_transactions`
- 运营在 VibeAdmin 看到的是全端汇总数据

### 3. 统一经营

VibeAdmin 基于同一数据库进行运营管理：

| 用户侧（VibeBase 等） | 运营侧（VibeAdmin） |
| --- | --- |
| 注册 | 用户管理 |
| 充值 | 订单 / 收入统计 |
| 提工单 | 工单处理 |
| 反馈 | 反馈查看 |
| 接收公告 | 发布公告 |

## 各端职责边界

::: tip 谁负责什么
- **VibeBase**：面向用户的完整产品（对话、充值、控制台、API Key 等）
- **VibeAdmin**：面向运营的管理后台（用户、订单、工单、收入、能力定价）
- **VibeApp**：复用 VibeBase API，提供原生移动体验
- **Vibe-Mp-H5**：复用 VibeBase API，覆盖微信生态
:::

## 该启动哪些端

| 你的目标 | 推荐组合 |
| --- | --- |
| 看产品全貌 | VibeBase + VibeAdmin |
| 只要 Web 产品 | VibeBase（用户 Web + 后端） |
| 要做微信生态 | VibeBase + Vibe-Mp-H5 |
| 要做原生 App | VibeBase + VibeApp |
| 完整商业化 | 全套四端 + VibeAdmin |

## 各端详细文档

- [VibeBase 用户 Web](./vibebase-web) — Vue 3 用户端
- [VibeAdmin 运营后台](./vibeadmin) — 运营管理
- [VibeApp Flutter](./vibeapp) — 移动 App
- [Vibe-Mp-H5 小程序](./vibe-mp-h5) — uni-app 小程序 / H5

## 相关文档

- [产品矩阵](../introduction/product-matrix) — 四端关系详解
- [技术架构](../introduction/architecture) — 整体技术栈
- [快速开始](../quickstart/requirements)
