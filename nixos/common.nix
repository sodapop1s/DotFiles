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
    extraGroups   = [ "networkmanager" "wheel" "libvirtd" "kvm" ];
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

  environment.sessionVariables.CLAUDE_DISABLE_SANDBOX = "1";

  environment.systemPackages = with pkgs; [
    # Virtualisation tools
    virt-viewer

    # Core tools
    neovim
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
    lutris
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
