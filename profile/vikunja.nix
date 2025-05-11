{ config, lib, ... }:
{
  # Vikunja
  # ----------
  services.vikunja = {
    enable = true;
    port = 6969;
    frontendScheme = "http";
    frontendHostname = "10.0.0.1";

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
  # ----------
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

  # Backup
  # ----------
  services.postgresqlBackup.databases = [
    "vikunja"
  ];

  # Network
  # ----------
  networking.firewall = {
    enable = true;
    interfaces.wg0.allowedTCPPorts = [ 6969 ];
  };

  services.nginx.virtualHosts."todo.kamoshi.org" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://10.0.0.1:6969";
    };
  };

  # System
  # ----------
  users = {
    groups.vikunja = { };

    users."vikunja" = {
      group = "vikunja";
      createHome = false;
      isSystemUser = true;
    };
  };
}
