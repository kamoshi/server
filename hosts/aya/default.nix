{ self, pkgs, device,... }:
let
  user = "kamov";
in {
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages =
    [ pkgs.vim
    ];

  # Enable alternative shell support in nix-darwin.
  programs.fish.enable = true;

  networking = {
    computerName = device.name;
    hostName = device.key;
    localHostName = device.key;
  };

  users.users.${user}.home = "/Users/${user}";

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

  system = {
    # Used for backwards compatibility, please read the changelog before changing.
    # $ darwin-rebuild changelog
    stateVersion = 6;

    # Set Git commit hash for darwin-version.
    configurationRevision = self.rev or self.dirtyRev or null;

    primaryUser = user;

    defaults = {
      NSGlobalDomain = {
        AppleShowAllExtensions = true;

        # 120, 90, 60, 30, 12, 6, 2
        KeyRepeat = 2;

        # 120, 94, 68, 35, 25, 15
        InitialKeyRepeat = 15;
      };

      dock = {
        autohide = true;
        show-recents = true;
        launchanim = true;
        orientation = "bottom";
        tilesize = 48;
      };
    };
  };

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = device.arch;
}
