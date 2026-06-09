#!/bin/bash
# Start OMA Lightspeed services using podman-compose

set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

# Check for required config files
if [[ ! -f "$PROJECT_ROOT/config/lightspeed-stack.yaml" ]]; then
    echo "Error: Configuration files not found."
    echo "Please run 'make generate' first."
    exit 1
fi

# Check for .env file
if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
    echo "Error: .env file not found."
    echo "Please run 'make generate' first."
    exit 1
fi

# Check for podman-compose
if ! command -v podman-compose &> /dev/null; then
    echo "Error: podman-compose is not installed."
    echo "Install it: pip install podman-compose"
    exit 1
fi

# Check if oma-service-mcp image exists locally
OMA_MCP_IMAGE="${OMA_MCP_IMAGE:-localhost/oma-service-mcp:latest}"
if ! podman image exists "$OMA_MCP_IMAGE" &>/dev/null; then
    echo "Warning: MCP server image '$OMA_MCP_IMAGE' not found locally."
    echo ""
    if [[ -d "$PROJECT_ROOT/../oma-service-mcp" ]]; then
        echo "Found oma-service-mcp repo at ../oma-service-mcp"
        read -rp "Build it now? [Y/n]: " build_mcp
        if [[ "${build_mcp:-Y}" =~ ^[Yy]$ ]]; then
            echo "Building oma-service-mcp..."
            podman build -f "$PROJECT_ROOT/../oma-service-mcp/Containerfile" \
                -t localhost/oma-service-mcp:latest \
                "$PROJECT_ROOT/../oma-service-mcp"
        else
            echo "Skipping. Set OMA_MCP_IMAGE in .env to use a different image."
            exit 1
        fi
    else
        echo "To build it, clone and build the repo:"
        echo "  git clone https://github.com/kubev2v/oma-service-mcp.git ../oma-service-mcp"
        echo "  make build-mcp"
        echo ""
        echo "Or set OMA_MCP_IMAGE in .env to use a pre-built image."
        exit 1
    fi
fi

cd "$PROJECT_ROOT"

echo "Starting OMA Lightspeed stack..."
echo "  PostgreSQL -> Migration Planner -> OMA Service MCP -> Lightspeed Stack"
echo ""

podman-compose up -d

# Wait for lightspeed-stack to become healthy
echo ""
echo "Waiting for services to start..."
HEALTH_URL="http://localhost:${LIGHTSPEED_PORT:-8080}/liveness"
HEALTH_TIMEOUT=120
HEALTH_INTERVAL=3
HEALTH_ELAPSED=0

while [ "$HEALTH_ELAPSED" -lt "$HEALTH_TIMEOUT" ]; do
    if curl -sf "$HEALTH_URL" >/dev/null 2>&1; then
        echo ""
        echo "All services are healthy!"
        break
    fi
    echo "  waiting... (${HEALTH_ELAPSED}s/${HEALTH_TIMEOUT}s)"
    sleep "$HEALTH_INTERVAL"
    HEALTH_ELAPSED=$((HEALTH_ELAPSED + HEALTH_INTERVAL))
done

if [ "$HEALTH_ELAPSED" -ge "$HEALTH_TIMEOUT" ]; then
    echo ""
    echo "WARNING: Services did not become healthy within ${HEALTH_TIMEOUT}s"
    echo "Check logs with: make logs"
fi

echo ""
echo "OMA Lightspeed is running!"
echo ""
echo "  Lightspeed API:     http://localhost:${LIGHTSPEED_PORT:-8080}"
echo "  Health check:       $HEALTH_URL"
echo ""
echo "  make logs    - follow logs"
echo "  make query   - test the API"
echo "  make stop    - stop services"
echo ""
