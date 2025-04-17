{ config, pkgs, ... }:
{
  services.syncthing = {
    enable = true;
    user = "kamov";
    group = "users";
    openDefaultPorts = false;
    configDir = "/home/kamov/.config/syncthing";
    # wg0 address
    guiAddress = "10.0.0.1:8384";

    settings = {
      gui = {
        enabled = true;
        user = "kamov";
        password = "kamov";
      };
      devices = {
        "arch" = {
          id = "Q3QI722-QQL5J5Y-7MZJM54-BF2ZVYD-ZF25RJW-MH7OIJK-6QRCKBZ-KT6V4QF";
        };
        "xiaomi" = {
          id = "C5MES7V-2QNWNA2-AYGIW2L-CBXJ7QX-D2UPQP2-SM6EDAW-ZWMHDOV-MVTSUQN";
        };
      };
      folders = {
        "Photos" = {
          id = "y963t-gpuhn";
          path = "/home/kamov/Sync/Photos";
          devices = [ "arch" "xiaomi" ];
        };
        "Obsidian" = {
          id = "g2lzf-m5eu9";
          path = "/home/kamov/Sync/Obsidian";
          devices = [ "arch" "xiaomi" ];
        };
      };
    };
  };

  # Syncthing ports: 8384 for remote access to GUI
  # 22000 TCP and/or UDP for sync traffic
  # 21027/UDP for discovery
  # source: https://docs.syncthing.net/users/firewall.html
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22000 ];
    allowedUDPPorts = [ 22000 21027 ];
    interfaces.wg0.allowedTCPPorts = [ 8384 ];
  };

  # Don't create default ~/Sync folder
  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";
}
