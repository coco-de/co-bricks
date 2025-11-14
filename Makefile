.PHONY: sync-monorepo sync-app create-blueprint help

help:
	@echo "Co-Bricks 개발용 명령어"
	@echo ""
	@echo "사용 가능한 명령:"
	@echo "  make sync-monorepo    - Monorepo brick 동기화"
	@echo "  make sync-app         - App brick 동기화"
	@echo "  make create-blueprint - Blueprint 프로젝트 생성 (serverpod + console)"
	@echo ""
	@echo "예시:"
	@echo "  make sync-monorepo PROJECT=good_teacher"
	@echo "  make create-blueprint"

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

create-blueprint:
	@echo "🎨 Creating Blueprint project (serverpod + console)..."
	@rm -rf ../blueprint
	@dart run bin/co_bricks.dart create \
		--type monorepo \
		--no-interactive \
		--auto-start \
		--name blueprint \
		--description "Blueprint - Cocode's service blueprint implementation" \
		--organization Cocode \
		--tld im \
		--org-tld im \
		--github-org coco-de \
		--github-repo blueprint \
		--github-visibility private \
		--backend serverpod \
		--enable-admin true \
		--admin-email dev@cocode.im \
		--apple-developer-id dev@cocode.com \
		--itc-team-id 127798085 \
		--team-id DNNK8RH9GY \
		--cert-cn "Cocode Inc." \
		--cert-ou Production \
		--cert-o "Cocode Inc." \
		--cert-l Seoul \
		--cert-st Mapo \
		--cert-c KR \
		--output-dir ..
	@echo "✅ Blueprint project created at ../blueprint"
