{ config, pkgs, ... }:

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
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

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
    extraGroups   = [ "networkmanager" "wheel" ];
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

  # Core services
  services.flatpak.enable  = true;
  services.udisks2.enable  = true;
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

  environment.systemPackages = with pkgs; [
    # Core tools
    neovim
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
    floorp-bin
    vesktop
    obsidian

    # Dev tools
    claude-code
    gh
    cloudflared

    # Java (needed for Minecraft tooling)
    javaPackages.compiler.semeru-bin.jre-17

    # Media / creative
    kdePackages.kdenlive

    # Gaming
    (prismlauncher.override {
      additionalLibs = [ libxkbcommon ] ++ (with xorg; [
        libX11 libXtst libxcb libXt libXinerama
      ]);
    })
    (callPackage ./pkgs/ninjabrain-bot.nix { })
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
