# 公告 API

平台公告的查询。仅返回已发布（`status="published"`）的公告，按置顶优先、发布时间倒序排列。

## 接口总览

| 方法 | 路径 | 认证 | 说明 |
| --- | --- | --- | --- |
| GET | `/announcement` | 公开 | 公告列表 |
| GET | `/announcement/{ann_id}` | 公开 | 单条公告 |

## 公告类型

公告 `type` 字段在序列化时映射为前端友好的分类标签：

| 原始 type | 映射值 | 含义 |
| --- | --- | --- |
| `system` | `maintenance` | 维护 |
| `feature` | `feature` | 新功能 |
| `price` | `pricing` | 定价 |
| `version` | `version` | 版本 |
| `security` | `security` | 安全 |

未匹配的 type 默认映射为 `maintenance`。

## 公告字段

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | string | 主键 UUID |
| `title` | string | 标题 |
| `content` | string | 正文 |
| `type` | string | 映射后的分类 |
| `date` | string | 发布时间（ISO） |
| `is_latest` | bool | 是否置顶（取自 `pinned`） |

原始模型 `announcements` 表字段：`announce_id`（如 `ANN012`）、`title`、`type`、`content`、`status`（`published` / `offline`）、`pinned`、`published_at`。

## 公告列表

```
GET /api/v1/announcement
```

**认证：** 公开

**说明：** 查询 `status="published"` 的公告，按 `pinned` 降序、`published_at` 降序排列。

**响应示例：**

```json
{
  "status_code": 200,
  "data": [
    {
      "id": "uuid-1",
      "title": "VibeAI 平台正式上线",
      "content": "欢迎使用 VibeAI 智能对话平台！",
      "type": "maintenance",
      "date": "2026-06-15T00:00:00",
      "is_latest": true
    },
    {
      "id": "uuid-2",
      "title": "图像生成功能升级通知",
      "content": "图像生成能力已升级至最新版本。",
      "type": "feature",
      "date": "2026-07-01T00:00:00",
      "is_latest": false
    }
  ]
}
```

::: tip 排序规则
置顶公告（`pinned=true`）始终排在前面，其次按发布时间倒序。`is_latest` 字段直接反映 `pinned`。
:::

## 单条公告

```
GET /api/v1/announcement/{ann_id}
```

**认证：** 公开

**路径参数：**

| 参数 | 说明 |
| --- | --- |
| `ann_id` | 公告 ID，可传主键 `id` 或业务 `announce_id`（如 `ANN001`） |

**说明：** 先按主键 `id` 查，未命中再按 `announce_id` 查。**仅返回已发布的公告**，未发布（`status != "published"`）返回 404。

**响应示例：**

```json
{
  "status_code": 200,
  "data": {
    "id": "uuid-1",
    "title": "积分价格调整公告",
    "content": "自下月起，AI 对话积分消耗将由每次 5 积分调整为 3 积分。",
    "type": "pricing",
    "date": "2026-07-08T00:00:00",
    "is_latest": false
  }
}
```

**错误：**

| status_code | 说明 |
| --- | --- |
| 404 | 公告不存在（或未发布） |

## curl 示例

```bash
# 公告列表
curl http://localhost:8081/api/v1/announcement

# 单条公告
curl http://localhost:8081/api/v1/announcement/ANN001
```

## 相关文档

- [反馈 API](./feedback) — 用户反馈
- [工单 API](./ticket) — 用户工单
- [API 概览](./overview)
