{ config, pkgs, lib, ... }:
let
  domain = "git.kamoshi.org";
  user   = "git";
  state  = "/var/lib/forgejo";
in
{
  users = {
    users.${user} = {
      description     = "Forgejo Service";
      home            = state;
      group           = user;
      useDefaultShell = true;
      isSystemUser    = true;
    };
    groups.${user} = {};
  };

  services = {
    forgejo = {
      enable = true;
      user   = user;
      group  = user;
      stateDir = state;
      # https://forgejo.org/docs/latest/admin/config-cheat-sheet/
      settings = {
        server = {
          HTTP_PORT = 3200;
          HTTP_ADDR = "127.0.0.1";
          DOMAIN = domain;
          ROOT_URL = "https://${domain}/";
          LANDING_PAGE = "explore";
        };

        service = {
          DISABLE_REGISTRATION = lib.mkForce true;
        };
      };
    };

    nginx.virtualHosts.${domain} = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:3200/";
      };
    };
  };
}
