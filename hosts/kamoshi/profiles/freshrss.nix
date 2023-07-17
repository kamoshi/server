{ config, pkgs, ... }:
let 
  address = "rss.kamoshi.org";
in
{
  services = {
    freshrss = {
      enable = true;
      defaultUser = "admin";
      # There's something wrong with this
      # Workaround: https://github.com/FreshRSS/FreshRSS/issues/1082
      passwordFile = "/root/secrets/freshrss/password";
      baseUrl = "https://${address}";
      virtualHost = address;
      database.type = "sqlite";
    };
    nginx = {
      enable = true;
      virtualHosts."${address}" = {
        forceSSL = true;
        enableACME = true;
      };
    };
  };
}

