{
  inputs,
  config,
  osConfig,
  pkgs,
  ...
}:
let
  link = config.lib.file.mkOutOfStoreSymlink;
  dots = "${config.home.homeDirectory}/nixos-config/dots";
  user = config.home.username;

  atuinargs = "--disable-up-arrow";
in
{

  # I don't like the read-only store symlinks
  # and I don't like managing everything via hm configs, makes making small
  # frequent changes a pita
  home.file = {
    ".config/atuin".source = link "${dots}/atuin";
    ".config/starship.toml".source = link "${dots}/starship.toml";
    ".config/tmux".source = link "${dots}/tmux";
    ".config/yazi".source = link "${dots}/yazi";
    ".config/ghostty".source = link "${dots}/ghostty";
    ".config/nvim".source = link "${dots}/nvim";
    ".vimrc".source = link "${dots}/.vimrc";
    ".local/bin/ta".source = link "${dots}/tmux/ta";
  };

  home.sessionVariables = {
    KEYTIMEOUT = 1;
  };

  home.sessionPath = [
    "/home/${user}/.cargo/bin"
    "/home/${user}/go/bin"
    "/home/${user}/apps/neovim/bin"
  ];

  programs = {
    zsh = {
      enable = true;
      autosuggestion = {
        enable = true;
        highlight = "fg=blue";
      };
      syntaxHighlighting.enable = true;

      initExtra = ''
        export CDPATH=$HOME/.local/share/nvim/:$CDPATH

        alias cat="bat"
        alias ll="ls -lah"

        eval "$(atuin init zsh ${atuinargs})"

        source ~/.secrets
        ta
      '';
    };

    fish = {
      enable = true;
      shellAbbrs = {
        ll = "ls -lah";
        cat = "bat";
      };
      interactiveShellInit = ''
        set fish_greeting

        atuin init fish ${atuinargs} | source

        ta
      '';
    };

    # using a custom build of atuin
    # atuin = {
    #   enable = true;
    #   package = pkgs.atuin;
    #   flags = [
    #     "--disable-up-arrow"
    #   ];
    #   settings = {
    #     search_mode = "fuzzy";
    #     style = "compact";
    #   };
    # };

    starship.enable = true;
    ghostty.enable = true;
    yazi.enable = true;
    htop.enable = true;

    git = {
      enable = true;
      ignores = [ ".direnv" ];
      userName = "James Trew";
      userEmail = "j.trew10@gmail.com";
      delta = {
        enable = true;
        options = {
          navigate = true;
          light = false;
          lineNumbers = true;
        };
      };
      extraConfig = {
        core = {
          editor = "nvim";
        };
        merge = {
          conflictStyle = "diff3";
        };
        diff = {
          colorMoved = "default";
        };
        color = {
          ui = true;
        };
        pull = {
          rebase = true;
        };
        rerere = {
          enabled = true;
        };
      };
    };

  };

}
