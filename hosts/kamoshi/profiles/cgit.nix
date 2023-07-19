{ config, pkgs, ... }:
let
  home = "/var/lib/git";
  address = "git.kamoshi.org";
in
{
  users.users.git = {
    isSystemUser = true;
    description = "git user";
    home = home;
    group = "users";
    shell = "${pkgs.git}/bin/git-shell";
    openssh.authorizedKeys.keyFiles = [
      /root/secrets/ssh/kamov.pub
    ];
  };
  services = {
    nginx = {
      enable = true;
      virtualHosts."${address}" = {
        forceSSL = true;
        enableACME = true;
      };
    };
    cgit."${address}" = {
      enable = true;
      scanPath = home;
      nginx.virtualHost = address;
    };
  };
}
