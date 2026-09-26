{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../common.nix
  ];

  networking.hostName = "soda-fw";

  # ESP is only 96MB, shared with Windows — keep the count low
  boot.loader.systemd-boot.configurationLimit = 3;

  # Bluetooth
  hardware.bluetooth.enable      = true;
  hardware.bluetooth.powerOnBoot = true;

  # Restrict BT to A2DP only (no headset mic / HFP profile)
  services.pipewire.wireplumber.extraConfig."51-bluez-a2dp-only" = {
    "monitor.bluez.properties" = {
      "bluez5.roles" = [ "a2dp_sink" "a2dp_source" ];
    };
  };

  # Plain btop — no ROCm dependency on the laptop
  environment.systemPackages = with pkgs; [ btop ];
}
