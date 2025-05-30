{ config, pkgs, lib, ... }:
let
  cfg = config.kamov.syncthing;
in {
  options.kamov.syncthing = {
    enable = lib.mkEnableOption "Enable Syncthing";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8384;
      description = "Port for the Syncthing GUI.";
    };

    bind = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "IP for Syncthing GUI to bind to.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "kamov";
      description = "User to run Syncthing under.";
    };

    configDir = lib.mkOption {
      type = lib.types.path;
      default = "/home/kamov/.config/syncthing";
      description = "Configuration directory for Syncthing.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      user = cfg.user;
      group = "users";
      openDefaultPorts = false;
      configDir = cfg.configDir;
      guiAddress = "${cfg.bind}:${toString cfg.port}";

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
          "Website" = {
            id = "bwy5c-xydvs";
            path = "/home/kamov/Sync/Website";
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
      interfaces.wg0.allowedTCPPorts = [ cfg.port ];
    };

    # Don't create default ~/Sync folder
    systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";
  };
}
