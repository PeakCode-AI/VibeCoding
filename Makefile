# Vibe monorepo — 常用脚手架命令
# 用法: make help | make check | make smoke | make sync-common

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
VIBE_BASE := $(ROOT)/VibeBase/vibe-base
SCRIPTS := $(ROOT)/scripts

.PHONY: help check sync-common smoke unit-safe health-hint status

help:
	@echo "Vibe monorepo targets:"
	@echo "  make sync-common  - 同步 vibe_common Base → Admin 并校验"
	@echo "  make check        - vibe_common 一致性检查"
	@echo "  make smoke        - VibeBase 冒烟测试 (需 PG/Redis + .venv)"
	@echo "  make unit-safe    - /user/info 白名单单测 (无 DB)"
	@echo "  make status       - 打印 docs/STATUS.md 头"

check:
	@bash "$(SCRIPTS)/check_vibe_common_sync.sh"

sync-common:
	@rsync -a --exclude='__pycache__' \
		"$(VIBE_BASE)/vibe_common/" \
		"$(ROOT)/VibeAdmin/vibe-admin/vibe_common/"
	@bash "$(SCRIPTS)/check_vibe_common_sync.sh"

smoke:
	@cd "$(VIBE_BASE)" && .venv/bin/python tests/smoke_test.py

unit-safe:
	@cd "$(VIBE_BASE)" && .venv/bin/python tests/test_user_info_safe.py

health-hint:
	@echo "VibeBase:  curl -s http://127.0.0.1:8081/health"
	@echo "VibeAdmin: curl -s http://127.0.0.1:8080/health"

status:
	@head -30 "$(ROOT)/docs/STATUS.md"
