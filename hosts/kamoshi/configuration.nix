{ config, pkgs, ... }:
{
  imports =
    [
      /etc/nixos/hardware-configuration.nix
    ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
  boot.loader.grub.device = "/dev/vda"; # or "nodev" for efi only

  networking = {
    hostName = "kamoshi";
    nat = {
      enable = true;
      externalInterface = "eth0";
      internalInterfaces = [ "wg0" ];
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [
        22    # endlessh 
        80    # nginx 
        443   # nginx TLS 
        2222  # ssh 
      ];
      allowedUDPPorts = [
        42069 # wireguard
      ];
      interfaces = {
        "wg0" = {
          allowedTCPPorts = [
            8384 22000    # syncthing
          ];
          allowedUDPPorts = [
            22000 21027   # syncthing
          ];
        };
      };
    };
    wireguard.interfaces = {
      "wg0" = {
        ips = [ "10.100.0.1/24" ];
        listenPort = 42069;
        postSetup = ''
          ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.100.0.0/24 -o eth0 -j MASQUERADE
        '';
        postShutdown = ''
          ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.100.0.0/24 -o eth0 -j MASQUERADE
        '';
        privateKeyFile = "/root/secrets/wireguard/kamoshi";

        peers = [
          {
            publicKey = "26lQ3qCZrZ3hAqLIDfQNrmFQSQv983TeyXpJUY59QkI=";
            allowedIPs = [ "10.100.0.2/32" ];
          }
        ];
      };
    };
  };

  time.timeZone = "Europe/Warsaw";
  i18n.defaultLocale = "en_US.UTF-8";

  users.users.kamov = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keyFiles = [ /root/secrets/ssh/kamov.pub ];
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    neovim
    neofetch
    nushell
    wireguard-tools
  ];

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
    nginx = {
      enable = true;
      recommendedTlsSettings = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      virtualHosts = {
        "kamoshi.org" = {
          default = true;
          root = "/var/www/kamoshi.org";
          addSSL = true;
          enableACME = true;
        };
      };
    };
    syncthing = {
      enable = true;
      user = "syncthing";
      dataDir = "/home/syncthing/sync/";
      configDir = "/home/syncthing/.config/";
      overrideDevices = true;
      overrideFolders = true;
      devices = {
        "kamov" = { id = (builtins.readFile /root/secrets/syncthing/kamov.id); };
        "phone" = { id = (builtins.readFile /root/secrets/syncthing/phone.id); };
      };
      folders = {
        "obsidian" = {
          path = "/home/syncthing/sync/obsidian";
          devices = [ "kamov" "phone" ];
        };
      };
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "maciej@kamoshi.org";
  };

  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true;
    };
    oci-containers = {
      backend = "podman";
      containers = {
        kotori = {
          image = "kamov/kotori";
          environmentFiles = [ /root/secrets/kotori.env ];
          autoStart = true;
        };
      };
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

}
