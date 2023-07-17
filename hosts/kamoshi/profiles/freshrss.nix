{ config, pkgs, ... }:
let 
  address = "rss.kamoshi.org";
in
{
  services = {
    freshrss = {
      defaultUser = "kamov";
      passwordFile = "/root/secrets/freshrss/password";
      baseUrl = "https://${address}";
      virtualHost = address;
      database.type = "sqlite";
    };
    nginx = {
      enable = true;
      virtualHosts."${address}" = {
        addSSL = true;
        enableACME = true;
      };
    };
  };
}

