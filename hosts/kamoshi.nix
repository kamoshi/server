{ ... }:
{
  kamov = {
    syncthing = {
      enable = true;
      port = 8384;
      bind = "10.0.0.1";
      user = "kamov";
      configDir = "/home/kamov/.config/syncthing";
    };
  };
}
