{ config, lib, ... }:
{
  # Syncthing
  # =========
  kamov.syncthing = {
    enable = true;
    port = 8384;
    bind = "10.0.0.1";
    user = "kamov";
    configDir = "/home/kamov/.config/syncthing";
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

  # Kanidm
  # ======
  kamov.kanidm = {
    enable = true;
    domain = "auth.kamoshi.org";
    port = 8443;
    bind = "127.0.0.1";
  };

  # Miniflux
  # ========
  sops.secrets."kanidm/miniflux" = lib.mkIf config.kamov.miniflux.enable {
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

  # Forgejo
  # =====
  # sops.secrets."kanidm/forgejo" = {
  #   owner = "git";
  #   group = "kanidm";
  #   mode = "0440";
  # };

  kamov.forgejo = {
    enable = false;
    domain = "git.kamoshi.org";
    port = 3200;
    bind = "127.0.0.1";
    oauthSecretPath = config.sops.secrets."kanidm/forgejo".path;
  };

  # Gatus
  # =====
  kamov.gatus = {
    enable = false;
    domain = "status.kamoshi.org";
    port = 2138;
    bind = "127.0.0.1";
  };

  # Grafana
  # =======
  # sops.secrets."grafana/secret_key" = lib.mkIf config.kamov.grafana.enable {
  #   owner = "grafana";
  #   group = "grafana";
  #   mode = "0400";
  # };

  # sops.secrets."grafana/client_secret" = lib.mkIf config.kamov.grafana.enable {
  #   owner = "grafana";
  #   group = "kanidm";
  #   mode = "0440";
  # };

  kamov.grafana = {
    enable = false;
    domain = "data.kamoshi.org";
    port = 2139;
    bind = "127.0.0.1";
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
