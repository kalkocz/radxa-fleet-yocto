# Radxa Zero Fleet — Yocto + RAUC A/B OTA

Reproducible Yocto image for 8× Radxa Zero (Amlogic S905Y2) RuView sensor nodes.

## Hardware
- Radxa Zero, Amlogic S905Y2, 4GB LPDDR4, 128GB eMMC
- Per-node: RPLiDAR S2, Seeed MR60BHA2 mmWave, BT5 ESPresense

## Build host
honeycomb (aarch64, 16 cores, 60GB RAM) — self-hosted GitHub Actions runner

## Stack
- Yocto Scarthgap (5.0)
- meta-meson (BayLibre, scarthgap) — Amlogic S905Y2 BSP
- meta-rauc — A/B OTA updates
- MACHINE: radxa-zero

## Quick start

```bash
# On honeycomb
cd /opt/yocto/radxa-fleet
./scripts/setup.sh
./scripts/build.sh
```

## Plan
See [docs/plan.md](docs/plan.md) — full Yocto + RAUC build plan.

## CI/CD
GitHub Actions → self-hosted runner on honeycomb → builds on push to main.
