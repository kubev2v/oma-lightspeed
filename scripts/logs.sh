#!/bin/bash
# Follow logs for OMA Lightspeed services

set -euo pipefail

if podman pod exists oma-lightspeed-pod &>/dev/null; then
    echo "Following logs for oma-lightspeed-pod (Ctrl+C to exit)..."
    podman logs -f oma-lightspeed-pod-lightspeed-stack
else
    echo "Pod oma-lightspeed-pod not found. Run 'make run' to start it."
fi
