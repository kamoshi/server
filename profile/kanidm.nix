{ config, pkgs, lib, ... }:
let
  certs = config.security.acme.certs."auth.kamoshi.org";
in {
  services.kanidm = {
    package = pkgs.kanidm_1_5;

    enableServer = true;
    serverSettings = {
      domain = "auth.kamoshi.org";
      origin = "https://auth.kamoshi.org";
      tls_chain = "${certs.directory}/fullchain.pem";
      tls_key   = "${certs.directory}/key.pem";
      trust_x_forward_for = true;
      bindaddress = "127.0.0.1:8443";

      online_backup = {
        path = "/var/lib/private/kanidm/backups/";
        schedule = "0 22 * * *";
        versions = 7;
      };
    };

    enableClient = true;
    clientSettings = {
      uri = "https://auth.kamoshi.org";
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
    "/var/lib/private/kanidm/backups/"
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
