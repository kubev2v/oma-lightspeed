#!/bin/bash
# Stop OMA Lightspeed services

set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

cd "$PROJECT_ROOT"

echo "Stopping OMA Lightspeed services..."
podman-compose stop
echo "Services stopped. Run 'make run' to start again."
