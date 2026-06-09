#!/bin/bash
# Follow logs for OMA Lightspeed services

set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

cd "$PROJECT_ROOT"

SERVICE="${1:-}"

if [[ -n "$SERVICE" ]]; then
    echo "Following logs for $SERVICE (Ctrl+C to exit)..."
    podman-compose logs -f "$SERVICE"
else
    echo "Following logs for all services (Ctrl+C to exit)..."
    podman-compose logs -f
fi
