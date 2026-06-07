# Radxa Zero Fleet — Yocto + RAUC A/B OTA Build

**Created:** 2026-06-07  
**Status:** Planning  
**Hardware:** Radxa Zero, Amlogic S905Y2, 4GB LPDDR4, 128GB eMMC (×8)  
**Build host:** honeycomb (aarch64, 16 cores, 60GB RAM, 3.6TB NVMe, Ubuntu 24.04)  
**Goal:** Reproducible fleet image with RAUC A/B OTA, pre-configured WiFi/SSH, RuView + ESPresense baked in  
**Motion project:** Home Infrastructure

---

## BSP Verdict

**Use meta-meson (superna9999) scarthgap branch.** Confirmed:
- `radxa-zero` machine present in `conf/machine/radxa-zero.conf`
- S905Y2 listed as fully supported: "complete bootable .wic sdcard image with mainline U-boot"
- Scarthgap branch exists and is active
- Uses `UBOOT_MACHINE = "radxa-zero_config"` + `amlogic-boot-fip` for FIP signing
- WKS file: `sdimage-meson.wks` (single partition by default — we extend this for RAUC)

**No Radxa-specific Yocto layer needed** — meta-meson covers the hardware completely.

---

## Target Image Layout

```
eMMC mmcblk0:
  mmcblk0boot0  512KB   Amlogic BL2 (U-Boot FIP — never touched by RAUC)
  mmcblk0boot1  512KB   Amlogic BL2 backup (never touched by RAUC)

GPT on mmcblk0 (user area):
  p1   8MB     U-Boot env (RAUC boot state + slot selection)
  p2   512MB   /boot — kernel + DTB (shared, RAUC updates both slots)
  p3   4GB     rootfs Slot A (ext4, active)
  p4   4GB     rootfs Slot B (ext4, standby)
  p5   256MB   /data — persistent config (overlayfs upper, never erased)
  p6   ~118GB  /storage — models, logs, data
```

### Boot Flow (RAUC + U-Boot)

```
Amlogic BL2 (boot0) → U-Boot → reads RAUC boot state from env partition
→ sets bootargs for active slot (A or B) → boots kernel
→ RAUC marks boot as successful → ready for next update
```

U-Boot RAUC integration uses `fw_env` / `bootcount` with two env variables:
- `BOOT_ORDER=A B` (or `B A` to try B first)
- `BOOT_A_LEFT=3` / `BOOT_B_LEFT=3` (countdown before fallback)

---

## Layer Stack

```
poky               (Yocto reference, scarthgap)
meta-oe            (openembedded-core extras, scarthgap)
meta-networking    (network tools, NetworkManager, scarthgap)
meta-python        (Python packages, scarthgap)
meta-meson         (Amlogic S905Y2 BSP, scarthgap)
meta-rauc          (RAUC OTA framework, scarthgap)
meta-ruview        (custom layer — WiFi config, SSH keys, RuView, ESPresense)
```

**Layer URLs:**

| Layer | URL | Branch |
|-------|-----|--------|
| poky | `git://git.yoctoproject.org/poky` | `scarthgap` |
| meta-openembedded | `https://github.com/openembedded/meta-openembedded` | `scarthgap` |
| meta-meson | `https://github.com/superna9999/meta-meson` | `scarthgap` |
| meta-rauc | `https://github.com/rauc/meta-rauc` | `scarthgap` |
| meta-ruview | `./meta-ruview` (local, create in step 4) | — |

---

## Steps

### Phase 0 — Environment Setup [ ]

- [ ] **P0.1** Install Yocto dependencies on honeycomb:
  ```bash
  sudo apt-get install -y gawk wget git diffstat unzip texinfo gcc build-essential \
    chrpath socat cpio python3 python3-pip python3-pexpect xz-utils debianutils \
    iputils-ping python3-git python3-jinja2 libegl1-mesa libsdl1.2-dev xterm \
    python3-subunit mesa-common-dev zstd liblz4-tool file locales libacl1 \
    gcc-aarch64-linux-gnu
  sudo locale-gen en_US.UTF-8
  ```

- [ ] **P0.2** Create build directory:
  ```bash
  mkdir -p /opt/yocto/radxa-fleet && cd /opt/yocto/radxa-fleet
  ```

- [ ] **P0.3** Clone all layers:
  ```bash
  git clone --depth 1 git://git.yoctoproject.org/poky -b scarthgap poky
  git clone --depth 1 https://github.com/openembedded/meta-openembedded -b scarthgap meta-oe
  git clone --depth 1 https://github.com/superna9999/meta-meson -b scarthgap meta-meson
  git clone --depth 1 https://github.com/rauc/meta-rauc -b scarthgap meta-rauc
  ```

- [ ] **P0.4** Initialize build environment:
  ```bash
  cd /opt/yocto/radxa-fleet
  source poky/oe-init-build-env build
  ```

### Phase 1 — RAUC Signing Keys [ ]

- [ ] **P1.1** Generate RAUC signing keypair:
  ```bash
  mkdir -p /opt/yocto/radxa-fleet/rauc-keys
  cd /opt/yocto/radxa-fleet/rauc-keys
  openssl req -x509 -newkey rsa:4096 -nodes -keyout development-1.key.pem \
    -out development-1.cert.pem -days 3650 \
    -subj "/CN=HMS Victory Radxa Zero Fleet/O=HMS Victory/C=US"
  ```

- [ ] **P1.2** Store in OpenBao:
  ```bash
  bao kv put secret/cic/radxa-zero-rauc/signing-cert @development-1.cert.pem
  bao kv put secret/cic/radxa-zero-rauc/signing-key @development-1.key.pem
  ```

- [ ] **P1.3** Copy into meta-ruview for build:
  ```bash
  cp development-1.cert.pem /opt/yocto/radxa-fleet/meta-ruview/files/rauc/
  # key stays in OpenBao — only cert goes in image
  ```

### Phase 2 — Custom Layer (meta-ruview) [ ]

- [ ] **P2.1** Create layer structure:
  ```bash
  mkdir -p /opt/yocto/radxa-fleet/meta-ruview/{conf,recipes-connectivity,recipes-ruview,recipes-security,files/rauc,files/nm,files/ssh}
  ```

- [ ] **P2.2** Create `meta-ruview/conf/layer.conf`:
  ```bitbake
  BBPATH .= ":${LAYERDIR}"
  BBFILES += "${LAYERDIR}/recipes-*/*/*.bb ${LAYERDIR}/recipes-*/*/*.bbappend"
  LAYERVERSION_meta-ruview = "1"
  LAYERDEPENDS_meta-ruview = "core"
  LAYERSERIES_COMPAT_meta-ruview = "scarthgap"
  ```

- [ ] **P2.3** Create `meta-ruview/files/nm/mango-wpa.nmconnection`:
  ```ini
  [connection]
  id=MANGO-WPA
  uuid=f47ac10b-58cc-4372-a567-0e02b2c3d479
  type=wifi
  autoconnect=true

  [wifi]
  mode=infrastructure
  ssid=MANGO-WPA

  [wifi-security]
  auth-alg=open
  key-mgmt=wpa-psk
  psk=PLACEHOLDER_SET_AT_BUILD_TIME

  [ipv4]
  method=auto

  [ipv6]
  method=auto
  ```
  **Note:** Set actual PSK at build time via `MANGO_WPA_PSK` variable from OpenBao (see recipe).

- [ ] **P2.4** Create `meta-ruview/files/ssh/authorized_keys` — add CIC's public key:
  ```
  ssh-ed25519 AAAA... root@claude-hub
  ```

- [ ] **P2.5** Create `meta-ruview/files/rauc/system.conf`:
  ```ini
  [system]
  compatible=radxa-zero-ruview
  bootloader=uboot
  statusfile=/data/rauc.status

  [keyring]
  path=/etc/rauc/keyring.pem

  [slot.rootfs.0]
  device=/dev/mmcblk0p3
  type=ext4
  bootname=A

  [slot.rootfs.1]
  device=/dev/mmcblk0p4
  type=ext4
  bootname=B
  ```

- [ ] **P2.6** Create WiFi config recipe `meta-ruview/recipes-connectivity/nm-config/nm-config.bb`:
  ```bitbake
  SUMMARY = "NetworkManager WiFi config for HMS Victory fleet"
  LICENSE = "MIT"
  LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

  SRC_URI = "file://mango-wpa.nmconnection"
  FILES:${PN} = "${sysconfdir}/NetworkManager/system-connections/mango-wpa.nmconnection"

  do_install() {
      install -d ${D}${sysconfdir}/NetworkManager/system-connections/
      install -m 0600 ${WORKDIR}/mango-wpa.nmconnection \
          ${D}${sysconfdir}/NetworkManager/system-connections/
      # Inject PSK from build variable
      sed -i "s/PLACEHOLDER_SET_AT_BUILD_TIME/${MANGO_WPA_PSK}/" \
          ${D}${sysconfdir}/NetworkManager/system-connections/mango-wpa.nmconnection
  }
  ```

- [ ] **P2.7** Create SSH key recipe `meta-ruview/recipes-security/ssh-keys/ssh-keys.bb`:
  ```bitbake
  SUMMARY = "Pre-installed SSH authorized_keys for fleet access"
  LICENSE = "MIT"
  LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

  SRC_URI = "file://authorized_keys"

  do_install() {
      install -d ${D}/root/.ssh
      install -m 0600 ${WORKDIR}/authorized_keys ${D}/root/.ssh/authorized_keys
  }

  FILES:${PN} = "/root/.ssh/authorized_keys"
  ```

- [ ] **P2.8** Create RAUC config recipe `meta-ruview/recipes-ruview/rauc-system/rauc-system.bb`:
  ```bitbake
  SUMMARY = "RAUC system configuration for radxa-zero fleet"
  LICENSE = "MIT"
  LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

  SRC_URI = "file://system.conf file://development-1.cert.pem"

  do_install() {
      install -d ${D}${sysconfdir}/rauc
      install -m 0644 ${WORKDIR}/system.conf ${D}${sysconfdir}/rauc/system.conf
      install -m 0644 ${WORKDIR}/development-1.cert.pem ${D}${sysconfdir}/rauc/keyring.pem
  }

  FILES:${PN} = "${sysconfdir}/rauc/"
  ```

### Phase 3 — bblayers.conf and local.conf [ ]

- [ ] **P3.1** Edit `build/conf/bblayers.conf`:
  ```bitbake
  BBLAYERS ?= " \
    /opt/yocto/radxa-fleet/poky/meta \
    /opt/yocto/radxa-fleet/poky/meta-poky \
    /opt/yocto/radxa-fleet/meta-oe/meta-oe \
    /opt/yocto/radxa-fleet/meta-oe/meta-networking \
    /opt/yocto/radxa-fleet/meta-oe/meta-python \
    /opt/yocto/radxa-fleet/meta-meson \
    /opt/yocto/radxa-fleet/meta-rauc \
    /opt/yocto/radxa-fleet/meta-ruview \
  "
  ```

- [ ] **P3.2** Edit `build/conf/local.conf` (key settings):
  ```bitbake
  MACHINE = "radxa-zero"
  DISTRO = "poky"
  PACKAGE_CLASSES = "package_ipk"

  # RAUC + systemd (RAUC requires systemd)
  DISTRO_FEATURES:append = " systemd rauc"
  VIRTUAL-RUNTIME_init_manager = "systemd"
  DISTRO_FEATURES_BACKFILL_CONSIDERED = "sysvinit"

  # Build hostname baked in
  hostname:pn-base-files = "ruview-${MACHINE}"

  # WiFi PSK — fetch from OpenBao before build
  MANGO_WPA_PSK = "${@os.environ.get('MANGO_WPA_PSK', 'UNSET')}"

  # Parallel build (honeycomb 16 cores)
  BB_NUMBER_THREADS = "14"
  PARALLEL_MAKE = "-j 14"

  # Image features
  IMAGE_FEATURES:append = " ssh-server-openssh"
  EXTRA_IMAGE_FEATURES += "debug-tweaks"  # Remove for production

  # Image install additions
  IMAGE_INSTALL:append = " \
    rauc \
    rauc-system \
    nm-config \
    ssh-keys \
    networkmanager \
    networkmanager-nmcli \
    node-exporter \
    curl \
    python3 \
    "

  # WKS customization for RAUC A/B layout
  WKS_FILE = "radxa-zero-rauc.wks"
  ```

### Phase 4 — WKS Partition Layout [ ]

- [ ] **P4.1** Create `meta-ruview/wic/radxa-zero-rauc.wks`:
  ```
  # Radxa Zero RAUC A/B partition layout
  # BL2/FIP written separately via dd to mmcblk0boot0

  part u-boot-env  --source empty --offset 2M   --size 8M    --label uboot-env  --align 2048
  part /boot       --source bootimg-efi          --offset 10M --size 512M   --label boot      --align 512
  part /           --source rootfs               --offset 522M --size 4096M  --label rootfs-a  --fstype=ext4 --align 512 --active
  part /media/b    --source empty                --offset 4618M --size 4096M --label rootfs-b  --fstype=ext4 --align 512
  part /data       --source empty                --offset 8714M --size 256M  --label data      --fstype=ext4 --align 512
  ```

### Phase 5 — First Build [ ]

- [ ] **P5.1** Fetch MANGO-WPA PSK from OpenBao before build:
  ```bash
  export MANGO_WPA_PSK=$(bao kv get -field=password secret/shared/wifi/mango-wpa 2>/dev/null \
    || echo "mango-wpa1970")
  ```

- [ ] **P5.2** Build the image:
  ```bash
  cd /opt/yocto/radxa-fleet
  source poky/oe-init-build-env build
  bitbake core-image-minimal
  ```
  Expected build time: 4-8 hours first time on honeycomb (14 parallel jobs). Subsequent builds: 30-60 min (sstate cache).

- [ ] **P5.3** Locate output:
  ```bash
  ls build/tmp/deploy/images/radxa-zero/
  # Key files:
  # core-image-minimal-radxa-zero.wic.bz2   — full eMMC image
  # u-boot.bin.sd.bin                        — bootloader
  ```

### Phase 6 — Initial Flash (First 8 Boards) [ ]

Method: Amlogic USB maskrom mode + pyamlboot

- [ ] **P6.1** Install pyamlboot on honeycomb:
  ```bash
  pip3 install pyamlboot --break-system-packages
  ```

- [ ] **P6.2** Put Radxa Zero in maskrom mode: short the maskrom test point (underside of board, near eMMC chip) while plugging in USB-C to honeycomb. Device appears as `1b8e:0006`.

- [ ] **P6.3** Flash via pyamlboot + dd:
  ```bash
  # Decompress image
  bzip2 -dk build/tmp/deploy/images/radxa-zero/core-image-minimal-radxa-zero.wic.bz2

  # Load USB boot loader (required for maskrom access to eMMC)
  pyamlboot -d radxa-zero write-bl2 build/tmp/deploy/images/radxa-zero/u-boot.bin

  # The board then presents eMMC as a USB mass storage device
  # Flash the full image
  dd if=core-image-minimal-radxa-zero.wic of=/dev/sdX bs=4M conv=fsync status=progress

  # Write bootloader to boot partitions (bypasses GPT)
  dd if=build/tmp/deploy/images/radxa-zero/u-boot.bin.sd.bin of=/dev/sdX conv=fsync,notrunc bs=512 skip=1 seek=1
  dd if=build/tmp/deploy/images/radxa-zero/u-boot.bin.sd.bin of=/dev/sdX conv=fsync,notrunc bs=1 count=440
  ```

  **Alternative if pyamlboot maskrom approach fails:** Use Radxa's `rkdeveloptool` or the Amlogic USB Burning Tool (Windows/Linux).

- [ ] **P6.4** Unplug and boot — board should join MANGO-WPA and be reachable via SSH as root.

- [ ] **P6.5** Verify RAUC:
  ```bash
  ssh root@<board-ip> "rauc status"
  # Expected: slot A active, slot B inactive, system compatible matches
  ```

- [ ] **P6.6** Repeat for all 8 boards. Assign hostnames via first boot:
  ```bash
  ssh root@<ip> "hostnamectl set-hostname ruview-<room>"
  ```

### Phase 7 — OTA Update Delivery [ ]

- [ ] **P7.1** Build a RAUC bundle after image changes:
  ```bash
  bitbake core-image-minimal
  bitbake core-image-minimal -c bundle
  # Output: build/tmp/deploy/images/radxa-zero/core-image-minimal-radxa-zero.raucb
  ```

- [ ] **P7.2** Sign bundle (key from OpenBao):
  ```bash
  bao kv get -field=signing-key secret/cic/radxa-zero-rauc > /tmp/signing.key
  bao kv get -field=signing-cert secret/cic/radxa-zero-rauc > /tmp/signing.cert
  rauc bundle --cert=/tmp/signing.cert --key=/tmp/signing.key \
    build/tmp/deploy/images/radxa-zero/update-manifest.raucm \
    fleet-update-$(date +%Y%m%d).raucb
  shred /tmp/signing.key
  ```

- [ ] **P7.3** Deliver to fleet — push via croc or HTTP:
  ```bash
  # On each board:
  ssh root@<board-ip> "rauc install http://honeycomb.lindy.hmsvictory.org/rauc/fleet-update-20260607.raucb"
  ssh root@<board-ip> "reboot"
  # Board boots into other slot, marks good, old slot becomes standby
  ```

- [ ] **P7.4** Automate fleet update via Ansible:
  ```bash
  ansible-playbook infra/playbooks/rauc-update-radxa-fleet.yml \
    -i inventory -e bundle_url=http://... -e bundle_sha256=...
  ```

---

## RAUC U-Boot Integration

U-Boot must call RAUC's `rauc_env` mechanism for boot counting. The meta-rauc layer provides `u-boot-fw-utils` and `librauc`. In `local.conf`:

```bitbake
IMAGE_INSTALL:append = " u-boot-fw-utils"
PREFERRED_VERSION_u-boot-fw-utils = "${PREFERRED_VERSION_u-boot}"
```

U-Boot environment must be at a known offset (matches `p1` env partition above). Set `fw_env.config` on the device:
```
/dev/mmcblk0p1  0x0000  0x20000  0x20000
```

---

## Critical Unknowns / Blockers

1. **Maskrom pad location** — The Radxa Zero maskrom test point must be physically accessible. Confirm on first board before scaling to 8. If inaccessible without disassembly, use the ADB + radxa-usbnet approach once an image with proper user/SSH is built.

2. **U-Boot RAUC boot counting** — Amlogic boot flow (BL2→U-Boot) needs U-Boot to read/write the env partition for RAUC boot slot selection. Verify this works before declaring RAUC A/B functional. The `amlogic-boot-fip` layer handles the Amlogic-specific bootloader stages.

3. **meta-rauc scarthgap + meta-meson compatibility** — These layers haven't been confirmed to build together without conflicts. Run `bitbake-layers show-recipes` after setup to check for layer conflicts.

4. **WiFi driver** — The Radxa Zero uses AP6212 WiFi. Verify `linux-yocto` mainline kernel includes `brcmfmac` driver and the required firmware blobs for this chip. meta-meson may handle this via `linux-firmware` recipe.

5. **RuView / ESPresense** — Docker for RuView isn't available in poky. Options: (a) add `meta-virtualization` for Docker support, (b) native Python build of RuView with Yocto recipes, (c) deploy via systemd unit that pulls Docker image on first boot from a pre-pulled tarball.

---

## Comparison with clearfog Yocto

| Aspect | clearfog (LX2160A) | radxa-zero (S905Y2) |
|--------|-------------------|---------------------|
| BSP | meta-solidrun-arm-lx2xxx | meta-meson (superna9999) |
| BSP maturity | High (production) | Medium (mainline, active) |
| Boot | NXP layerscape chain | Amlogic BL2 + U-Boot FIP |
| RAUC slots | NVMe GPT | eMMC GPT |
| First flash | dd to NVMe | pyamlboot maskrom |
| Kernel | NXP vendor fork | mainline (linux-yocto) |

---

## Next Steps After Plan Approval

1. `P0.1-P0.4` — environment setup on honeycomb (30 min)
2. `P1.1-P1.3` — RAUC keys (15 min)
3. `P2.1-P2.8` — meta-ruview layer creation (2 hours)
4. `P3.1-P3.2` — layer config (30 min)
5. `P5.1-P5.3` — first build (4-8 hours, overnight)
6. `P6.1-P6.5` — flash first board, verify RAUC (1 hour)
7. `P6.6` — flash remaining 7 boards (3-4 hours)
