{ config, pkgs, ... }:
{
  virtualisation = {
    docker.enable = true;
    oci-containers = {
      backend = "docker";
      containers = {
        kotori = {
          image = "kamov/kotori";
          environmentFiles = [ /root/secrets/kotori.env ];
          autoStart = true;
        };
      };
    };
  };
}
