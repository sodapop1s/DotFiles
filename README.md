# DotFiles

> Some of the configs in this repo were written with AI assistance
> rather than fully hand-written. Review before blindly
> trusting anything here on a new machine.

Personal config and homelab setup. NixOS flake-based on the desktop and
Framework 16, Docker Compose everywhere else.

## About

Aerospace engineering student, Linux/homelab tinkerer. Strong preference for
FOSS, terminal-native, and self-hosted tools over SaaS.

- **Editor:** Neovim (LazyVim), all machines
- **Theme:** Catppuccin Mocha
- **Scripting language:** Python
- **Browser:** Floorp
- **Homelab philosophy:** Docker Compose always, never bare metal

## Machines

### Debian — homelab server
Headless. AMD Ryzen 7 5800X3D, Radeon RX 7600. Runs everything via Docker
Compose, fronted by a Cloudflare Tunnel instead of a local reverse proxy like
Caddy. Hosts a GTNH (GregTech: New Horizons) modded Minecraft server via
Pelican Panel, and Odysseus — a self-hosted AI workspace that calls out to
Ollama running on the desktop.

### NixOS Desktop — main computer
niri window manager, flake-based config. Migrated from Fedora. AMD Ryzen 7
7700X, Radeon RX 6950 XT + Raphael iGPU. Runs Ollama with ROCm as the
inference backend for Odysseus on the server.

### NixOS Framework 16 — main laptop
Dual-boots Windows, niri, flake-based, still a work in progress. Linked to
the Pixel 10 via KDE Connect. Shares its config with a ThinkPad T420 (older
hardware, no dGPU) that's used for sandboxing and testing changes before
they hit the main machines — the ThinkPad itself runs Arch.

### Windows
Same hardware as the Framework 16, dual-booted for the rare occasion school
software doesn't run on Linux. Minimal use.

### Android — Pixel 10
Stock, unrooted. Daily driver phone, linked to the Framework 16 via KDE
Connect. F-Droid preferred over the Play Store where available. Used for a
self-hosted reading/media setup (Kavita, etc.) and remote access to homelab
services through the Cloudflare Tunnel.

## Repo structure
