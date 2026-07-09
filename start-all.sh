#!/usr/bin/env bash
#
# Vibe 全栈一键启动脚本（中间件 + 前后端）
# --------------------------------------------------------------
# 启动内容：
#   中间件      PostgreSQL(5433) + Redis(6379)   [Docker]
#   后端        VibeAdmin :8080  /  VibeBase :8081   （后端段 808x）
#   前端        VibeAdmin :5173  /  Vibe-Mp-H5 :5174  /  VibeBase :5175  （前端段 517x）
#   前端        VibeAdmin :5173  /  Vibe-Mp-H5 :5174  /  VibeBase :5175
#
# 特性：
#   - 幂等：已监听的端口不会重复拉起；未启动的才启动。
#   - 启动完成后统一打印各服务端口与可访问地址，并做健康检查。
#
# 用法：
#   cd /Users/jwangkun/Coding/VibeCoding
#   ./start-all.sh
#
# 说明：
#   - 两个后端（VibeAdmin :8080 / VibeBase :8081）均连接同一个 PostgreSQL
#     实例（库 vibe / 用户 vibe / 端口 5433）与同一个 Redis(6379)。
#   - VibeBase 启动命令已用环境变量显式指定连接串，避免回退到默认 5432
#     而连不上；VibeAdmin 通过其目录下的 .env 读取（同样指向 5433）。
#   - Vibe-Mp-H5 按约定不在此脚本中启动。
# --------------------------------------------------------------

set -u

# 脚本所在目录 = 工作区根
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR"

# ---------- 环境 PATH（非交互 shell 下 node/docker/poetry 可能不在 PATH） ----------
# ServBay 的 Node（pnpm/npm 所在）
for d in /Applications/ServBay/package/node/*/bin; do
  [ -d "$d" ] && export PATH="$d:$PATH"
done
export PATH="/Applications/ServBay/bin:$PATH"
export PATH="/opt/miniconda3/bin:$PATH"
# 若 docker 以桌面版方式提供，确保可被发现
export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

LOG_DIR="/tmp/vibe-logs"
mkdir -p "$LOG_DIR"

# ---------- 颜色 ----------
if [ -t 1 ]; then
  C_GREEN=$'\033[0;32m'; C_YEL=$'\033[0;33m'; C_RED=$'\033[0;31m'; C_RST=$'\033[0m'
else
  C_GREEN=""; C_YEL=""; C_RED=""; C_RST=""
fi

# ---------- 工具函数 ----------
port_up() {
  lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
}

wait_for() {
  local port="$1" name="$2" i
  for i in $(seq 1 60); do
    if port_up "$port"; then
      echo "  ${C_GREEN}✅ $name 已就绪 (:$port)${C_RST}"
      return 0
    fi
    sleep 1
  done
  echo "  ${C_RED}⚠️  $name 60s 内未就绪 (:$port)，请查看日志：$LOG_DIR${C_RST}"
  return 1
}

# ensure_service <port> <名称> <日志文件> <启动命令>
ensure_service() {
  local port="$1" name="$2" logfile="$3" cmd="$4"
  if port_up "$port"; then
    echo "• $name 已在运行 (:$port)，跳过"
    return 0
  fi
  echo "• 启动 $name ..."
  nohup bash -c "$cmd" > "$logfile" 2>&1 &
  disown 2>/dev/null || true
}

# 选出能 import uvicorn 的 python（VibeAdmin 后端用）
pick_admin_python() {
  local cand
  for cand in python3 /Library/Frameworks/Python.framework/Versions/3.12/Resources/Python.app/Contents/MacOS/Python; do
    if command -v "$cand" >/dev/null 2>&1 && "$cand" -c "import uvicorn" >/dev/null 2>&1; then
      echo "$cand"
      return 0
    fi
  done
  echo "python3"
}

# ---------- 1) 中间件 ----------
echo
echo "========== [1/4] 中间件 (PostgreSQL + Redis) =========="
# Postgres(5433)：优先复用已有容器 vibe-pg；否则用本仓 compose
ensure_service 5433 "PostgreSQL(中间件)" "$LOG_DIR/postgres.log" \
  "docker start vibe-pg >/dev/null 2>&1 || docker compose -f '$ROOT/docker-compose.middleware.yml' up -d postgres"
# Redis(6379)
ensure_service 6379 "Redis(中间件)" "$LOG_DIR/redis.log" \
  "docker start vibe-admin-redis-1 >/dev/null 2>&1 || docker start vibe-redis >/dev/null 2>&1 || docker compose -f '$ROOT/docker-compose.middleware.yml' up -d redis"

# ---------- 2) 后端 ----------
echo
echo "========== [2/4] 后端 API =========="
ADMIN_PY="$(pick_admin_python)"
ensure_service 8080 "VibeAdmin 后端" "$LOG_DIR/vibe-admin-be.log" \
  "cd '$ROOT/VibeAdmin/vibe-admin' && '$ADMIN_PY' -m uvicorn app.main:app --host 127.0.0.1 --port 8080"

ensure_service 8081 "VibeBase 后端" "$LOG_DIR/vibe-base-be.log" \
  "cd '$ROOT/VibeBase/vibe-base' && DATABASE_URL=postgresql+asyncpg://vibe:vibe@localhost:5433/vibe REDIS_URL=redis://localhost:6379 poetry run uvicorn main:app --host 0.0.0.0 --port 8081 --reload"

# ---------- 3) 前端 ----------
echo
echo "========== [3/4] 前端 =========="
ensure_service 5173 "VibeAdmin 前端" "$LOG_DIR/vibe-admin-fe.log" \
  "cd '$ROOT/VibeAdmin/vibe-admin-web' && pnpm dev"
ensure_service 5174 "Vibe-Mp-H5 前端" "$LOG_DIR/vibe-mp-h5-fe.log" \
  "cd '$ROOT/Vibe-Mp-H5' && UNI_PLATFORM=h5 sh node_modules/.bin/uni"
ensure_service 5175 "VibeBase 前端" "$LOG_DIR/vibe-base-fe.log" \
  "cd '$ROOT/VibeBase/vibe-base-web' && npm run dev"

# ---------- 4) 等待 + 健康检查 + 打印 ----------
echo
echo "========== [4/4] 等待服务就绪 =========="
wait_for 5433 "PostgreSQL(中间件)"
wait_for 6379 "Redis(中间件)"
wait_for 8080 "VibeAdmin 后端"
wait_for 8081 "VibeBase 后端"
wait_for 5173 "VibeAdmin 前端"
wait_for 5174 "Vibe-Mp-H5 前端"
wait_for 5175 "VibeBase 前端"

echo
echo "============================================================"
echo "  Vibe 全栈服务访问地址"
echo "============================================================"
printf "%-22s %-8s %s\n" "服务" "端口" "地址"
printf "%-22s %-8s %s\n" "VibeAdmin 前端" "5173" "http://localhost:5173/"
printf "%-22s %-8s %s\n" "Vibe-Mp-H5 前端" "5174" "http://localhost:5174/"
printf "%-22s %-8s %s\n" "VibeBase 前端"  "5175" "http://localhost:5175/"
printf "%-22s %-8s %s\n" "VibeAdmin 后端" "8080" "http://localhost:8080/   (API 文档: /docs)"
printf "%-22s %-8s %s\n" "VibeBase 后端"  "8081" "http://localhost:8081/   (API 文档: /docs)"
printf "%-22s %-8s %s\n" "PostgreSQL"     "5433" "localhost:5433   库=vibe 用户=vibe 密码=vibe"
printf "%-22s %-8s %s\n" "Redis"          "6379" "localhost:6379"
echo "------------------------------------------------------------"

# 简易健康检查
probe() {
  local url="$1" label="$2"
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$url" 2>/dev/null)"
  if [ "$code" = "200" ] || [ "$code" = "301" ] || [ "$code" = "308" ]; then
    echo "  ${C_GREEN}✅ $label 可访问 (HTTP $code)${C_RST}"
  else
    echo "  ${C_RED}❌ $label 暂不可访问 (HTTP ${code:-无响应})${C_RST}"
  fi
}
echo "健康检查:"
probe "http://localhost:5173/"       "VibeAdmin 前端"
probe "http://localhost:5174/"       "Vibe-Mp-H5 前端"
probe "http://localhost:5175/"       "VibeBase 前端"
probe "http://localhost:8080/health" "VibeAdmin 后端"
probe "http://localhost:8081/health" "VibeBase 后端"
echo "------------------------------------------------------------"
echo "说明: 两个后端均使用 PostgreSQL(5433)+Redis(6379)，共享同一数据库（库 vibe）。"
echo "日志目录: $LOG_DIR"
echo "============================================================"
