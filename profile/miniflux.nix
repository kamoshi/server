{ config, pkgs, ... }:
{
  # System security
  # ----------
  users.groups.miniflux = {};
  users.users.miniflux = {
    isSystemUser = true;
    createHome = false;
    group = "miniflux";
  };

  systemd.services.miniflux = {
    serviceConfig = {
      User  = "miniflux";
      Group = "miniflux";
    };
  };

  sops.secrets."kanidm/miniflux" = {
    owner = "miniflux";
    group = "miniflux";
    mode = "0400";
  };

  # Miniflux
  # ----------
  services.miniflux = {
    enable = true;
    config = {
      LISTEN_ADDR = "10.0.0.1:2137";
      BASE_URL = "https://rss.kamoshi.org/";
      RUN_MIGRATIONS = 1;
      CREATE_ADMIN = 0;
      CLEANUP_ARCHIVE_UNREAD_DAYS = "-1";
      CLEANUP_ARCHIVE_READ_DAYS = "-1";
      POLLING_FREQUENCY = 480;

      # OIDC
      OAUTH2_PROVIDER = "oidc";
      OAUTH2_CLIENT_ID = "miniflux";
      OAUTH2_CLIENT_SECRET_FILE = config.sops.secrets."kanidm/miniflux".path;
      OAUTH2_REDIRECT_URL = "https://rss.kamoshi.org/oauth2/oidc/callback";
      OAUTH2_OIDC_DISCOVERY_ENDPOINT = "https://auth.kamoshi.org/oauth2/openid/miniflux";

      # Disable local auth
      DISABLE_LOCAL_AUTH = "true";
      OAUTH2_USER_CREATION = "true";
    };
  };

  # Network
  # ----------
  networking.firewall = {
    enable = true;
    interfaces.wg0.allowedTCPPorts = [ 2137 ];
  };

  services.nginx.virtualHosts."rss.kamoshi.org" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://10.0.0.1:2137";
    };
  };

  services.fail2ban.jails = {
    miniflux = ''
      enabled = true
      filter = miniflux
      port = http,https
    '';
  };

  environment.etc = {
    "fail2ban/filter.d/miniflux.conf".text = ''
      [Definition]
      failregex = ^.*msg="[^"]*(Incorrect|Invalid) username or password[^"]*".*client_ip=<ADDR>
      journalmatch = _SYSTEMD_UNIT=miniflux.service
    '';
  };

  # Database
  # ----------
  services.postgresqlBackup.databases = [
    "miniflux"
  ];
}
