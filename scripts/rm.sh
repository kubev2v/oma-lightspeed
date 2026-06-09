#!/bin/bash
# Remove OMA Lightspeed services and volumes

set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

cd "$PROJECT_ROOT"

echo "Removing OMA Lightspeed services..."
podman-compose down -v
echo "Services and volumes removed."
