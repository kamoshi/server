{ config, pkgs, lib, ... }:
let
  cfg = config.kamov.kanidm;
  certs = config.security.acme.certs."${cfg.domain}";
in {
  options.kamov.kanidm = {
    enable = lib.mkEnableOption "Enable Kanidm";

    port = lib.mkOption {
      type = lib.types.port;
      description = "Port for Kanidm";
    };

    bind = lib.mkOption {
      type = lib.types.str;
      description = "Bind address for Kanidm";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Nginx domain";
    };

    oauthSecretPath = lib.mkOption {
      type = lib.types.path;
      description = "OAuth secret path.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.kanidm = {
      package = pkgs.kanidmWithSecretProvisioning;

      enableServer = true;
      serverSettings = {
        domain = cfg.domain;
        origin = "https://${cfg.domain}";
        tls_chain = "${certs.directory}/fullchain.pem";
        tls_key   = "${certs.directory}/key.pem";
        trust_x_forward_for = true;
        bindaddress = "${cfg.bind}:${toString cfg.port}";

        online_backup = {
          path = "/var/backup/kanidm/";
          schedule = "0 20 * * *"; # UTC time
          versions = 2;
        };
      };

      enableClient = true;
      clientSettings = {
        uri = "https://${cfg.domain}";
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

              "grafana.access"
              "grafana.admins"
            ];
          };
        };

        groups = {
          # Miniflux
          "miniflux.access" = {};
          # Forgejo
          "forgejo.access" = {};
          "forgejo.admins" = {};
          # Vikunja
          # "vikunja.access" = {};
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
          # vikunja = {
          #   displayName = "Vikunja";
          #   originUrl = "https://kanban.kamoshi.org/auth/openid/";
          #   originLanding = "https://kanban.kamoshi.org";
          #   preferShortUsername = true;
          #   scopeMaps = {
          #     "miniflux.access" = [ "openid" "profile" "email" ];
          #   };
          # };
        };

        # Grafana
        groups."grafana.access" = { };
        groups."grafana.editors" = { };
        groups."grafana.admins" = { };
        groups."grafana.server-admins" = { };
        systems.oauth2.grafana = {
          displayName = "Grafana";
          originUrl = "https://data.kamoshi.org/login/generic_oauth";
          originLanding = "https://data.kamoshi.org/login/generic_oauth";
          basicSecretFile = config.sops.secrets."grafana/client_secret".path;
          preferShortUsername = true;
          scopeMaps."grafana.access" = [ "openid" "email" "profile" ];
          claimMaps.groups = {
            joinType = "array";
            valuesByGroup = {
              "grafana.editors" = [ "editor" ];
              "grafana.admins" = [ "admin" ];
              "grafana.server-admins" = [ "server_admin" ];
            };
          };
        };
      };
    };

    systemd.services.kanidm = {
      after = [ "acme-selfsigned-${cfg.domain}.target" ];
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
    services.nginx.virtualHosts."${cfg.domain}" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "https://${cfg.bind}:${toString cfg.port}";
      };
    };
  };
}
