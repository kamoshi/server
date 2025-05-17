{ config, pkgs, ... }:
{
  # System security
  # ----------
  sops.secrets.kotori = {
    mode = "0400";
  };

  # Kotori
  # ----------
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
          environmentFiles = [ config.sops.secrets.kotori.path ];
          autoStart = true;
        };
      };
    };
  };
}
