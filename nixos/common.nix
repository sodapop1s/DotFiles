{ config, pkgs, inputs, system, ... }:

{
  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelModules = [ "nct6683" ];

  # Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # Locale / timezone
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS        = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT    = "en_US.UTF-8";
    LC_MONETARY       = "en_US.UTF-8";
    LC_NAME           = "en_US.UTF-8";
    LC_NUMERIC        = "en_US.UTF-8";
    LC_PAPER          = "en_US.UTF-8";
    LC_TELEPHONE      = "en_US.UTF-8";
    LC_TIME           = "en_US.UTF-8";
  };

  # Keymap
  services.xserver.xkb = {
    layout  = "us";
    variant = "";
  };

  # Networking
  networking.networkmanager.enable = true;
  services.tailscale.enable = true;
  networking.firewall.trustedInterfaces = [ "tailscale0" "virbr0" ];

  # nix-ld: makes non-NixOS binaries (SMAPI, AppImages, VS Code extensions) work
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      icu
      openssl
      zlib
      stdenv.cc.cc.lib
      fontconfig.lib
      freetype
      libGL
    ];
  };

  # User account
  users.users.soda = {
    isNormalUser  = true;
    description   = "Soda";
    extraGroups   = [ "networkmanager" "wheel" "libvirtd" "kvm" "dialout" ];
    packages      = with pkgs; [];
  };

  # Display / WM
  programs.niri.enable = true;
  services.displayManager.sddm = {
    enable         = true;
    wayland.enable = true;
  };
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    google-fonts
  ];

  # External drive — shared between both machines
  fileSystems."/mnt/external" = {
    device  = "/dev/disk/by-uuid/869cb7b4-fc80-454f-8913-37dd51a80c0c";
    fsType  = "btrfs";
    options = [ "defaults" "nofail" "x-systemd.device-timeout=5s" ];
  };

  # Virtualisation (QEMU/KVM + virt-manager, Windows 11 ready)
  virtualisation.libvirtd = {
    enable = true;
    qemu.swtpm.enable = true;  # software TPM 2.0 — required by Windows 11
  };
  virtualisation.spiceUSBRedirection.enable = true;
  programs.virt-manager.enable = true;

  # Power profiles (the bar's Profile button switches between saver / balanced / performance)
  services.power-profiles-daemon.enable = true;

  # Don't suspend on lid close (keeps VMs running)
  services.logind.lidSwitch = "ignore";

  # NAT for VMs on virbr0 (libvirt's iptables rules don't apply on NixOS nftables)
  networking.nat = {
    enable             = true;
    internalInterfaces = [ "virbr0" ];
    externalInterface  = "wlp1s0";
  };

  # Core services
  services.flatpak.enable             = true;
  services.gnome.gnome-keyring.enable = true;
  services.udisks2.enable             = true;
  services.devmon.enable   = true;
  services.gvfs.enable     = true;
  services.tumbler.enable  = true;

  # Audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable            = true;
    alsa.enable       = true;
    alsa.support32Bit = true;
    pulse.enable      = true;
  };

  # Programs
  programs.steam = {
    enable                    = true;
    remotePlay.openFirewall   = true;
    dedicatedServer.openFirewall = true;
    protontricks.enable       = true;
    extraCompatPackages       = [ pkgs.proton-ge-bin ];
  };
  programs.gamescope.enable = true;
  programs.thunar = {
    enable  = true;
    plugins = with pkgs.xfce; [
      thunar-archive-plugin
      thunar-volman
      thunar-media-tags-plugin
    ];
  };
  programs.obs-studio = {
    enable  = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-pipewire-audio-capture
    ];
  };

  # XDG portals
  xdg.portal = {
    enable       = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
  };

  # Polkit agent — niri doesn't ship one, so GUI apps can't ask for the password without it
  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    description = "polkit-gnome-authentication-agent-1";
    wantedBy    = [ "graphical-session.target" ];
    wants       = [ "graphical-session.target" ];
    after       = [ "graphical-session.target" ];
    serviceConfig = {
      Type           = "simple";
      ExecStart      = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart        = "on-failure";
      RestartSec     = 1;
      TimeoutStopSec = 10;
    };
  };

  # Default apps by file type
  xdg.mime.defaultApplications = {
    "application/pdf"  = "sioyek.desktop";
    "text/plain"       = "org.gnome.TextEditor.desktop";
    "video/mp4"        = "mpv.desktop";
    "video/x-matroska" = "mpv.desktop";
    "video/webm"       = "mpv.desktop";
    "video/quicktime"  = "mpv.desktop";
    "video/x-msvideo"  = "mpv.desktop";
    "audio/mpeg"       = "vlc.desktop";
    "audio/flac"       = "vlc.desktop";
    "audio/ogg"        = "vlc.desktop";
    "audio/x-wav"      = "vlc.desktop";
    "image/png"        = "swayimg.desktop";
    "image/jpeg"       = "swayimg.desktop";
    "image/gif"        = "swayimg.desktop";
    "image/webp"       = "swayimg.desktop";
    "inode/directory"  = "thunar.desktop";
  };

  environment.sessionVariables.CLAUDE_DISABLE_SANDBOX = "1";

  # iPhone support (libimobiledevice needs usbmuxd to talk to the phone)
  services.usbmuxd.enable = true;

  environment.systemPackages = with pkgs; [
    # Virtualisation tools
    virt-viewer

    # iPhone tools (idevice_id, idevicerestore, ...)
    libimobiledevice
    ifuse
    (callPackage ./pkgs/idevicerestore-git.nix { })

    # Microcontroller dev
    (callPackage ./pkgs/arduino-ide.nix { })

    # Core tools
    neovim
    ghostty          # terminal for the orbit setup; kitty stays for bar
    python3          # used by the quickshell bar (calendar feed, spotify login)
    fastfetch
    git
    unzip
    yazi
    qview
    lm_sensors
    libnotify
    playerctl
    (rofi.override { plugins = [ pkgs.rofi-calc ]; })

    # Terminal / shell
    kitty
    alacritty
    wl-clipboard
    quickshell
    xwayland-satellite
    brightnessctl
    swww
    swaylock

    # Communication / browsers
    inputs.zen-browser.packages.${system}.default
    (callPackage ./pkgs/helium.nix { })
    inputs.claude-desktop-extra.packages.${system}.default
    vesktop
    obsidian

    # Dev tools
    claude-code
    gh
    cloudflared

    # Java (needed for Minecraft tooling)
    jdk21

    # Media / creative
    kdePackages.kdenlive
    spotify-player
    wlsunset         # night light (the bar's "Night" button)
    ckan             # Kerbal Space Program mod manager (used by the bar's Games > KSP tab)

    # Gaming
    # Lutris from unstable: 25.11 ships 0.5.19, three releases behind
    (import inputs.nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
      # Lutris's FHS env still ships gtk2 for old games; unstable flags it as a deprecation nag
      config.problems.handlers."gtk+".broken = "warn";
    }).lutris
    (prismlauncher.override {
      additionalLibs = [ libxkbcommon ] ++ (with xorg; [
        libX11 libXtst libxcb libXt libXinerama
      ]);
    })
    (callPackage ./pkgs/ninjabrain-bot.nix { })
    (callPackage ./pkgs/matlab-fhs.nix { })
    wivrn
    olympus
    gale

    # Misc / office
    libreoffice

    # Default desktop apps
    vlc                  # audio default, fallback for odd video
    (mpv.override { scripts = with mpvScripts; [ uosc thumbfast ]; })
    sioyek               # PDF viewer (default)
    papers               # secondary PDF app: forms, signing, markup
    swayimg              # image viewer (default)
    yazi                 # terminal file manager
    gnome-text-editor
    pavucontrol          # audio mixer
    networkmanagerapplet # nm-connection-editor
    gnome-disk-utility
    baobab               # disk usage analyzer

    # Thumbnail / file manager dependencies
    ffmpegthumbnailer
    webp-pixbuf-loader
    file-roller
    unar
    jq
    poppler
    fd
    ripgrep
    fzf
    zoxide
    imagemagick
  ];

  system.stateVersion = "25.11";
}
