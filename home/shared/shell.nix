{ config, pkgs, ... }:
let
  home = config.home.homeDirectory;
in
{
  programs.bash = {
    enable = true;
    shellAliases = {
      ls = "ls --color=auto";
      grep = "grep --color=auto";
    };
    bashrcExtra = ''
      # Haskell ghcup
      [ -f "${home}/.ghcup/env" ] && . "${home}/.ghcup/env"
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
      test -r '${home}/.opam/opam-init/init.fish' && source '${home}/.opam/opam-init/init.fish' > /dev/null 2> /dev/null; or true
      # END opam configuration
    '';
  };

  programs.direnv = {
    enable = true;
  };

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
  };

  programs.fzf = {
    enable = true;
  };

  home.shell.enableFishIntegration = true;
}
