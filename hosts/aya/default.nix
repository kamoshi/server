{ self, pkgs, ... }:
{
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages =
    [ pkgs.vim
    ];

  # Enable alternative shell support in nix-darwin.
  programs.fish.enable = true;

  networking = {
    computerName = "Aya";
    hostName = "aya";
    localHostName = "aya";
  };

  users.users.kamov.home = "/Users/kamov";

  homebrew = {
    enable = true;
    onActivation.cleanup = "uninstall";
    onActivation.upgrade = true;

    taps = [];
    brews = [
      "gpg"
      "ncdu"
      "dosbox-x"
      "pinentry-mac"
      "mupdf-tools"
    ];
    casks = [
      "vlc"
      "steam"
      "anki"
      "zed"
      "ghostty"
      "spotify"
      "obsidian"
      "krita"
      "calibre"
    ];
  };

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

  security.pam.services.sudo_local.touchIdAuth = true;

  system.primaryUser = "kamov";

  # Set Git commit hash for darwin-version.
  system.configurationRevision = self.rev or self.dirtyRev or null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";
}
