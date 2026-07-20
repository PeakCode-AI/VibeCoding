# 对象存储配置

VibeBase 使用 S3 协议兼容的对象存储（推荐 MinIO）来托管用户上传的文件，目前主要用于**头像上传**。本页讲解环境变量、MinIO 本地搭建、头像上传规则以及排障。

源码位置：`vibe_common/core/config.py`（配置）、`settings.py`（`use_oss` 开关）、头像相关接口在 `api/v1/` 下。

## S3 环境变量

在 `vibe-base/.env` 中配置：

```bash
# MinIO / AWS S3 / 任意兼容服务
S3_ENDPOINT=http://localhost:9000
S3_ACCESS_KEY=minioadmin
S3_SECRET_KEY=minioadmin
S3_REGION=us-east-1
S3_BUCKET=vibe-storage
S3_PUBLIC_URL=
S3_AVATAR_PATH=avatars
```

### 字段说明

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `S3_ENDPOINT` | `http://localhost:9000` | S3 兼容服务端点（不含 bucket） |
| `S3_ACCESS_KEY` | `minioadmin` | Access Key（MinIO 默认账号） |
| `S3_SECRET_KEY` | `minioadmin` | Secret Key（MinIO 默认密码） |
| `S3_REGION` | `us-east-1` | 区域；MinIO 可填任意值 |
| `S3_BUCKET` | `vibe-storage` | Bucket 名称 |
| `S3_PUBLIC_URL` | （空） | 文件对外访问的前缀；为空时回退到 `S3_ENDPOINT` |
| `S3_AVATAR_PATH` | `avatars` | 头像在 Bucket 内的目录前缀 |

::: tip S3_PUBLIC_URL 的作用
返回给前端的文件 URL 由 `S3_PUBLIC_URL` + 路径拼接。如果 MinIO 只在内网、需要通过 CDN 或反向代理对外暴露，就把它设为对外域名，例如 `https://cdn.example.com`。
:::

## use_oss 开关

`settings.py` 中维护一个 `use_oss` 标志，用于在运行时判断是否启用对象存储。当它关闭或 `boto3` 不可用时，相关上传接口会返回 503，而不是抛 500。

```python
# settings.py
use_oss: bool = ...   # 取决于配置/依赖是否就绪
```

::: warning use_oss 关闭时
头像等上传接口直接返回 503（服务不可用），不会去尝试连接 S3。这是优雅降级——不配置存储也能跑通后端，只是无法上传文件。
:::

## MinIO 快速开始（Docker）

推荐用 Docker 在本地起一个 MinIO 作为开发存储：

```bash
mkdir -p ~/minio/data

docker run -d \
  --name minio \
  -p 9000:9000 \
  -p 9001:9001 \
  -e "MINIO_ROOT_USER=minioadmin" \
  -e "MINIO_ROOT_PASSWORD=minioadmin" \
  -v ~/minio/data:/data \
  minio/minio server /data --console-address ":9001"
```

| 端口 | 用途 |
| --- | --- |
| `9000` | S3 API 端点（对应 `S3_ENDPOINT`） |
| `9001` | Web 控制台 |

启动后：

1. 浏览器打开 `http://localhost:9001`，用 `minioadmin / minioadmin` 登录。
2. 手动创建名为 `vibe-storage` 的 Bucket（对应 `S3_BUCKET`）。
3. 把该 Bucket 的访问策略设为 `public`（或仅对 `avatars/*` 放开读），否则前端拿到的头像 URL 打不开。

::: details 用 mc 命令行创建并公开 Bucket
```bash
# 拉一个 mc 客户端
docker run --rm -it --entrypoint=/bin/sh minio/mc

# 在容器内：
mc alias set local http://host.docker.internal:9000 minioadmin minioadmin
mc mb local/vibe-storage
mc anonymous set download local/vibe-storage
```
:::

::: tip 为什么需要公开读
头像 URL 会直接拼到前端 `<img src>` 上，浏览器要能匿名 GET。如果 Bucket 是私有的，要么改用预签名 URL，要么配置 CDN / 反向代理鉴权转发。开发环境直接公开最简单。
:::

## 头像上传接口

VibeBase 提供两个等价的头像上传端点（功能一致，路径不同，便于不同前端复用）：

| 路径 | 说明 |
| --- | --- |
| `POST /api/v1/settings/avatar` | 设置页头像上传 |
| `POST /api/v1/user/avatar` | 用户中心头像上传 |

### 上传规则

| 规则 | 值 |
| --- | --- |
| 允许类型 | **仅图片**（`image/*`） |
| 大小上限 | **≤ 5 MB** |
| 存储 Key | `avatars/{user_id}.{ext}` |
| 返回 | 头像可访问 URL |

::: warning Key 按用户 ID 命名
文件名形如 `avatars/u_12345.png`。**同一用户再次上传会覆盖旧头像**（Key 相同），不会产生历史文件堆积，符合头像场景。
:::

### 实现细节

```python
# 伪代码示意
def upload_avatar(file, user):
    # 1. 校验：必须是图片且 <= 5MB
    if not file.content_type.startswith("image/"):
        raise HTTPException(400, "仅支持图片")
    if file.size > 5 * 1024 * 1024:
        raise HTTPException(400, "图片不能超过 5MB")

    # 2. 懒加载 boto3（避免未安装时拖累启动）
    try:
        import boto3
    except ImportError:
        raise HTTPException(503, "对象存储不可用")

    # 3. 上传到 S3
    ext = file.filename.rsplit(".", 1)[-1]
    key = f"{S3_AVATAR_PATH}/{user.user_id}.{ext}"
    s3.put_object(Bucket=S3_BUCKET, Key=key, Body=..., ContentType=file.content_type)

    # 4. 返回可访问 URL
    return f"{S3_PUBLIC_URL or S3_ENDPOINT}/{S3_BUCKET}/{key}"
```

### 懒加载 boto3

`boto3`（AWS S3 SDK）是**按需 import** 的，而不是模块顶部导入：

- 未安装 `boto3` → 不影响后端启动；调用上传接口时才 `ImportError` → 返回 503。
- 这样即使不打算用对象存储，也能跑通整个项目。

### 503 的两种触发条件

| 情况 | 响应 |
| --- | --- |
| 未安装 `boto3` | 503 服务不可用 |
| `use_oss` 关闭 / 配置缺失 | 503 服务不可用 |

::: info 503 不是 500
503 属于「服务暂时不可用」，语义上是「这个功能没开」，前端可以提示用户「头像功能未启用」，而不是当成系统崩溃。
:::

## 配置 MinIO 用于开发（完整步骤）

1. **启动 MinIO**（见上文 Docker 命令）。
2. **创建 Bucket** `vibe-storage` 并设为公开读。
3. **填写 `.env`**：
   ```bash
   S3_ENDPOINT=http://localhost:9000
   S3_ACCESS_KEY=minioadmin
   S3_SECRET_KEY=minioadmin
   S3_BUCKET=vibe-storage
   S3_PUBLIC_URL=http://localhost:9000
   S3_AVATAR_PATH=avatars
   ```
4. **安装 boto3**：`pip install boto3`（已在 `requirements.txt` 中）。
5. **重启后端**，登录后到「设置」页上传一张图片测试。

::: tip S3_PUBLIC_URL 在本机的取值
开发时直接填 `http://localhost:9000`。前端和后端在同一台机器时浏览器能直接访问。若前端在另一台机器，需填 MinIO 所在机器的可访问 IP。
:::

## 排障

| 症状 | 排查 |
| --- | --- |
| 上传返回 503 | 未安装 `boto3`，或 `use_oss` 未开启 / 配置缺失 |
| 上传返回 400 | 文件不是图片，或超过 5MB |
| 上传成功但图片打不开 | Bucket 未公开读；检查 MinIO 控制台匿名策略 |
| `Connection refused` 到 9000 | MinIO 未启动；`docker ps` 确认 |
| 返回的 URL 是内网地址 | `S3_PUBLIC_URL` 未配置或填错；改成对外可达地址 |
| 头像不更新（仍是旧图） | 浏览器/CDN 缓存；Key 相同会覆盖，但 URL 不变，加 `?v=时间戳` 绕过缓存 |
| 生产环境用阿里云 OSS | `S3_ENDPOINT` 填 OSS 的内网/外网域名，Key/Secret 用 RAM 子账号，Region 填实际 Region |

::: details 对接阿里云 OSS 示例
```bash
S3_ENDPOINT=https://oss-cn-hangzhou.aliyuncs.com
S3_ACCESS_KEY=LTAI5xxx
S3_SECRET_KEY=xxx
S3_REGION=oss-cn-hangzhou
S3_BUCKET=my-vibe-bucket
S3_PUBLIC_URL=https://my-vibe-bucket.oss-cn-hangzhou.aliyuncs.com
S3_AVATAR_PATH=avatars
```
OSS 兼容 S3 协议，无需改动代码。
:::

## 相关文档

- [后端配置](./backend) — 配置体系总览
- [JWT 与认证密钥](./jwt) — 上传接口需要 Bearer Token
- [前端配置](./frontend) — 前端如何调用上传接口
