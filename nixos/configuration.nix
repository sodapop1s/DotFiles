#This is my config for NixOS, it has the basic packages i use everyday aswell as DMS
#
#as of July 8th 2026 a complete rewrite has been done to unvibe code a lot of this
#
#
#

#-----------------------------------
{ config, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelModules = [ "nct6683" ];

  networking.hostName = "nixos"; # Every computer with NixOS has this username for simplicity
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  

#--------------------------------
#VIBE CODED AND NOT REWRITTEN YET
#--------------------------------
programs.nix-ld = {
  enable = true;
  libraries = with pkgs; [
    icu        # CoreCLR needs libicu — common cause of 0x80004005
    openssl
    zlib
    stdenv.cc.cc.lib   # libstdc++/libgcc
  ];
};

#
  #--------------
  # Core Settings
  #--------------
  services.flatpak.enable = true;
  # networking
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [ 11434 2049 46000 ]; # only works when home, 2049 is omalla
  networking.firewall.allowedUDPPorts = [ 46000 ]; # RTP from Steam Deck
  networking.firewall.extraInputRules = ''ip saddr 192.168.1.0/24 tcp dport 11434 accept''; # this only works when home / think about removing

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  swapDevices = [{
    device = "/var/lib/swapfile";
    size = 16 * 1024;
  }];
  time.timeZone = "America/New_York";
  nixpkgs.config.allowUnfree = true;


  # Configure keymap in X11 
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
  # Define a user account
  users.users.soda = {
    isNormalUser = true;
    description = "Soda";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
  };

  programs.niri.enable = true;

 # this enables my external hard drive
  fileSystems."/mnt/external" = {
    device = "/dev/disk/by-uuid/869cb7b4-fc80-454f-8913-37dd51a80c0c";
    fsType = "btrfs";
    options = [
      "defaults"
      "nofail"
      "x-systemd.device-timeout=5s"
    ];
  };

  #-----------------
  # Visual Settings  
  #-----------------

  programs.dank-material-shell = {
    enable = true;
    enableSystemMonitoring = true;
    dgop.package = inputs.dgop.packages.${pkgs.system}.default;
  };
  
  # This is the package to configure the RGB on the main desktop computer
  services.hardware.openrgb = {
    enable = true;
    package = pkgs.openrgb-with-all-plugins;
    motherboard = "amd";
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    google-fonts
  ];
  #-------------------
  # Important Services
  #-------------------

  # Used to run Bigger models locally when the gpu in the current homelab is insuffecient
  services.ollama = {
    enable = true;
    acceleration = "rocm";        # AMD GPU path
    host = "0.0.0.0";             # listen on the LAN, not just localhost
    port = 11434;

    environmentVariables = {
    ROCR_VISIBLE_DEVICES = "0";
    OLLAMA_FLASH_ATTENTION = "1";
    OLLAMA_KV_CACHE_TYPE = "q8_0";
  };
};
  
  # Bullshit rabbit hole I went down for a game and I cant remember -- look into this at some point. This will stay vibe coded for now
  programs.steam = {
  enable = true;
  remotePlay.openFirewall = true;       # Steam Remote Play
  dedicatedServer.openFirewall = true;  # Source Dedicated Server
  protontricks.enable = true;
  extraCompatPackages = [ pkgs.proton-ge-bin ];
  };
  programs.gamescope = {
    enable = true;
  };
  # Fall back file manager for when needing to have someone access the computer and I am not nearby
  programs.thunar = {
    enable = true;
    plugins = with pkgs.xfce; [
      thunar-archive-plugin   # right click 
      thunar-volman           # auto-mount USB/SD/optical
      thunar-media-tags-plugin  # edit audio tags
    ];
  };
  
  services.displayManager.sddm = {
  enable = true;
  wayland.enable = true;
};
  # a more complex install than defaul by a slight amount
  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-pipewire-audio-capture
    ];
  };

  #-------------------
  # System Packages
  #-------------------

  # this is a cluster fuck and a lot was not commented so i will try my best to figure it out
  environment.systemPackages = with pkgs; [

  # Important Base Packages
  neovim 
  fastfetch
  git
  unzip
  yazi   # Main file manager
  qview  # For loading images
  brightnessctl # Used by the laptop
  kitty     # Prefered terminal
  alacritty # niri's default incase the config fails to load
  wl-clipboard
  quickshell
  xwayland-satellite
  claude-code
  (btop.override { rocmSupport = true; })
  
  # Random vibe coded dependecies that i dont know what theyre for
  webp-pixbuf-loader # webp thumbnails
  file-roller        # GUI archive manager
  ffmpegthumbnailer  # video thumbnails
  unar               # archive previews
  jq                 # JSON previews
  poppler            # PDF previews
  fd                 # fast find (used by yazi's search)
  ripgrep            # fast grep (used by yazi's search)
  fzf                # fuzzy finder integration
  zoxide             # smart cd integration
  imagemagick        # image conversion for previews
  gh                 # GitHub CLI, needed by Octo

  #Game Launchers
  prismlauncher
  wivrn  # Quest 3 support
  olympus
  
  # Programs
  floorp-bin
  kdePackages.kdenlive
  vesktop


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
  extraConfig.pipewire."99-deck-lan" = {
    "context.modules" = [
      {
        name = "libpipewire-module-rtp-source";
        args = {
          "source.ip" = "0.0.0.0";
          "source.port" = 46000;
          "sess.latency.msec" = 200;
          "audio.format" = "S16BE";
          "audio.rate" = 48000;
          "audio.channels" = 2;
          "stream.props" = { "node.name" = "deck-rtp"; "media.class" = "Audio/Source"; };
        };
      }
      {
        name = "libpipewire-module-loopback";
        args = {
          "node.description" = "Steam Deck In";
          "capture.props"."node.target" = "deck-rtp";
          "playback.props"."node.name" = "deck-loopback-out";
        };
      }
    ];
  };
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
