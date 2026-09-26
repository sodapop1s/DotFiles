{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../common.nix
  ];

  networking.hostName = "soda-desk";

  swapDevices = [{
    device = "/var/lib/swapfile";
    size   = 16 * 1024;
  }];

  # RGB control
  services.hardware.openrgb = {
    enable      = true;
    package     = pkgs.openrgb-with-all-plugins;
    motherboard = "amd";
  };

  # Local LLM inference via AMD GPU
  services.ollama = {
    enable       = true;
    acceleration = "rocm";
    host         = "0.0.0.0";
    port         = 11434;
    environmentVariables = {
      ROCR_VISIBLE_DEVICES   = "0";
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KV_CACHE_TYPE   = "q8_0";
    };
  };

  # Firewall: Ollama LAN, NFS, Steam Deck RTP
  networking.firewall.allowedTCPPorts   = [ 11434 2049 46000 ];
  networking.firewall.allowedUDPPorts   = [ 46000 ];
  networking.firewall.extraInputRules   = ''ip saddr 192.168.1.0/24 tcp dport 11434 accept'';

  # Steam Deck LAN audio via RTP
  services.pipewire.extraConfig.pipewire."99-deck-lan" = {
    "context.modules" = [
      {
        name = "libpipewire-module-rtp-source";
        args = {
          "source.ip"        = "0.0.0.0";
          "source.port"      = 46000;
          "sess.latency.msec" = 200;
          "audio.format"     = "S16BE";
          "audio.rate"       = 48000;
          "audio.channels"   = 2;
          "stream.props"     = {
            "node.name"   = "deck-rtp";
            "media.class" = "Audio/Source";
          };
        };
      }
      {
        name = "libpipewire-module-loopback";
        args = {
          "node.description"              = "Steam Deck In";
          "capture.props"."node.target"   = "deck-rtp";
          "playback.props"."node.name"    = "deck-loopback-out";
        };
      }
    ];
  };

  # btop with ROCm GPU monitoring
  environment.systemPackages = with pkgs; [
    (btop.override { rocmSupport = true; })
  ];
}
