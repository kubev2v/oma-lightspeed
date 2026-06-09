#!/bin/bash
# Resume stopped OMA Lightspeed services

set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

cd "$PROJECT_ROOT"

echo "Resuming OMA Lightspeed services..."
podman-compose start
echo "Services resumed."
