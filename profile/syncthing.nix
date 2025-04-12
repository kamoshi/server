{ config, pkgs, ... }:
{
  services.syncthing = {
    enable = true;
    user = "kamov";
    group = "users";
    openDefaultPorts = false;
    configDir = "/home/kamov/.config/syncthing";
    # wg0 address
    guiAddress = "10.0.0.1:8384";

    settings = {
      gui = {
        enabled = true;
        user = "kamov";
        password = "kamov";
      };
      devices = {
        "Arch" = {
          id = "Q3QI722-QQL5J5Y-7MZJM54-BF2ZVYD-ZF25RJW-MH7OIJK-6QRCKBZ-KT6V4QF";
        };
        "Xiaomi" = {
          id = "C5MES7V-2QNWNA2-AYGIW2L-CBXJ7QX-D2UPQP2-SM6EDAW-ZWMHDOV-MVTSUQN";
        };
      };
    };
  };

  networking.firewall = {
    enable = true;
    interfaces.wg0.allowedTCPPorts = [ 8384 ];
  };

  # Don't create default ~/Sync folder
  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";
}
