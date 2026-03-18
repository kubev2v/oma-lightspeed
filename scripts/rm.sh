#!/bin/bash
# Remove OMA Lightspeed services

set -euo pipefail

if podman pod exists oma-lightspeed-pod &>/dev/null; then
    echo "Removing oma-lightspeed-pod..."
    podman pod kill oma-lightspeed-pod 2>/dev/null || true
    podman pod rm oma-lightspeed-pod
    echo "Pod removed."
else
    echo "Pod oma-lightspeed-pod not found."
fi
