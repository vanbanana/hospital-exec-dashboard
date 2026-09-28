# EDSS 薄壳 Makefile——常用命令统一入口,不藏逻辑
# compose 变量全部 ${VAR:-default} 兜底:.env 存在才追加 --env-file,缺席时删该段也能跑

COMPOSE := docker compose -f deploy/docker-compose.yml
ENV_FILE := $(if $(wildcard .env),--env-file .env,)

.DEFAULT_GOAL := help

.PHONY: help dev dev-api backend build vet test migrate migrate-status baseline seed up down logs ci ci-mech

help: ## 列出全部目标
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  %-16s %s\n", $$1, $$2}'

# ---- 前端 ----
dev: ## vite dev,mock 数据轨(:5173)
	npm run dev

dev-api: ## vite dev 真链路:VITE_USE_MOCK=0 经 proxy 打 :8080
	VITE_USE_MOCK=0 npm run dev

build: ## 前端构建(vue-tsc -b && vite build → dist/)
	npm run build

# ---- 后端 ----
backend: ## Go API 服务(:8080)
	cd backend && go run ./cmd/server

vet: ## go vet ./...
	cd backend && go vet ./...

test: ## go test ./...
	cd backend && go test ./...

# ---- CI 门禁(与 .github/workflows/ci.yml 同一串,CI=权威门禁)----
ci: ## CI 门禁本地复跑:前端 vue-tsc/test:unit/build + 后端 vet/build/test(-race) + 机械自查
	npx vue-tsc -b
	npm run test:unit
	npm run build
	cd backend && go vet ./... && go build ./... && go test -count=1 -race ./...
	@$(MAKE) --no-print-directory ci-mech

ci-mech: ## 机械自查:time.Now/as any/@ts-ignore 豁免核对(清单同 acceptance.md §1)
	@if grep -rn "time.Now\|as any\|@ts-ignore" --include="*.ts" --include="*.go" src/ backend/ \
	  | grep -vE '^backend/(internal/envelope/envelope|internal/middleware/requestlog|internal/handler/write_alert|cmd/migrate/main|cmd/loadbench/main|internal/clock/clock)\.go:[0-9]+:.*time\.Now'; \
	then echo "FAIL: 机械自查命中非豁免项(见上),豁免清单见 docs/acceptance.md §1"; exit 1; \
	else echo "PASS: 命中项全部落在豁免清单内(或无命中)"; fi

# ---- 迁移/种子(旗标语义见 backend/README.md)----
migrate: ## apply 未应用迁移
	cd backend && go run ./cmd/migrate

migrate-status: ## 文件名×applied/pending 对照表
	cd backend && go run ./cmd/migrate -status

baseline: ## 既有库收养:全部迁移标记已应用(不执行 SQL)
	cd backend && go run ./cmd/migrate -baseline

seed: ## apply 后接跑 seed/ 全部文件(幂等)
	cd backend && go run ./cmd/migrate -seed

# ---- compose(prod 三服务)----
up: ## compose 构建并后台起 web+backend+db
	$(COMPOSE) $(ENV_FILE) up -d --build

down: ## compose 停服(卷保留)
	$(COMPOSE) $(ENV_FILE) down

logs: ## compose 跟随日志
	$(COMPOSE) $(ENV_FILE) logs -f
