# Makefile for OMA Lightspeed
# AI assistant for OMA Migration Planner

.PHONY: all generate run stop rm resume logs query build build-mcp test-eval help

EVAL_TAGS ?= smoke

all: help

generate: ## Generate configuration files from template.yaml
	@echo "Generating configuration files..."
	./scripts/generate.sh

run: ## Start the full OMA stack (planner + MCP + lightspeed)
	@echo "Starting OMA Lightspeed services..."
	./scripts/run.sh

stop: ## Stop services (preserves data)
	@echo "Stopping OMA Lightspeed services..."
	./scripts/stop.sh

rm: ## Remove services and volumes
	@echo "Removing OMA Lightspeed services..."
	./scripts/rm.sh

resume: ## Resume stopped services
	@echo "Resuming OMA Lightspeed services..."
	./scripts/resume.sh

logs: ## Follow logs (usage: make logs [SERVICE=lightspeed-stack])
	@./scripts/logs.sh $(SERVICE)

query: ## Query the OMA Lightspeed service
	@./scripts/query.sh

build: ## Build the OMA Lightspeed container image
	@echo "Building OMA Lightspeed image..."
	podman build -f Containerfile -t oma-lightspeed:latest .

build-mcp: ## Build the OMA Service MCP image from ../oma-service-mcp
	@echo "Building OMA Service MCP image..."
	@if [ ! -d "../oma-service-mcp" ]; then \
		echo "Error: ../oma-service-mcp not found."; \
		echo "Clone it: git clone https://github.com/kubev2v/oma-service-mcp.git ../oma-service-mcp"; \
		exit 1; \
	fi
	podman build -f ../oma-service-mcp/Containerfile -t localhost/oma-service-mcp:latest ../oma-service-mcp

test-eval: ## Run agent evaluation tests (requires: make run, GEMINI_API_KEY)
	@pip install -q git+https://github.com/lightspeed-core/lightspeed-evaluation.git pyyaml 2>/dev/null
	@if [ "$(EVAL_TAGS)" = "all" ]; then \
		cd test/evals && python eval.py; \
	else \
		cd test/evals && python eval.py --tags $(EVAL_TAGS); \
	fi

help: ## Show this help message
	@echo "OMA Lightspeed - AI Assistant for Migration Planner"
	@echo ""
	@echo "Quick Start:"
	@echo "  make generate    # Set up configuration (run first!)"
	@echo "  make run         # Start the full stack"
	@echo "  make query       # Test the API"
	@echo ""
	@echo "The full stack includes:"
	@echo "  PostgreSQL -> Migration Planner -> OMA Service MCP -> Lightspeed"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
