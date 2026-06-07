#!/bin/bash
# Build Radxa Zero fleet image
set -e
TARGET=${1:-radxa-fleet-image}
YOCTO_DIR="/opt/yocto/radxa-fleet"
cd "$YOCTO_DIR"
source poky/oe-init-build-env build
bitbake "$TARGET"
