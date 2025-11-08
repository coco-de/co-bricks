.PHONY: sync-monorepo sync-app help

help:
	@echo "Co-Bricks 개발용 명령어"
	@echo ""
	@echo "사용 가능한 명령:"
	@echo "  make sync-monorepo    - Monorepo brick 동기화"
	@echo "  make sync-app         - App brick 동기화"
	@echo ""
	@echo "예시:"
	@echo "  make sync-monorepo PROJECT=good_teacher"

sync-monorepo:
	@if [ -z "$(PROJECT)" ]; then \
		echo "❌ PROJECT 변수가 필요합니다."; \
		echo "예: make sync-monorepo PROJECT=good_teacher"; \
		exit 1; \
	fi
	@echo "🚀 Syncing monorepo brick for project: $(PROJECT)"
	dart run bin/co_bricks.dart sync --type monorepo --project-dir ../$(PROJECT)

sync-app:
	@if [ -z "$(PROJECT)" ]; then \
		echo "❌ PROJECT 변수가 필요합니다."; \
		echo "예: make sync-app PROJECT=good_teacher"; \
		exit 1; \
	fi
	@echo "🚀 Syncing app brick for project: $(PROJECT)"
	dart run bin/co_bricks.dart sync --type app --project-dir ../$(PROJECT)
