#!/bin/bash
# Start OMA Lightspeed services using podman play kube

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

# Kill existing pod if running
if podman pod exists oma-lightspeed-pod &>/dev/null; then
    echo "Found existing oma-lightspeed-pod. Stopping and removing..."
    podman pod kill oma-lightspeed-pod 2>/dev/null || true
    podman pod rm oma-lightspeed-pod 2>/dev/null || true
fi

# Create named volume for persistent SQLite storage (if not exists)
if ! podman volume exists oma-lightspeed-data &>/dev/null; then
    echo "Creating persistent volume for conversation data..."
    podman volume create oma-lightspeed-data
fi

# Source environment variables
set -a
source "$PROJECT_ROOT/.env"
set +a

# Set default values for all pod variables (envsubst doesn't handle ${VAR:-default} syntax)
export LIGHTSPEED_STACK_IMAGE="${LIGHTSPEED_STACK_IMAGE_OVERRIDE:-registry.redhat.io/lightspeed-core/lightspeed-stack-rhel9:0.4.1}"
export OMA_MCP_IMAGE="${OMA_MCP_IMAGE:-localhost/oma-service-mcp:latest}"
export MIGRATION_PLANNER_URL="${MIGRATION_PLANNER_URL:-http://host.containers.internal:3443}"
export AUTH_TYPE="${AUTH_TYPE:-none}"
export CONFIG_PATH="$PROJECT_ROOT/config"

# Change to project root for relative paths in pod yaml
cd "$PROJECT_ROOT"

# Start the pod
echo "Starting OMA Lightspeed pod..."
podman play kube <(envsubst < "$PROJECT_ROOT/oma-pod.yaml")

echo ""
echo "OMA Lightspeed is starting!"
echo ""
echo "Service URL: http://localhost:8080"
echo "Health check: http://localhost:8080/liveness"
echo ""
echo "Run 'make logs' to follow logs"
echo "Run 'make query' to test the API"
echo ""

# Follow logs
"$SCRIPT_DIR/logs.sh"
