# Radxa Zero Fleet — Yocto + RAUC A/B OTA

Reproducible Yocto image for 8× Radxa Zero (Amlogic S905Y2) RuView sensor nodes.

## Hardware
- Radxa Zero, Amlogic S905Y2 (G12A), 4GB LPDDR4, 128GB eMMC
- **WiFi/BT: AP6256 = Broadcom BCM43456** (`BCM4345/9`). NOT the older AP6212/BCM43430.
- Per-node: ESP32-S3 CSI sensor, Seeed MR60BHA2 mmWave, BT5 ESPresense

## Build host
honeycomb (`/opt/yocto/radxa-fleet`), Yocto **scarthgap (5.0)**, MACHINE `radxa-zero`.

## Repo layout
Only `meta-ruview` (the custom layer) + build config live here. Upstream layers are
cloned separately (and gitignored):

| Layer | Source | Branch |
|-------|--------|--------|
| poky | git://git.yoctoproject.org/poky | scarthgap |
| meta-openembedded (`meta-oe`) | https://github.com/openembedded/meta-openembedded | scarthgap |
| meta-meson | https://github.com/baylibre/meta-meson | scarthgap |
| meta-rauc | https://github.com/rauc/meta-rauc | scarthgap |
| meta-virtualization | git://git.yoctoproject.org/meta-virtualization | scarthgap |
| **meta-ruview** | **this repo** | — |

## Build

```bash
cd /opt/yocto/radxa-fleet
# clone upstream layers (see table) into ./, then:
cp /path/to/this-repo/conf/local.conf    build/conf/local.conf
cp /path/to/this-repo/conf/bblayers.conf build/conf/bblayers.conf
export MANGO_WPA_PSK=...            # from OpenBao — do NOT hardcode in local.conf
# set the rock password hash in local.conf: openssl passwd -6
source poky/oe-init-build-env build
bitbake core-image-minimal
```

Provide secrets out-of-band (gitignored): `rauc-keys/development-1.{cert,key}.pem`,
`MANGO_WPA_PSK` (env), and the `rock` SHA-512 crypt hash in `local.conf`.

## Fleet fixes baked into `meta-ruview` (S125 2026-06-09)
Lessons from board 1 bring-up (`ruview-family`, live on MANGO-WPA `10.10.5.203`):

| Symptom | Cause | Fix |
|---------|-------|-----|
| No `wlan0`, deferred-probe spam | `core-image-minimal` omits `kernel-modules` → `pwm-meson`/`brcmfmac` absent → SDIO clock chain (wifi32k/sdio-pwrseq) never resolves | `IMAGE_INSTALL += kernel-modules` |
| `brcmfmac43456-sdio.bin failed -2` | chip is **BCM43456/AP6256**, not 43430 | `firmware-radxa-wifi` recipe (Radxa-official 43456 blobs + `radxa,zero` symlinks) |
| `wlan0` stuck `unmanaged` | NM `ifupdown` plugin (`managed=false`) + `wlan0` stanza in `/etc/network/interfaces` | `nm-config` ships `conf.d/00-plugins.conf` → `plugins=keyfile` |
| no `ip` / `timeout` | minimal image | `iproute2`, `coreutils` |

## Flashing a board (Amlogic Maskrom → host)

1. Hold **BOOT**, plug USB-C into the build host → Maskrom (`1b8e:c003`).
2. Build the combined U-Boot once:
   `cat u-boot.bin.usb.bl2 u-boot.bin.usb.tpl > u-boot-usb-combined.bin`
   (in `tmp/deploy/images/radxa-zero/`)
3. `sudo python3 scripts/boot-g12-stage.py u-boot-usb-combined.bin` → U-Boot in RAM.
4. On the board's serial console (`ttyAML0`, 115200): **`ums 0 mmc 2`** (eMMC = mmc 2).
5. On the host: `bzcat core-image-minimal-radxa-zero.wic.bz2 | dd of=/dev/sdX bs=4M conv=fsync`
   (verify `/dev/sdX` = the 115G `Linux UMS disk`, not a host disk).
6. `Ctrl-C` + `reset` on the console. Boots Yocto from eMMC; auto-connects MANGO-WPA.

## CI/CD
GitHub Actions → self-hosted runner on honeycomb → builds on push to main.
