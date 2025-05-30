{ config, pkgs, lib, ... }:
let
  certs = config.security.acme.certs."auth.kamoshi.org";
in {
  services.kanidm = {
    package = pkgs.kanidmWithSecretProvisioning;

    enableServer = true;
    serverSettings = {
      domain = "auth.kamoshi.org";
      origin = "https://auth.kamoshi.org";
      tls_chain = "${certs.directory}/fullchain.pem";
      tls_key   = "${certs.directory}/key.pem";
      trust_x_forward_for = true;
      bindaddress = "127.0.0.1:8443";

      online_backup = {
        path = "/var/backup/kanidm/";
        schedule = "0 20 * * *"; # UTC time
        versions = 2;
      };
    };

    enableClient = true;
    clientSettings = {
      uri = "https://auth.kamoshi.org";
    };

    provision = {
      enable = true;
      autoRemove = true;

      persons = {
        kamov = {
          displayName = "kamov";
          mailAddresses = [ "maciej@kamoshi.org" ];
          groups = [
            "miniflux.access"
            "forgejo.access"
            "forgejo.admins"
          ];
        };
      };

      groups = {
        # Miniflux
        "miniflux.access" = {};
        # Forgejo
        "forgejo.access" = {};
        "forgejo.admins" = {};
      };

      systems.oauth2 = {
        miniflux = {
          displayName = "Miniflux";
          originUrl = "https://rss.kamoshi.org/oauth2/oidc/callback";
          originLanding = "https://rss.kamoshi.org/oauth2/oidc/redirect";
          basicSecretFile = config.sops.secrets."kanidm/miniflux".path;
          preferShortUsername = true;
          scopeMaps = {
            "miniflux.access" = [ "openid" "profile" "email" ];
          };
        };
        forgejo = {
          displayName = "Forgejo";
          originUrl = "https://git.kamoshi.org/user/oauth2/kanidm/callback";
          originLanding = "https://git.kamoshi.org/user/oauth2/kanidm";
          basicSecretFile = config.sops.secrets."kanidm/forgejo".path;
          preferShortUsername = true;
          scopeMaps = {
            "forgejo.access" = [ "openid" "profile" "email" ];
          };
          claimMaps.groups = {
            joinType = "array";
            valuesByGroup."forgejo.admins" = [ "admin" ];
          };
        };
      };
    };
  };

  systemd.services.kanidm = {
    after = [ "acme-selfsigned-auth.kamoshi.org.target" ];
    serviceConfig = {
      SupplementaryGroups = [ certs.group ];
      BindReadOnlyPaths   = [ certs.directory ];
      BindPaths           = [ "/var/lib/kanidm" ];
    };
  };

  # Backup
  # ----------
  services.restic.backups.daily.paths = [
    "/var/backup/kanidm/"
  ];

  # Network
  # ----------
  # networking.firewall = {
  #   enable = true;
  #   interfaces.wg0.allowedTCPPorts = [ 8443 ];
  # };

  services.nginx.virtualHosts."auth.kamoshi.org" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "https://127.0.0.1:8443";
    };
  };
}
