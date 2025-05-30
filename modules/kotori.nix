{ config, pkgs, lib, ... }:
let
  cfg = config.kamov.kotori;
in {
  options.kamov.kotori = {
    enable = lib.mkEnableOption "Enable Kotori";

    envPath = lib.mkOption {
      type = lib.types.path;
      description = "Config env path.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation = {
      podman = {
        enable = true;
        dockerCompat = true;
      };
      oci-containers = {
        backend = "podman";
        containers = {
          kotori = {
            image = "kamov/kotori:latest";
            serviceName = "podman-kotori";
            environmentFiles = [ cfg.envPath ];
            autoStart = true;
          };
        };
      };
    };
  };
}
