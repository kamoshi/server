{ config, pkgs, ... }:
{
  # enable NAT
  networking.nat.enable = true;
  networking.nat.externalInterface = "enp1s0";
  networking.nat.internalInterfaces = [ "wg0" ];
  networking.firewall = {
    allowedUDPPorts = [ 42069 ];
  };

  networking.wireguard.enable = true;
  networking.wireguard.interfaces = {
    wg0 = {
      # IP address and subnet
      ips = [ "10.0.0.1/24" ];
      # The port that WireGuard listens to. Must be accessible by the client.
      listenPort = 42069;

      # This allows the wireguard server to route your traffic to the internet and hence be like a VPN
      # For this to work you have to set the dnsserver IP of your router (or dnsserver of choice) in your clients
      postSetup = ''
        ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o eth0 -j MASQUERADE
      '';

      # This undoes the above command
      postShutdown = ''
        ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.0.0.0/24 -o eth0 -j MASQUERADE
      '';

      # Path to the private key file.
      privateKeyFile = "/root/wireguard/kamoshi.key";

      peers = [
        { # Arch
          publicKey = "9UISV736vJr39rHCvTuJeF72vjSxnD8DJgF0NZYzLTU=";
          allowedIPs = [ "10.0.0.2/32" ];
        }
        { # Xiaomi
          publicKey = "THSJl4nUJCU3cUX1egy9XojocTocLXG4+UoNEuYztXw=";
          allowedIPs = [ "10.0.0.3/32" ];
        }
      ];
    };
  };
}
