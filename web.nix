{ config, pkgs, ... }:
{
  # Group for people who can edit the website
  users.groups.www = {};

  # Directory for web content
  systemd.tmpfiles.rules = [
    "d /var/www/kamoshi.org 775 root www"
  ];

  # Automatically renew certs
  security.acme = {
    acceptTerms = true;
    defaults.email = "maciej@kamoshi.org";
  };

  services = {
    nginx = {
      enable = true;
      recommendedTlsSettings = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      virtualHosts = {
        "kamoshi.org" = {
          root = "/var/www/kamoshi.org";
          forceSSL = true;
          enableACME = true;
        };
      };
    };
  };
}
