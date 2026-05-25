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

if [[ -z "${GEMINI_API_KEY:-}" ]]; then
    echo "Error: GEMINI_API_KEY is not set in .env" >&2
    exit 1
fi

# Set default values for all pod variables (envsubst doesn't handle ${VAR:-default} syntax)
export LIGHTSPEED_STACK_IMAGE="${LIGHTSPEED_STACK_IMAGE_OVERRIDE:-quay.io/lightspeed-core/lightspeed-stack:0.5.1}"
export OMA_MCP_IMAGE="${OMA_MCP_IMAGE:-localhost/oma-service-mcp:latest}"
export MIGRATION_PLANNER_URL="${MIGRATION_PLANNER_URL:-http://host.containers.internal:3443}"
export AUTH_TYPE="${AUTH_TYPE:-none}"
export CONFIG_PATH="$PROJECT_ROOT/config"
# Vertex AI settings (only effective when vertex-credentials.json is a real SA key)
export VERTEXAI_PROJECT="${VERTEXAI_PROJECT:-}"
export VERTEXAI_LOCATION="${VERTEXAI_LOCATION:-us-central1}"

# Change to project root for relative paths in pod yaml
cd "$PROJECT_ROOT"

# Create Kubernetes secret for API keys (podman play kube supports secrets)
echo "Creating secret for API keys..."
podman play kube --replace <(envsubst < "$PROJECT_ROOT/oma-secret.yaml")

# Start the pod
echo "Starting OMA Lightspeed pod..."
podman play kube <(envsubst < "$PROJECT_ROOT/oma-pod.yaml")

# Wait for services to become healthy
echo "Waiting for services to start..."
HEALTH_URL="http://localhost:8081/liveness"
HEALTH_TIMEOUT=60
HEALTH_INTERVAL=2
HEALTH_ELAPSED=0

while [ "$HEALTH_ELAPSED" -lt "$HEALTH_TIMEOUT" ]; do
    if curl -sf "$HEALTH_URL" >/dev/null 2>&1; then
        echo "Services are healthy!"
        break
    fi
    echo "  waiting... (${HEALTH_ELAPSED}s/${HEALTH_TIMEOUT}s)"
    sleep "$HEALTH_INTERVAL"
    HEALTH_ELAPSED=$((HEALTH_ELAPSED + HEALTH_INTERVAL))
done

if [ "$HEALTH_ELAPSED" -ge "$HEALTH_TIMEOUT" ]; then
    echo "WARNING: Services did not become healthy within ${HEALTH_TIMEOUT}s"
    echo "Check logs with: make logs"
fi

echo ""
echo "OMA Lightspeed is running!"
echo ""
echo "Service URL: http://localhost:8081"
echo "Health check: $HEALTH_URL"
echo ""
echo "Run 'make logs' to follow logs"
echo "Run 'make query' to test the API"
echo ""

# Follow logs
"$SCRIPT_DIR/logs.sh"
