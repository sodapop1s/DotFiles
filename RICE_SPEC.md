# Rice overhaul spec — soda-fw (Framework 16, NixOS, niri)

## Goal
Full teardown of the current rice. Replace the bloated quickshell "bar" hub with a minimal default view plus on-demand panels. Drop Catppuccin. Space feel comes from a live Earth wallpaper and restrained modern-spacecraft styling — no role-play vocabulary, no puns, plain labels everywhere.

## Context
- Host: soda-fw (Framework 16, Ryzen 7 7840HS), NixOS, flakes, niri
- Currently still on an outdated flake in /etc/nixos — must migrate into ~/DotFiles per-host layout first
- Current shell: quickshell config named `bar` (`qs -c bar ipc call ...`) — keep it as a fallback until the new one works
- Terminal: kitty (moving to Ghostty). Editor: Neovim (lazy.nvim, ~/.config/nvim/init.lua). Browser: Helium (Chromium-based, already in use)
- Scripting language: Python. Prefer NixOS-native tooling
- ESP is 96MB (shared with Windows) — keep boot.loader.systemd-boot.configurationLimit low

## Design tokens (single source of truth, defined in Nix)
Colors (dark; light variant later):
- bg `#0E1013`, panel `#171A1F`, raised `#20242B`, hairline `#2C313A`
- text `#F2F4F7`, muted `#8B93A1`
- accent `#4C9EFF` — focus/selection only
- good `#3FCF8E`, warn `#F5A524`, crit `#F2555A` — states only

Type: D-DIN (UI), JetBrains Mono or Iosevka (terminal/code)

Motion: one shared spring definition (slight overshoot, then settle) used by both niri `animations` (spring damping-ratio/stiffness) and quickshell animations.

Export tokens to: quickshell (JSON file read at runtime), Ghostty, niri (borders/focus ring/animations), GTK, Neovim, yazi, swayimg, mpv/uosc, sioyek, spicetify, Obsidian CSS snippet.

## Layout
Default (minimal):
- Floating pill, bottom center: workspace dots, time, battery
- Anything else (network, etc.) appears only when it needs attention

Panels (toggle with one keybind, slide in from screen edges, wallpaper dims behind):
- Left — system: CPU, temps, battery detail, wifi, homelab service up/down
- Right — day: classes, deadlines, media
- Keep the panel set small; only port hub features the user confirms they use (TBD — ask)

## Wallpaper
- QML ShaderEffect rendering Earth: blend NASA Blue Marble (day) and Black Marble (night) textures by real subsolar point for the current time
- ISS position dot: small Python script (skyfield or sgp4) fetches TLE from CelesTrak periodically, computes position, writes JSON the shader/QML reads
- Update once per minute; on battery, render a static frame (no continuous animation)

## Build order
1. Migrate soda-fw from /etc/nixos into ~/DotFiles per-host layout (rebuild: `sudo nixos-rebuild switch --flake ~/DotFiles/nixos#<host>`)
2. Theme module: tokens in Nix → generated configs/JSON
3. New quickshell config built by copying the existing `bar` hub into a new config dir and reworking the copy (pill + panels, new tokens); `bar` itself stays untouched as the fallback
4. Earth wallpaper shader + ISS script (systemd user timer)
5. Port only confirmed-used hub features into panels

## Default apps
Decided:
- Browser: **Helium** (already installed and in use — just theme/integrate, don't replace)
- Terminal: **Ghostty** (programs.ghostty via Home Manager). Keep kitty installed because the fallback `bar` session uses it
- Editor: **Neovim** (keep)
- File manager: **yazi** (themed from tokens; image previews work in Ghostty via the Kitty graphics protocol)
- PDF: **sioyek** default for application/pdf (colors from tokens); **Papers** installed as secondary "Open with" for forms, signing, markup
- Images: **swayimg** default for image/* (colors from tokens; gallery mode)
- Video: **mpv** with `mpvScripts.uosc` + `mpvScripts.thumbfast` via `mpv.override { scripts = [...]; }`; `hwdec=auto-safe`; uosc colors and osd-font from tokens
- Launcher, panels: the reworked quickshell hub (see build step 3)
- Notifications: keep the current notification setup as-is, only restyle with new tokens
- Clipboard:
  - `wl-clip-persist --clipboard regular` (regular clipboard only, NOT primary)
  - **clipvault** for history storage via `wl-paste --watch clipvault store`, with expiry (e.g. `--max-entries 200 --max-entry-age 2d`)
  - Picker is a quickshell panel reading from clipvault (bind Mod+V), not rofi/fuzzel
- Music: Spotify themed with **spicetify-nix**, colors from tokens

Still open — ask before installing:
- GUI file manager (Thunar?) if one is needed alongside yazi
- Lock screen, idle (swayidle), screenshots (niri built-in + satty?), system monitor (btop?)
- Notes: Obsidian + obsidian.nvim + self-hosted LiveSync (CouchDB on the Debian server) was proposed, not confirmed
- Password prompts: proposed quickshell built-in polkit agent (Quickshell.Services.Polkit) in the new config, gnome-keyring unlocked via PAM at login for Helium, pinentry-gnome3 if GPG/SSH passphrases are used — not confirmed. Check what the current session uses first (`ps aux | grep -i polkit`)

Check current handlers first with `xdg-mime query default <type>` before changing anything.

## Fallback requirement
The new UI must be fully separate from the current one so the user can switch back at any time:
- Do all work on a separate git branch (e.g. `rice-v2`)
- New quickshell config is a copy of `bar` under its own name/dir (e.g. `orbit`); never modify the existing `bar` config itself
- New niri config lives alongside the current one, not over it
- Both setups stay installed; switching between them should be a script or login-session choice, not a rebuild
- Avoid a NixOS specialisation unless needed — each one adds boot entries and the ESP is only 96MB
- Note: hosts/soda-fw already exists in ~/DotFiles/nixos with uncommitted changes — check what's already migrated before redoing it

## Constraints
- No hype labels or space puns in UI text
- Never commit secrets (prior incident with an SSH key)
- Battery-conscious on the laptop
