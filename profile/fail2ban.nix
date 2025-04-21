{ config, lib, ... }:
{
  services.fail2ban = {
    enable = true;

    ignoreIP = [
      # Wireguard IPs
      "10.0.0.0/24"
      # Loopback addresses
      "127.0.0.0/8"
    ];

    maxretry = 5;

    bantime-increment = {
      enable = true;
      rndtime = "5m"; # Use 5 minute jitter to avoid unban evasion
    };

    jails.DEFAULT.settings = {
      findtime = "4h";
      bantime = "10m";
    };
  };
}
