{ config, pkgs, ... }:
{
  services.miniflux = {
    enable = true;
    config = {
      LISTEN_ADDR = "10.0.0.1:2137";
      BASE_URL = "https://rss.kamoshi.org/";
      RUN_MIGRATIONS = 1;
      CREATE_ADMIN = 0;
    };
  };

  networking.firewall = {
    enable = true;
    interfaces.wg0.allowedTCPPorts = [ 2137 ];
  };

  services.nginx.virtualHosts."rss.kamoshi.org" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://10.0.0.1:2137";
    };
  };
}
