{ pkgs, ... }:
let
  ssh = 39016;
in {
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      # Secrets provisioning
      "${builtins.fetchTarball "https://github.com/Mic92/sops-nix/archive/e93ee1d900ad264d65e9701a5c6f895683433386.tar.gz"}/modules/sops"
      # Services
      ./services.nix
    ];

  system = {
    autoUpgrade = {
      enable = true;
      allowReboot = true;
    };
  };

  nix = {
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
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
  ];

  networking = {
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ssh ];
    };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.kamov = {
    isNormalUser = true;
    extraGroups = [ "wheel" "www" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEelrqEvoCTbgjdN5W6SnIMZ3HrsbfOg3PE2van+XlR4 maciej@kamoshi.org"
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
}
