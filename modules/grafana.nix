# https://github.com/oddlama/nix-config/blob/main/hosts/sire/guests/grafana.nix
{ config, pkgs, lib, ... }:
let
  cfg = config.kamov.grafana;
in {
  options.kamov.grafana = {
    enable = lib.mkEnableOption "Enable Grafana";

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Nginx domain";
    };

    port = lib.mkOption {
      type = lib.types.port;
      description = "Port for Grafana";
    };

    bind = lib.mkOption {
      type = lib.types.str;
      description = "Bind address for Grafana";
    };
  };

  config = lib.mkIf cfg.enable {
    services.grafana = {
      enable = true;

      settings = {
        # Prevents Grafana from phoning home
        analytics.reporting_enabled = false;
        users.allow_sign_up = false;

        server = {
          domain = cfg.domain;
          root_url = "https://${cfg.domain}";
          enforce_domain = true;
          enable_gzip = true;
          http_addr = cfg.bind;
          http_port = cfg.port;
        };

        security = {
          disable_initial_admin_creation = true;
          secret_key = "$__file{${config.sops.secrets."grafana/secret_key".path}}";
          cookie_secure = true;
          disable_gravatar = true;
        };

        "auth.anonymous" = {
          enabled = false;
          hide_version = true;
        };

        auth.disable_login_form = true;
        "auth.generic_oauth" = {
          enabled = true;
          name = "Arstotzka";
          icon = "signin";
          allow_sign_up = true;
          #auto_login = true;
          client_id = "grafana";
          client_secret = "$__file{${config.sops.secrets."grafana/client_secret".path}}";
          scopes = "openid email profile";
          login_attribute_path = "preferred_username";
          auth_url = "https://auth.kamoshi.org/ui/oauth2";
          token_url = "https://auth.kamoshi.org/oauth2/token";
          api_url = "https://auth.kamoshi.org/oauth2/openid/grafana/userinfo";
          use_pkce = true;
          # Allow mapping oauth2 roles to server admin
          allow_assign_grafana_admin = true;
          role_attribute_path = "contains(groups[*], 'server_admin') && 'GrafanaAdmin' || contains(groups[*], 'admin') && 'Admin' || contains(groups[*], 'editor') && 'Editor' || 'Viewer'";
        };
      };
    };

    services.nginx.virtualHosts."${cfg.domain}" = {
      addSSL = true;
      enableACME = true;

      locations."/" = {
          proxyPass = "http://${cfg.bind}:${toString cfg.port}";
          proxyWebsockets = true;
          recommendedProxySettings = true;
      };
    };
  };
}
