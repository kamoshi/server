{ config, pkgs, ... }:
{
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
          environmentFiles = [ /root/.secrets/kotori.env ];
          autoStart = true;
        };
      };
    };
  };
}
