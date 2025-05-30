{ config, pkgs, lib, ... }:
let
  cfg = config.kamov.vikunja;
in {
  options.kamov.vikunja = {
    enable = lib.mkEnableOption "Enable Vikunja";

    port = lib.mkOption {
      type = lib.types.port;
      description = "Port for Vikunja";
    };

    bind = lib.mkOption {
      type = lib.types.str;
      description = "Bind address for Vikunja";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Nginx domain";
    };
  };

  config = lib.mkIf cfg.enable {
    # System
    # ------
    users = {
      groups.vikunja = { };

      users."vikunja" = {
        group = "vikunja";
        createHome = false;
        isSystemUser = true;
      };
    };

    # Vikunja
    # -------
    services.vikunja = {
      enable = true;
      port = cfg.enable;
      frontendScheme = "http";
      frontendHostname = cfg.bind;

      database = {
        type = "postgres";
        host = "/run/postgresql";
        user = "vikunja";
        database = "vikunja";
      };

      settings = {
        service.enableregistration = false;
      };
    };

    # Postgres
    # --------
    services.postgresql = {
      enable = true;

      ensureDatabases = [
        "vikunja"
      ];

      ensureUsers = [
        {
          name = "vikunja";
          ensureDBOwnership = true;
        }
      ];
    };

    services.postgresqlBackup.databases = [
      "vikunja"
    ];

    # Network
    # -------
    networking.firewall = {
      enable = true;
      interfaces.wg0.allowedTCPPorts = [ cfg.port ];
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
