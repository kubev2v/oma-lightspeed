# Makefile for OMA Lightspeed
# AI assistant for OMA Migration Planner

.PHONY: all generate run stop rm resume logs query build help

all: help

generate: ## Generate configuration files from template.yaml
	@echo "Generating configuration files..."
	./scripts/generate.sh

run: ## Start the OMA Lightspeed services
	@echo "Starting OMA Lightspeed services..."
	./scripts/run.sh

stop: ## Stop the OMA Lightspeed services
	@echo "Stopping OMA Lightspeed services..."
	./scripts/stop.sh

rm: ## Remove/cleanup the OMA Lightspeed services
	@echo "Removing OMA Lightspeed services..."
	./scripts/rm.sh

resume: ## Resume stopped OMA Lightspeed services
	@echo "Resuming OMA Lightspeed services..."
	./scripts/resume.sh

logs: ## Show logs for the OMA Lightspeed services
	@echo "Showing logs..."
	./scripts/logs.sh

query: ## Query the OMA Lightspeed service
	@echo "Querying OMA Lightspeed..."
	./scripts/query.sh

build: ## Build the OMA Lightspeed container image
	@echo "Building OMA Lightspeed image..."
	podman build -f Containerfile -t oma-lightspeed:latest .

help: ## Show this help message
	@echo "OMA Lightspeed - AI Assistant for Migration Planner"
	@echo ""
	@echo "Quick Start:"
	@echo "  make generate   # Set up configuration (run first!)"
	@echo "  make run        # Start the services"
	@echo "  make query      # Test the API"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
