{ config, pkgs, lib, mesh, ... }:
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

        inherit (mesh) devices folders;
        # devices = {
        #   "aya" = {
        #     id = "K53ML2R-XXPRH3Z-SB7RKVP-UZCWTDA-636J5O4-442XL3U-O7ZA7Y4-K4THEQY";
        #   };
        #   "momiji" = {
        #     id = "Q3QI722-QQL5J5Y-7MZJM54-BF2ZVYD-ZF25RJW-MH7OIJK-6QRCKBZ-KT6V4QF";
        #   };
        #   "hatate" = {
        #     id = "IF63A73-XV6LEZS-UZH7DEU-CPOJVEN-OQ3CEWZ-KHVNC5U-KNFCLLD-S7MOXAW";
        #   };
        #   "nitori" = {
        #     id = "4SIJHMJ-6RR5KGV-E53GPIR-MJOZ3PO-4KSKIXP-T7DYO3J-2AP2TGI-GD524A6";
        #   };
        # };
        # folders = {
        #   "Nix" = {
        #     id = "nix";
        #     path = "~/nix";
        #     devices = [ "aya" "momiji" "nitori" ];
        #   };
        #   "Photos" = {
        #     id = "y963t-gpuhn";
        #     path = "/data/sync/photos";
        #     devices = [ "momiji" ];
        #   };
        #   "Obsidian" = {
        #     id = "g2lzf-m5eu9";
        #     path = "/data/sync/obsidian";
        #     devices = [ "aya" "momiji" "hatate" ];
        #   };
        #   "Website" = {
        #     id = "bwy5c-xydvs";
        #     path = "/data/sync/website";
        #     devices = [ "aya" "momiji" ];
        #   };
        #   "Workspace" = {
        #     id = "workspace";
        #     path = "/data/sync/workspace";
        #     devices = [ "aya" "momiji" ];
        #   };
        # };
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
