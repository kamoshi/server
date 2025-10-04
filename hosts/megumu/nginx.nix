{ config, pkgs, ... }:
{
  # Group for people who can edit the website
  users.groups.www = {};

  # Directory for web content
  systemd.tmpfiles.rules = [
    "d /var/www/kamoshi.org 775 kamov www"
    "d /var/www/sejm 775 kamov www"
  ];

  # Automatically renew certs
  security.acme = {
    acceptTerms = true;
    defaults.email = "maciej@kamoshi.org";
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services = {
    nginx = {
      enable = true;
      recommendedTlsSettings = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;

      virtualHosts."_" = {
        default = true;

        extraConfig = ''
          default_type text/html;
          return 418 '
          <html>
          <head><title>418 I\'m a teapot</title></head>
          <body bgcolor="white">
            <center><h1>418 I\'m a teapot</h1></center>
            <hr><center>teapot/0.4.11</center>
          </body>
          </html>
          ';
        '';
      };

      virtualHosts."kamoshi.org" = {
        root = "/var/www/kamoshi.org";
        forceSSL = true;
        enableACME = true;

        listen = [
          { addr = "[::]";    port = 80; ssl = false; }
          { addr = "0.0.0.0"; port = 80; ssl = false; }
          { addr = "[::]";    port = 443; ssl = true; }
          { addr = "0.0.0.0"; port = 443; ssl = true; }
        ];
      };

      virtualHosts."sejm.kamoshi.org" = {
        root = "/var/www/sejm";
        forceSSL = true;
        enableACME = true;

        locations."/" = {
          tryFiles = "$uri $uri/ /index.html";
        };

        listen = [
          { addr = "[::]";    port = 80; ssl = false; }
          { addr = "0.0.0.0"; port = 80; ssl = false; }
          { addr = "[::]";    port = 443; ssl = true; }
          { addr = "0.0.0.0"; port = 443; ssl = true; }
        ];
      };
    };
  };
}
