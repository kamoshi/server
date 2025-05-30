{ config, ... }:
{
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
    port = 2137;
    bind = "10.0.0.1";
    domain = "rss.kamoshi.org";
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
}
