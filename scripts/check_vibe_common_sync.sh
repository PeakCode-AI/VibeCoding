#!/usr/bin/env bash
#
# 检查两份 vendored 的 vibe_common 是否同步一致。
# --------------------------------------------------------------
# vibe_common 分别 vendored 在：
#   VibeBase/vibe-base/vibe_common
#   VibeAdmin/vibe-admin/vibe_common
# 它们指向同一个 PostgreSQL 数据库，表结构必须保持一致。
# 本脚本 diff 两份目录（排除 __pycache__），不一致则以非零码退出。
#
# 用法：
#   ./scripts/check_vibe_common_sync.sh
# --------------------------------------------------------------

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BASE_DIR="$ROOT/VibeBase/vibe-base/vibe_common"
ADMIN_DIR="$ROOT/VibeAdmin/vibe-admin/vibe_common"

if [ ! -d "$BASE_DIR" ]; then
  echo "❌ 未找到 $BASE_DIR"
  exit 1
fi
if [ ! -d "$ADMIN_DIR" ]; then
  echo "❌ 未找到 $ADMIN_DIR"
  exit 1
fi

# diff 递归、简要输出，忽略 __pycache__ 与 .pyc
if diff_output=$(diff -rq \
    --exclude="__pycache__" \
    --exclude="*.pyc" \
    "$BASE_DIR" "$ADMIN_DIR"); then
  echo "✅ 两份 vibe_common 完全一致。"
  exit 0
else
  echo "❌ 两份 vibe_common 不一致，请同步后重试："
  echo "$diff_output"
  echo
  echo "提示：保持单一事实来源，修改任一份后用以下命令同步："
  echo "  rsync -av --exclude='__pycache__' '$BASE_DIR/' '$ADMIN_DIR/'"
  exit 1
fi
