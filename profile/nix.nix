{ config, pkgs, ... }:
{
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

  networking = {
    firewall = {
      enable = true;
    };
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    neovim
  ];
}
