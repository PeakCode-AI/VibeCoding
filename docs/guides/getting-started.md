# 快速开始指南

分别说明各子项目的本地/源码运行方式。各项目均为独立工程，互不依赖统一构建工具。

## 1. VibeAdmin（B 端后台）

### 方式 A：本地源码运行
```bash
# 后端
cd VibeAdmin/vibe-admin
pip install -r requirements.txt
cp .env.example .env
python setup_database.py      # 建表 + 种子管理员
python run_server.py          # http://localhost:8080

# 前端（另开终端）
cd VibeAdmin/vibe-admin-web
corepack enable && pnpm install
cp .env.example .env
pnpm dev                      # http://localhost:5173
```
默认管理员：`admin@example.com` / `admin123`（首次登录请修改密码）。

### 方式 B：Docker 一键启动
```bash
cd VibeAdmin
docker compose up -d --build
```
- 前端(Nginx)：http://localhost
- 后端 API：http://localhost:8080

常用：`make docker-up` / `make docker-down` / `make docker-logs`

## 2. VibeBase（C 端对话产品）

### Docker Compose 一键启动
```bash
cd VibeBase
docker-compose up -d
```
- 前端：http://localhost
- 后端 API：http://localhost:8081

### 单独开发
```bash
# 前端
cd VibeBase/vibe-base-web
npm install
npm run dev            # 开发服务器
npm run build:prod     # 生产构建

# 后端
cd VibeBase/vibe-base
pip install -r requirements.txt
python main.py
```
也可使用 `bash start_dev.sh` 一键启动。

## 3. VibeApp（Flutter App）

环境要求：Flutter ≥ 3.7.0、Dart ≥ 3.0.0。
```bash
cd VibeApp
flutter pub get
flutter run
```
目录：`lib/app/`（入口、路由）、`lib/core/`（主题/常量/工具）、`lib/features/`（功能模块）。

## 4. Vibe-Mp-H5（小程序 + H5）

基于 `unibest`（uniapp 框架），无需 HBuilderX，VSCode 开发即可。

环境要求：node ≥ 18、pnpm ≥ 7.30。

```bash
cd Vibe-Mp-H5
pnpm install
pnpm dev:h5              # 运行 H5 → http://localhost:5174
pnpm dev:mp              # 运行微信小程序（需微信开发者工具导入 dist/dev/mp-weixin）
pnpm build:h5           # H5 生产构建
pnpm build:mp            # 微信小程序生产构建
```

## 5. 依赖与端口速查

| 项目 | 启动命令 | 前端端口 | 后端端口 |
| --- | --- | --- | --- |
| VibeAdmin | `docker compose up` / 源码运行 | 5173(开发) / 80 | 8080 |
| VibeBase | `docker-compose up` / `start_dev.sh` | 80 / 5175(开发) | 8081 |
| VibeApp | `flutter run` | — | — |
| Vibe-Mp-H5 | `pnpm dev:h5` / `pnpm dev:mp` | 5174(H5) | — |
