#!/bin/bash
# Stop OMA Lightspeed services

set -euo pipefail

if podman pod exists oma-lightspeed-pod &>/dev/null; then
    echo "Stopping oma-lightspeed-pod..."
    podman pod stop oma-lightspeed-pod
    echo "Pod stopped."
else
    echo "Pod oma-lightspeed-pod not found."
fi
