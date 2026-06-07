#!/bin/bash
# Setup Yocto workspace for Radxa Zero fleet build
# Run on honeycomb: bash scripts/setup.sh
set -e

YOCTO_DIR="/opt/yocto/radxa-fleet"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "[setup] Yocto workspace: $YOCTO_DIR"
mkdir -p "$YOCTO_DIR"
cd "$YOCTO_DIR"

# Install Yocto host dependencies (Ubuntu 24.04)
if ! dpkg -l python3-pip >/dev/null 2>&1; then
  sudo apt-get install -y \
    gawk wget git diffstat unzip texinfo gcc build-essential \
    chrpath socat cpio python3 python3-pip python3-pexpect \
    xz-utils debianutils iputils-ping python3-git python3-jinja2 \
    python3-subunit zstd liblz4-tool file locales libacl1 \
    lz4 zstd
fi

# Clone layers if not present
clone_or_update() {
  local url=$1 branch=$2 dir=$3
  if [ ! -d "$dir" ]; then
    git clone -b "$branch" --depth 1 "$url" "$dir"
  else
    git -C "$dir" fetch --depth 1 origin "$branch"
    git -C "$dir" checkout FETCH_HEAD
  fi
}

clone_or_update https://git.yoctoproject.org/poky                            scarthgap  poky
clone_or_update https://github.com/openembedded/meta-openembedded             scarthgap  meta-openembedded
clone_or_update https://github.com/superna9999/meta-meson                    scarthgap  meta-meson
clone_or_update https://github.com/rauc/meta-rauc                            scarthgap  meta-rauc
clone_or_update https://github.com/meta-rauc/meta-rauc-community              scarthgap  meta-rauc-community

# Link conf/ from repo
mkdir -p "$YOCTO_DIR/build/conf"
ln -sf "$REPO_DIR/conf/local.conf"    "$YOCTO_DIR/build/conf/local.conf"
ln -sf "$REPO_DIR/conf/bblayers.conf" "$YOCTO_DIR/build/conf/bblayers.conf"

echo "[setup] Done. Run: bash scripts/build.sh"
