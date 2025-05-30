{ config, pkgs, lib, ... }:
let
  cfg = config.kamov.miniflux;
in {
  options.kamov.miniflux = {
    enable = lib.mkEnableOption "Enable Miniflux";

    port = lib.mkOption {
      type = lib.types.port;
      description = "Port for Miniflux.";
    };

    bind = lib.mkOption {
      type = lib.types.str;
      description = "Bind address for Miniflux.";
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

    # Miniflux
    # ----------
    services.miniflux = {
      enable = true;
      config = {
        LISTEN_ADDR = "${cfg.bind}:${toString cfg.port}";
        BASE_URL = "https://${cfg.domain}/";
        RUN_MIGRATIONS = 1;
        CREATE_ADMIN = 0;
        CLEANUP_ARCHIVE_UNREAD_DAYS = "-1";
        CLEANUP_ARCHIVE_READ_DAYS = "-1";
        POLLING_FREQUENCY = 480;

        # OIDC
        OAUTH2_PROVIDER = "oidc";
        OAUTH2_CLIENT_ID = "miniflux";
        OAUTH2_CLIENT_SECRET_FILE = cfg.oauthSecretPath;
        OAUTH2_REDIRECT_URL = "https://${cfg.domain}/oauth2/oidc/callback";
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
      interfaces.wg0.allowedTCPPorts = [ cfg.port ];
    };

    services.nginx.virtualHosts."${cfg.domain}" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://${cfg.bind}:${toString cfg.port}";
      };
    };

    # services.fail2ban.jails = {
    #   miniflux = ''
    #     enabled = true
    #     filter = miniflux
    #     port = http,https
    #   '';
    # };

    # environment.etc = {
    #   "fail2ban/filter.d/miniflux.conf".text = ''
    #     [Definition]
    #     failregex = ^.*msg="[^"]*(Incorrect|Invalid) username or password[^"]*".*client_ip=<ADDR>
    #     journalmatch = _SYSTEMD_UNIT=miniflux.service
    #   '';
    # };

    # Database
    # ----------
    services.postgresqlBackup.databases = [
      "miniflux"
    ];
  };
}
