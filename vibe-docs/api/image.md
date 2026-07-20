# 图像理解 API

图像理解接口，接入视觉大模型（OpenAI 兼容协议，如通义千问 VL / GPT-4o）。传入图片 URL 与提示词，返回模型对图片的理解描述。

## 接口总览

| 方法 | 路径 | 认证 | 说明 |
| --- | --- | --- | --- |
| POST | `/image/understand` | 公开 | 图像理解（视觉 LLM） |

## 图像理解

```
POST /api/v1/image/understand
```

**认证：** 公开

**请求体：**

```json
{
  "image_url": "https://example.com/image.jpg",
  "prompt": "请描述这张图片"
}
```

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `image_url` | string | ✅ | 图片 URL |
| `prompt` | string | ❌ | 提示词，默认 `请描述这张图片` |

**响应示例（真实模型）：**

```json
{
  "status_code": 200,
  "data": {
    "content": "这是一张展示日落的海滩照片，天空呈现橙红色……",
    "usage": {
      "prompt_tokens": 50,
      "completion_tokens": 120,
      "total_tokens": 170
    },
    "model": "qwen-vl-plus"
  }
}
```

**响应示例（未配置 / 降级）：**

```json
{
  "status_code": 200,
  "data": {
    "content": "[演示] 已收到图片理解请求：请描述这张图片（图片：https://example.com/image.jpg）。请在 .env 配置 VL_API_KEY / VL_BASE_URL / VL_MODEL（或 multi_models.qwen_vl）后返回真实结果。",
    "usage": { "image": 1 },
    "fallback": true
  }
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `content` | string | 模型生成的描述文本 |
| `usage` | object | token 用量（或降级时的 `{image: 1}`） |
| `model` | string | 实际调用的模型名（仅真实响应） |
| `fallback` | bool | 是否为降级演示文案（仅降级响应） |

## 配置解析链

::: details 视觉模型配置解析
后端 `_resolve_vl_config()` 按以下优先级解析视觉模型配置：

1. **环境变量**：`VL_API_KEY` / `VL_BASE_URL` / `VL_MODEL`
2. **回退到对话模型变量**：`OPENAI_API_KEY` / `OPENAI_BASE_URL`
3. **YAML 配置**：`config.*.yaml` 的 `multi_models.qwen_vl`

返回三元组 `(api_key, base_url, model_name)`。
:::

::: details 已配置判定
`_vl_configured()` 判定模型是否「真正配置」：

- `api_key` 非空，且不在占位符集合 `{ "", "your-api-key", "sk-xxx", "changeme", "none", "null" }` 中
- `model_name` 非空

两项都满足才视为已配置，否则走降级。
:::

## 优雅降级

::: warning 未配置时降级而非报错
当视觉模型未配置（api_key 为空 / 占位符，或 model_name 为空）时，接口**不会返回 500**，而是返回演示文案 + `"fallback": true`。这样保证前端链路在未配置密钥时也可用。

生产部署时请在 `.env` 配置 `VL_API_KEY` / `VL_BASE_URL` / `VL_MODEL`，或在 `config/config.dev.yaml` 的 `multi_models.qwen_vl` 填入有效配置。
:::

## 默认模型

::: tip 默认视觉模型
对接通义千问 VL 系列时，推荐使用 `qwen-vl-plus`（在 YAML 的 `multi_models.qwen_vl.model_name` 配置）。接口本身不绑定具体模型，模型名完全由配置决定。
:::

## 调用失败

模型调用抛异常时返回 500：

```json
{
  "status_code": 500,
  "status_message": "图片理解调用失败: <错误详情>",
  "data": null
}
```

## curl 示例

```bash
# 图像理解
curl -X POST http://localhost:8081/api/v1/image/understand \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "https://example.com/sunset.jpg",
    "prompt": "这张图里有什么？"
  }'
```

## 相关文档

- [对话 API](./chat) — 文本对话（同源配置解析思路）
- [AI 能力 API](./ability) — 视觉类能力（图像生成 / OCR）
- [API 概览](./overview)
- [错误码](./error-codes)
