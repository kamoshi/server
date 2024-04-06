{ config, pkgs, ... }:
{
  users.users.kamov = {
    isNormalUser = true;
    extraGroups = [ "wheel" "www" ];
    openssh.authorizedKeys.keyFiles = [ /root/.ssh/kamov.pub ];
  };

  services = {
    endlessh = {
      enable = true;
      port = 22;
    };
    openssh = {
      enable = true;
      ports = [ 2222 ];
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
  };
}
