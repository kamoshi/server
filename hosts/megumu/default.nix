# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, pkgs, vpn, ... }:
let
  ssh = 39016;
  pathBackup = "/var/backup/postgres";
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # Custom module definitions
    ../../modules
    # Host service settings
    ./services.nix
    # Other
    ./nginx.nix
  ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
  boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

  networking.hostName = "megumu"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "Europe/Warsaw";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.11"; # Did you read the comment?

  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # system = {
  #   autoUpgrade = {
  #     enable = true;
  #     allowReboot = true;
  #   };
  # };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nix = {
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Load secrets
  sops = {
    age.keyFile = "/root/.config/sops/age/keys.txt";
    defaultSopsFile = ./sops.yaml;
  };

  sops.secrets = {
    "wireguard" = {
      mode = "0600";
    };
    "restic" = {
      mode = "0600";
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    nano
    git
    vim
    wget
    fish
    sshfs
    ncdu
    gnumake
  ];

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = true;
  };

  networking = {
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ssh ];
      trustedInterfaces = [ "wg0" ];
    };
  };

  # fileSystems."/data" = {
  #   device = "/tmp";
  #   fsType = "tmpfs";
  # };

  fileSystems."/data" = {
    device = "u489674@u489674.your-storagebox.de:/home/megumu";
    neededForBoot = false;
    fsType = "fuse.sshfs";
    options = [
      "_netdev"
      "nodev"
      "noatime"
      "allow_other"
      "reconnect"
      "cache=yes"
      "cache_timeout=300"
      "IdentityFile=/root/.ssh/root@megumu"
      "ServerAliveInterval=15"
      "ServerAliveCountMax=3"
      "port=23"
    ];
  };

  # Define a user account. Don't forget to set a password with `passwd`.
  users.users.kamov = {
    isNormalUser = true;
    extraGroups = [ "wheel" "www" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIPeYt5Es7OB2z5EKC48XW/ziq2f8RtDhdODfSYISGJu kamov@aya"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEelrqEvoCTbgjdN5W6SnIMZ3HrsbfOg3PE2van+XlR4 kamov@momiji"
    ];
  };

  services = {
    endlessh = {
      enable = true;
      port = 22;
    };
    openssh = {
      enable = true;
      ports = [ ssh ];
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
  };

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
      # Path to the private key file.
      privateKeyFile = config.sops.secrets."wireguard".path;

      # ips        - IP address and subnet
      # peers      - List of peers
      # listenPort - Port to listen on
      inherit (vpn) ips peers listenPort;

      # # This allows the wireguard server to route your traffic to the internet and hence be like a VPN
      # # For this to work you have to set the dnsserver IP of your router (or dnsserver of choice) in your clients
      # postSetup = ''
      #   ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o eth0 -j MASQUERADE
      # '';

      # # This undoes the above command
      # postShutdown = ''
      #   ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.0.0.0/24 -o eth0 -j MASQUERADE
      # '';
    };
  };

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

  services.postgresql = {
    enable = true;
  };

  systemd.tmpfiles.rules = [
    "d ${pathBackup} 0700 postgres postgres -"
  ];

  services.postgresqlBackup = {
    enable = true;
    # Add database names in modules
    databases = [];
    location = pathBackup;
    startAt = "*-*-* 23:15:00";
  };

  services.restic.backups = {
    daily = {
      # Add paths in modules
      paths = [
        pathBackup
      ];
      repository = "/data/backup/megumu";
      initialize = true;
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 5"
        "--keep-monthly 12"
      ];
      passwordFile = config.sops.secrets."restic".path;
    };
  };
}
