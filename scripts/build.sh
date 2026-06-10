#!/bin/bash
# Build the Radxa Zero fleet image.
# Requires: scripts/setup.sh already run, and MANGO_WPA_PSK exported.
set -e
TARGET=${1:-core-image-minimal}
YOCTO_DIR="${YOCTO_DIR:-/opt/yocto/radxa-fleet}"
cd "$YOCTO_DIR"
: "${MANGO_WPA_PSK:?export MANGO_WPA_PSK before building (do not hardcode in local.conf)}"
source poky/oe-init-build-env build
bitbake "$TARGET"
