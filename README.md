# DotFiles

NixOS and desktop configuration for two machines, built around one design: a minimal bottom pill, two slide-in
panels, a live Earth wallpaper, and one set of colours that every app shares.

- **soda-fw**: Framework 16 laptop (Ryzen 7 7840HS), NixOS, niri. Gets everything in this repo.
- **soda-desk**: desktop. Uses only `nixos/common.nix` and its own hardware file.

The design brief is in [RICE_SPEC.md](RICE_SPEC.md).

## Two setups, one command to switch

There are two complete desktops in this repo, and you can move between them without a rebuild or a re-login.

| Setup | Shell | niri config | What it is |
|---|---|---|---|
| **orbit** (new) | `quickshell/orbit` | `niri/config-v2.kdl` | pill, panels, Earth wallpaper, shared theme |
| **bar** (old) | `quickshell/bar` | `niri/config.kdl` | the original hub, kept untouched as the fallback |

```bash
~/DotFiles/bin/rice-switch status    # which one is active
~/DotFiles/bin/rice-switch orbit     # switch to the new one
~/DotFiles/bin/rice-switch bar       # back to the old one
~/DotFiles/bin/rice-switch orbit --dry-run
```

`rice-switch` points `~/.config/niri/config.kdl` at the chosen config (niri reloads it live), stops the running shell,
and starts the other. It also stops the `swww` wallpaper daemon for orbit (orbit draws its own) and starts it again for
bar. The first run saves your original file as `config.kdl.pre-rice`. **Never edit `quickshell/bar`**; new work goes in
`quickshell/orbit` and `niri/config-v2.kdl`.

### Getting back to a working desktop

1. `rice-switch bar` restores the old shell and keybinds.
2. `sudo nixos-rebuild switch --rollback` goes back one system generation. The boot menu also lists the last three.
3. The files that were replaced during the restyle (GTK `gtk.css` and `settings.ini`, btop's `btop.conf`) were saved next to
   themselves with a `.pre-rice` suffix.

## Layout

```
nixos/
  flake.nix, flake.lock         inputs: nixpkgs 25.11, nixpkgs-unstable, zen-browser, spicetify-nix, ...
  common.nix                    shared by both hosts: packages, services, default apps, polkit agent
  hosts/soda-fw, soda-desk      one folder per machine
  modules/
    theme/                      tokens.nix (the colours) and the generator for every app's theme file
    wallpaper/                  Earth shader, ISS script and its timer, NASA textures
    clipboard.nix               cliphist and wl-clip-persist as user services
    idle.nix                    orbit-lock (swaylock) and swayidle
    filemanager.nix             "Yazi in Ghostty" launcher
    spotify.nix                 Spotify desktop app themed with spicetify
    omdrop.nix                  AirDrop
  pkgs/                         packages that are not in nixpkgs
quickshell/orbit/               the new shell (see below)
quickshell/bar/                 the old shell, untouched
niri/                           config.kdl (bar) and config-v2.kdl (orbit)
bin/rice-switch                 the switcher
ghostty/ yazi/ gtk/ mpv/ swayimg/   small config files that include the generated theme
```

`nixos/configuration.nix`, `nixos/hardware-configuration.nix` and `niri/dms/` are old leftovers that the flake does
not use.

## Rebuilding

```bash
sudo nixos-rebuild switch --flake ~/DotFiles/nixos#soda-fw     # or #soda-desk
```

The flake only sees files git knows about. A brand-new file needs `git add -N <file>` (or a commit) before a rebuild
will include it.

## One set of colours

`nixos/modules/theme/tokens.nix` is the only place the colours, fonts, corner radius and animation spring are defined.
The theme module turns them into a file per app, installed under `/run/current-system/sw/share/rice-theme/`. Change a
value, rebuild, and everything follows.

- Colours: `bg #0E1013`, `panel`, `raised`, `hairline`, `text`, `muted`. The accent blue is for focus and selection
  only. `good`, `warn` and `crit` (green, amber, red) are for states only.
- Motion: one spring, used by niri's animations and by the shell.
- Fonts: D-DIN for the interface (not packaged in nixpkgs, so Inter is the fallback), JetBrainsMono Nerd Font for code.

| App | How it picks up the theme |
|---|---|
| orbit shell | reads `rice-theme/tokens.json` at start |
| niri | `config-v2.kdl` includes `rice-theme/niri.kdl` (border colours, animations) |
| Ghostty | `ghostty/config` includes the generated palette and font files |
| GTK apps | `gtk/gtk.css` imports the generated colours; the `adw-gtk3-dark` theme and dark scheme are set through dconf |
| yazi | `~/.config/yazi/theme.toml` links to the generated file |
| mpv | `mpv/mpv.conf` includes the generated file; `script-opts/uosc.conf` links to the generated one |
| swayimg | `swayimg/config` has `include <path>` (a space, no equals sign) |
| sioyek | `~/.config/sioyek/prefs_user.config` links to the generated file |
| btop | `~/.config/btop/themes/rice.theme` links to it; `color_theme = "rice"` in `btop.conf` |
| Neovim | a `rice.lua` plugin loads the generated colourscheme (see below) |
| Spotify | `modules/spotify.nix` feeds the tokens to spicetify |
| swaylock | generated config used by `orbit-lock` |

### Wiring on a new machine

These links are not created by the rebuild. After the first rebuild:

```bash
cd ~/DotFiles; R=/run/current-system/sw/share/rice-theme
mkdir -p ~/.config/{ghostty,yazi,mpv/script-opts,swayimg,sioyek,btop/themes,gtk-3.0,gtk-4.0}
ln -sfn $PWD/quickshell        ~/.config/quickshell
ln -sfn $PWD/ghostty/config    ~/.config/ghostty/config
ln -sfn $PWD/yazi/yazi.toml    ~/.config/yazi/yazi.toml
ln -sfn $R/yazi/theme.toml     ~/.config/yazi/theme.toml
ln -sfn $PWD/gtk/gtk.css       ~/.config/gtk-3.0/gtk.css
ln -sfn $PWD/gtk/gtk.css       ~/.config/gtk-4.0/gtk.css
ln -sfn $PWD/mpv/mpv.conf      ~/.config/mpv/mpv.conf
ln -sfn $R/mpv/script-opts/uosc.conf ~/.config/mpv/script-opts/uosc.conf
ln -sfn $PWD/swayimg/config    ~/.config/swayimg/config
ln -sfn $R/sioyek/theme.config ~/.config/sioyek/prefs_user.config
ln -sfn $R/btop/rice.theme     ~/.config/btop/themes/rice.theme
sed -i 's/^color_theme = .*/color_theme = "rice"/' ~/.config/btop/btop.conf
sed -i 's/^gtk-application-prefer-dark-theme=.*/gtk-application-prefer-dark-theme=true/' ~/.config/gtk-{3,4}.0/settings.ini
bin/rice-switch orbit
```

For Neovim (LazyVim), create `~/.config/nvim/lua/plugins/rice.lua`. Neovim's config is not in this repo.

```lua
return {
  { dir = "/run/current-system/sw/share/rice-theme/nvim", name = "rice", lazy = false, priority = 1000 },
  { "LazyVim/LazyVim", opts = { colorscheme = "rice" } },
}
```

## The orbit shell

Written in QML for [Quickshell](https://quickshell.org). `shell.qml` loads these pieces:

- **Pill** (bottom centre): workspace dots, time, battery. A study timer or a "No network" notice appears only when
  there is something to show.
- **System panel** (`Super+B`, slides in from the left): quick settings (brightness, Wi-Fi, Bluetooth, Tailscale),
  processor and memory, temperatures, battery, audio, AirDrop, and homelab services.
- **Day panel** (`Super+Y`, from the right): today's classes, what is due, now playing, notifications.
- **Windows**: launcher (`Super+Space`), clipboard history (`Super+V`), study (`Super+E`: due, exams, grades, focus
  timer), Wi-Fi and Bluetooth (`Super+Shift+W` / `Super+Shift+B`), and the shortcuts menu (`Super+Shift+/`).
- **Wallpaper**, **notification popups**, and the lock screen and idle handling (see below).

Press **`Super+Shift+/`** for the full list of keys. That menu reads your niri binds, so it is always correct; to add or
rename a row, edit `MENU` in `quickshell/orbit/hotkeys.py`.

Everything can also be driven from a terminal, which is handy for keybinds and testing:

```bash
qs -c orbit ipc show                                    # every target and function
qs -c orbit ipc call panel toggle left|right|launcher|clipboard|study|keys|network
qs -c orbit ipc call network open wifi|bluetooth
qs -c orbit ipc call quick brightness 60
qs -c orbit ipc call study timer start|pause|toggle|reset
qs -c orbit ipc call dnd toggle
qs -c orbit ipc call notif dismiss|dismissAll|clearHistory
```

The orbit folder still holds 44 old hub files (QML pages, plus helper scripts only they use) that the shell does not
load. They are kept so features can be ported from them, and can be deleted once nothing more is needed.

## Wallpaper

A fragment shader draws Earth as seen from orbit, lit by the real sun. NASA's Blue Marble (day) and Black Marble
(night) maps are fetched by Nix, pinned by hash, and downscaled to 4096x2048. The sun's position is computed once a
minute (every five on battery) and nothing animates. A systemd user timer (`orbit-iss`) computes the ISS position
every minute from a CelesTrak orbit file (refetched at most every 12 hours) and the shell draws a marker.

## Services

User units, started with the graphical session: `swayidle` (lock after 5 minutes, screen off after 6, suspend after 20
only on battery), `cliphist-watch` and `wl-clip-persist` (clipboard history, wiped daily at 4 AM), and the `orbit-iss`
timer.

## Not in the repo

These live on the machine on purpose. Several are secrets and must never be committed.

| Path | What |
|---|---|
| `~/.config/orbit/calendar-url` | calendar link(s), one per line (Google "secret address in iCal format"). Set with `wl-paste \| bash ~/DotFiles/quickshell/orbit/calendar.sh seturl` |
| `~/.config/orbit/services.json` | homelab services for the System panel: `[{"name": "...", "host": "...", "port": 443}]` |
| `~/.config/qs-bar/` | Canvas token and other data shared with the old shell |
| `~/.local/state/qs-orbit-*.json`, `~/.cache/orbit/` | shell state, ISS position |
| `~/.config/nvim/` | Neovim config |

## Things that cost time before

- **Nix renames processes.** Quickshell is `.quickshell-wrapped`. Match with an anchored `pgrep -f '^\S*/quickshell( |$)'`;
  `-x` never matches, and an unanchored `-f` can match your own shell.
- **`environment.pathsToLink` is an allow-list.** A module that installs files under a new `share/<dir>` must add it, or
  the files never reach `/run/current-system/sw`.
- **dconf beats `settings.ini`.** The GTK theme only applies because it is set in `modules/theme`.
- **A new `.qml` file used in a later edit** makes Quickshell say "X is not a type" until the shell is restarted
  (`rice-switch orbit`).
- **IPC function names** must not be `show` (clashes with `qs ipc show`), and file names must not shadow built-in QML
  types (`Connections`).
- **config-v2 includes a generated niri file.** Until a rebuild installs it, niri cannot reload that config.
- **Testing:** never run a lock command as a test (it needs your password to undo), and never flip Wi-Fi, Bluetooth or
  Tailscale. Test lock scripts on a copy with the last command replaced by `echo`.
- **The boot partition is 96 MB** and shared with Windows, so `configurationLimit` is kept at 3.
