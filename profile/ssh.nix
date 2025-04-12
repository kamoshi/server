{ config, pkgs, ... }:
{
  users.users.kamov = {
    isNormalUser = true;
    extraGroups = [ "wheel" "www" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEelrqEvoCTbgjdN5W6SnIMZ3HrsbfOg3PE2van+XlR4 maciej@kamoshi.org"
    ];
  };

  networking.firewall.allowedTCPPorts = [ 22 2222 ];

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
