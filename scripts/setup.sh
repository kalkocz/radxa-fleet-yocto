#!/bin/bash
# Setup the Yocto workspace for the Radxa Zero fleet build.
# Clones the upstream layers (matching the live build on honeycomb) and links
# this repo's meta-ruview + conf into the build tree.
#   Run:  bash scripts/setup.sh
set -e

YOCTO_DIR="${YOCTO_DIR:-/opt/yocto/radxa-fleet}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "[setup] Yocto workspace: $YOCTO_DIR"
# CI runs as the 'yocto' user; layers/sstate may be created by other uids.
git config --global --add safe.directory '*' 2>/dev/null || true
mkdir -p "$YOCTO_DIR"
cd "$YOCTO_DIR"

clone_or_update() {  # url branch dir
  local url=$1 branch=$2 dir=$3
  if [ ! -d "$dir/.git" ]; then
    git clone -b "$branch" --depth 1 "$url" "$dir"
  else
    git -C "$dir" fetch --depth 1 origin "$branch" && git -C "$dir" checkout -q FETCH_HEAD
  fi
}

# Upstream layers — must match conf/bblayers.conf (clone meta-openembedded as "meta-oe")
clone_or_update https://git.yoctoproject.org/poky                 scarthgap  poky
clone_or_update https://github.com/openembedded/meta-openembedded scarthgap  meta-oe
clone_or_update https://github.com/baylibre/meta-meson            scarthgap  meta-meson
clone_or_update https://github.com/rauc/meta-rauc                 scarthgap  meta-rauc
clone_or_update https://git.yoctoproject.org/meta-virtualization  scarthgap  meta-virtualization

# meta-ruview ships in THIS repo — link it into the workspace
ln -sfn "$REPO_DIR/meta-ruview" "$YOCTO_DIR/meta-ruview"

# Link build config from repo
mkdir -p "$YOCTO_DIR/build/conf"
ln -sf "$REPO_DIR/conf/local.conf"    "$YOCTO_DIR/build/conf/local.conf"
ln -sf "$REPO_DIR/conf/bblayers.conf" "$YOCTO_DIR/build/conf/bblayers.conf"

# RAUC signing keys are NOT in git — provide them out-of-band
[ -f "$YOCTO_DIR/rauc-keys/development-1.key.pem" ] || \
  echo "[setup] WARNING: rauc-keys/development-1.{cert,key}.pem missing — provide before building"

echo "[setup] Done. Export MANGO_WPA_PSK, then: bash scripts/build.sh"
