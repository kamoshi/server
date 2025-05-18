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

  sops.secrets."kanidm/forgejo" = {
    owner = "git";
    group = "kanidm";
    mode = "0440";
  };

  services = {
    forgejo = {
      enable = true;
      package = pkgs.forgejo;
      user   = user;
      group  = user;
      stateDir = state;
      # https://forgejo.org/docs/latest/admin/config-cheat-sheet/
      settings = {
        DEFAULT.APP_NAME = "Git";
        oauth2_client = {
          # Never use auto account linking with this, otherwise users cannot change
          # their new user name and they could potentially overtake other users accounts
          # by setting their email address to an existing account.
          # With "login" linking the user must choose a non-existing username first or login
          # with the existing account to link.
          ACCOUNT_LINKING = "login";
          USERNAME = "nickname";
          # This does not mean that you cannot register via oauth, but just that there should
          # be a confirmation dialog shown to the user before the account is actually created.
          # This dialog allows changing user name and email address before creating the account.
          ENABLE_AUTO_REGISTRATION = false;
          REGISTER_EMAIL_CONFIRM = false;
          # UPDATE_AVATAR = true;
        };
        repository = {
          DEFAULT_PRIVATE = "private";
        };
        server = {
          HTTP_PORT = 3200;
          HTTP_ADDR = "127.0.0.1";
          DOMAIN = domain;
          ROOT_URL = "https://${domain}/";
          LANDING_PAGE = "login";
        };
        service = {
          DISABLE_REGISTRATION = false;
          ALLOW_ONLY_INTERNAL_REGISTRATION = false;
          ALLOW_ONLY_EXTERNAL_REGISTRATION = true;
          SHOW_REGISTRATION_BUTTON = false;
          REGISTER_EMAIL_CONFIRM = false;
          # Disable pasword login
          ENABLE_BASIC_AUTHENTICATION = false;
          ENABLE_INTERNAL_SIGNIN = false;
        };
        session.COOKIE_SECURE = true;
        ui.DEFAULT_THEME = "forgejo-auto";
        "ui.meta" = {
          AUTHOR = "Git";
          DESCRIPTION = "Developers";
        };
      };
    };

    nginx.virtualHosts.${domain} = {
      enableACME = true;
      forceSSL = true;

      locations = {
        "/robots.txt" = {
          extraConfig = ''
            return 200 "User-agent: *\nDisallow: /\n";
            add_header Content-Type text/plain;
          '';
        };
        "/" = {
          proxyPass = "http://localhost:3200/";
        };
      };
    };
  };

  systemd.services.forgejo = {
    serviceConfig.RestartSec = "60"; # Retry every minute
    preStart =
      let
        exe = lib.getExe config.services.forgejo.package;
        providerName = "kanidm";
        clientId = "forgejo";
        args = lib.escapeShellArgs (
          lib.concatLists [
            [
              "--name"
              providerName
            ]
            [
              "--provider"
              "openidConnect"
            ]
            [
              "--key"
              clientId
            ]
            [
              "--auto-discover-url"
              "https://auth.kamoshi.org/oauth2/openid/${clientId}/.well-known/openid-configuration"
            ]
            [
              "--scopes"
              "email"
            ]
            [
              "--scopes"
              "profile"
            ]
            [
              "--group-claim-name"
              "groups"
            ]
            [
              "--admin-group"
              "admin"
            ]
            [
              "--skip-local-2fa"
            ]
          ]
        );
      in
        lib.mkAfter ''
          provider_id=$(${exe} admin auth list | ${pkgs.gnugrep}/bin/grep -w '${providerName}' | cut -f1)
          SECRET="$(< ${config.sops.secrets."kanidm/forgejo".path})"
          if [[ -z "$provider_id" ]]; then
            ${exe} admin auth add-oauth ${args} --secret "$SECRET"
          else
            ${exe} admin auth update-oauth --id "$provider_id" ${args} --secret "$SECRET"
          fi
        '';
  };

  # Backup
  # ----------
  systemd.tmpfiles.rules = [
    "d /var/backup/forgejo/ 0700 git git -"
  ];

  services.restic.backups.daily.paths = [
    "/var/backup/forgejo/"
  ];

  services.forgejo.dump = {
    enable = true;
    type = "tar";
    file = "dump";
    backupDir = "/var/backup/forgejo/";
  };
}
