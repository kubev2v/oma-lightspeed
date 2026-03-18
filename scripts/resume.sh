#!/bin/bash
# Resume stopped OMA Lightspeed services

set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

if podman pod exists oma-lightspeed-pod &>/dev/null; then
    echo "Resuming oma-lightspeed-pod..."
    podman pod start oma-lightspeed-pod
    echo "Pod resumed."
    "$SCRIPT_DIR/logs.sh"
else
    echo "Pod oma-lightspeed-pod not found. Run 'make run' to start it."
fi
