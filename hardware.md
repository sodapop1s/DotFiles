# Hardware Inventory

Volatile/exact specs for all machines. Update this file when hardware, kernel, or
memory/swap config changes — the `userPreferences` block only tracks stable identity
(DE, purpose, package manager) and points here for anything precise.

Last updated: 2026-07-07

---

## nixos_desktop — Main Desktop

- **CPU:** AMD Ryzen 7 7700X @ 5.7GHz (16 threads)
- **GPU1:** AMD Radeon RX 6950 XT
- **GPU2:** AMD Raphael (iGPU)
- **Memory:** 30.49GB
- **Monitors:** 1920x1080, 1920x1080 @ 165Hz
- **Network:** 1Gbps
- **Kernel:** TBD
- **Notes:** Migrated from Fedora. Previous Fedora kernel was 6.14.14-200.fc43.x86_64;
  no longer accurate post-migration.

## debian — PowerSpec PC (homelab server)

- **CPU:** AMD Ryzen 7 5800X3D @ 4.55GHz (16 threads)
- **GPU:** AMD Radeon RX 7600
- **Memory:** 16GB
- **Swap:** 8GB
- **Kernel:** Linux 6.12.73+deb13-amd64
- **Local IP:** 192.168.1.236/24

## nixos_framework16 — Framework 16 (dual-boot with Windows)

- **CPU:** AMD Ryzen 7 7840HS (integrated Radeon 780M graphics)
- **GPU:** AMD Radeon 780M (iGPU, part of the 7840HS)
- **Memory:** 30GB total (26GB used / 1.0GB free / 4.4GB buff-cache at time of check)
- **Swap:** 0B (no swap configured)
- **Kernel:** 6.12.93
- **Notes:** Config WIP, being built out over summer 2026.

## arch — ThinkPad T420 (sandboxing)

- **CPU:** TBD (older hardware)
- **GPU:** None (no dGPU)
- **Memory:** TBD
- **Notes:** Shares config with nixos_framework16, but runs Arch/Hyprland natively —
  used for testing before deploying config changes to main machines.

## windows — Framework 16 (dual-boot with NixOS)

- Same physical hardware as nixos_framework16 entry above.
- Minimal use, fallback OS only for Linux-incompatible school software.

## android — Pixel 10

- **OS:** Stock, unrooted
- **Storage/RAM:** TBD

---

