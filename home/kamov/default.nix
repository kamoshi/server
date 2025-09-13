{ config, pkgs, mesh, ... }:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
in
{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "kamov";
  home.homeDirectory =
    if isDarwin
      then "/Users/${config.home.username}"
      else "/home/${config.home.username}";


  programs.bash = {
    enable = true;
    shellAliases = {
      ls = "ls --color=auto";
      grep = "grep --color=auto";
    };
    bashrcExtra = ''
      # Haskell ghcup
      [ -f "/home/kamov/.ghcup/env" ] && . "/home/kamov/.ghcup/env"
    '';
    initExtra = ''
      PS1='\[\e]0;\u@\h: \w\a\]\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

      # Run fish
      # https://wiki.archlinux.org/title/Fish#Modify_.bashrc_to_drop_into_fish
      if [[ $(ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} && ''${SHLVL} == 1 ]]
      then
        shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION='''
        exec fish $LOGIN_OPTION
      fi
    '';
  };

  programs.fish = {
    enable = true;

    shellInit = ''
      # BEGIN opam configuration
      # This is useful if you're using opam as it adds:
      # - the correct directories to the PATH
      # - auto-completion for the opam binary
      # This section can be safely removed at any time if needed.
      test -r '${config.home.homeDirectory}/.opam/opam-init/init.fish' && source '${config.home.homeDirectory}/.opam/opam-init/init.fish' > /dev/null 2> /dev/null; or true
      # END opam configuration
    '';
  };

  home.shell.enableFishIntegration = true;

  programs.direnv = {
    enable = true;
  };

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
  };

  services.syncthing = {
    enable = true;

    settings = {
      gui = {
        user = "kamov";
        password = "kamov";
      };

      inherit (mesh) devices folders;
    };
  };

  programs.git = {
    enable = true;
    userName  = "Maciej Jur";
    userEmail = "maciej@kamoshi.org";

    signing = {
      key = "191CBFF5F72ECAFD";
      signByDefault = true;
    };

    extraConfig = {
      init.defaultBranch = "main";
    };
  };

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    nixd
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  xdg.configFile."zed/settings.json".source = ./zed/settings.json;
  xdg.configFile."newsboat/config".source = ./newsboat/config;
  xdg.configFile."newsboat/urls".source = ./newsboat/urls;

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/kamov/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    EDITOR = "nvim";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "25.05"; # Please read the comment before changing.
}
