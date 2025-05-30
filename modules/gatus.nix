{ config, pkgs, lib, ... }:
let
  cfg = config.kamov.gatus;
in {
  options.kamov.gatus = {
    enable = lib.mkEnableOption "Enable Gatus";

    port = lib.mkOption {
      type = lib.types.port;
      description = "Port for Gatus";
    };

    bind = lib.mkOption {
      type = lib.types.str;
      description = "Bind address for Gatus";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Nginx domain";
    };
  };

  config = lib.mkIf cfg.enable {
    services.gatus = {
      enable = true;

      settings = {
        web = {
          port = cfg.port;
          address = cfg.bind;
        };

        ui = {
          title = "Healthcheck";
          header = "Services Health";
          logo = "https://kamoshi.org/static/svg/aya.svg";
          link = "https://kamoshi.org";
          custom-css = "#social { display: none; }";
        };

        endpoints = [
          {
            name = "Website";
            url = "https://kamoshi.org/";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
          }
          {
            name = "Auth";
            url = "https://auth.kamoshi.org/status";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
              "[BODY] == true"
            ];
          }
          {
            name = "Miniflux";
            url = "https://rss.kamoshi.org/healthcheck";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
          }
          {
            name = "Forgejo";
            url = "https://git.kamoshi.org/api/healthz";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
              "[BODY].status == pass"
              "[BODY].checks.cache:ping[0].status == pass"
              "[BODY].checks.database:ping[0].status == pass"
            ];
          }
        ];
      };
    };

    services.nginx.virtualHosts."${cfg.domain}" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://${cfg.bind}:${toString cfg.port}";
      };
    };
  };
}
