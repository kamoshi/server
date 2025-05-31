{ config, ... }:
{
  # Load secrets
  sops = {
    age.keyFile = "/root/.config/sops/age/keys.txt";
    defaultSopsFile = /var/lib/secrets/kamoshi.yaml;
  };

  # Forgejo
  # =====
  sops.secrets."kanidm/forgejo" = {
    owner = "git";
    group = "kanidm";
    mode = "0440";
  };

  kamov.forgejo = {
    enable = true;
    domain = "git.kamoshi.org";
    port = 3200;
    bind = "127.0.0.1";
    oauthSecretPath = config.sops.secrets."kanidm/forgejo".path;
  };

  # Gatus
  # =====
  kamov.gatus = {
    enable = true;
    domain = "status.kamoshi.org";
    port = 2138;
    bind = "127.0.0.1";
  };

  # Grafana
  # =======
  sops.secrets."grafana/secret_key" = {
    owner = "grafana";
    group = "grafana";
    mode = "0400";
  };

  sops.secrets."grafana/client_secret" = {
    owner = "grafana";
    group = "kanidm";
    mode = "0440";
  };

  kamov.grafana = {
    enable = true;
    domain = "data.kamoshi.org";
    port = 2139;
    bind = "127.0.0.1";
  };

  # Kanidm
  # ======
  kamov.kanidm = {
    enable = true;
    domain = "auth.kamoshi.org";
    port = 8443;
    bind = "127.0.0.1";
  };

  # Kotori
  # ======
  sops.secrets.kotori = {
    mode = "0400";
  };

  kamov.kotori = {
    enable = true;
    envPath = config.sops.secrets.kotori.path;
  };

  # Miniflux
  # ========
  sops.secrets."kanidm/miniflux" = {
    owner = "miniflux";
    group = "kanidm";
    mode = "0440";
  };

  kamov.miniflux = {
    enable = true;
    domain = "rss.kamoshi.org";
    port = 2137;
    bind = "127.0.0.1";
    oauthSecretPath = config.sops.secrets."kanidm/miniflux".path;
  };

  # Syncthing
  # =========
  kamov.syncthing = {
    enable = true;
    port = 8384;
    bind = "10.0.0.1";
    user = "kamov";
    configDir = "/home/kamov/.config/syncthing";
  };

  # Vikunja
  # =======
  kamov.vikunja = {
    enable = false;
    domain = "kanban.kamoshi.org";
    port = 6969;
    bind = "127.0.0.1";
  };
}
