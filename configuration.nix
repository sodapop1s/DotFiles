# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 3;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelModules = [ "nct6683" ];

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;
  services.flatpak.enable = true;

  services.pipewire.wireplumber.extraConfig."51-bluez-a2dp-only" = {
  "monitor.bluez.properties" = {
    "bluez5.roles" = [ "a2dp_sink" "a2dp_source" ];
  };
};
  # Bluetooth
hardware.bluetooth.enable = true;
hardware.bluetooth.powerOnBoot = true;
  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.soda = {
    isNormalUser = true;
    description = "Soda Graybill";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  programs.niri.enable = true;
  programs.dank-material-shell = {
  enable = true;
  enableSystemMonitoring = true;
};
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  fileSystems."/mnt/external" = {
  device = "/dev/disk/by-uuid/869cb7b4-fc80-454f-8913-37dd51a80c0c";
  fsType = "btrfs";
  options = [
    "defaults"
    "nofail"
    "x-systemd.device-timeout=5s"
  ];
};

  programs.steam = {
  enable = true;
  remotePlay.openFirewall = true;       # Steam Remote Play
  dedicatedServer.openFirewall = true;  # Source Dedicated Server
  protontricks.enable = true;
};
  programs.gamescope = {
    enable = true;
};
programs.thunar = {
    enable = true;
    plugins = with pkgs.xfce; [
      thunar-archive-plugin   # right-click extract/compress
      thunar-volman           # auto-mount USB/SD/optical
      thunar-media-tags-plugin  # edit audio tags
    ];
  };
  
  services.displayManager.sddm = {
  enable = true;
  wayland.enable = true;
};

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    google-fonts
];
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  neovim
  (rofi.override { plugins = [ pkgs.rofi-calc ]; })
  fastfetch

  ffmpegthumbnailer       # video thumbnails
  webp-pixbuf-loader      # webp thumbnails
  file-roller             # GUI archive manager
  
#game launchers
  prismlauncher
  wivrn
  git
  qview
  unzip

  libreoffice

  yazi

  btop
  lm_sensors

  ffmpegthumbnailer  # video thumbnails
  unar               # archive previews
  jq                 # JSON previews
  poppler            # PDF previews
  fd                 # fast find (used by yazi's search)
  ripgrep            # fast grep (used by yazi's search)
  fzf                # fuzzy finder integration
  zoxide             # smart cd integration
  imagemagick        # image conversion for previews

  swww
  alacritty
  xwayland-satellite
  wl-clipboard
  quickshell
  brightnessctl
  swaylock
  mako
  vesktop
  kitty
  floorp-bin
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
  ];
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
    xdg-desktop-portal-gtk
    xdg-desktop-portal-gnome
  ];
};

security.rtkit.enable = true;
services.pipewire = {
  enable = true;
  alsa.enable = true;
  alsa.support32Bit = true;
  pulse.enable = true;
};
services.udisks2.enable = true;
services.devmon.enable = true;
services.gvfs.enable = true;      # trash, mounting, network shares
services.tumbler.enable = true;   # thumbnail generation daemon
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
