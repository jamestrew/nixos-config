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
    ".config/nvim".source = link "${dots}/nvim";
    ".config/tmux".source = link "${dots}/tmux";
    ".config/atuin".source = ../../../dots/atuin;
    ".config/starship.toml".source = ../../../dots/starship.toml;
    ".config/yazi".source = ../../../dots/yazi;
    ".config/ghostty".source = ../../../dots/ghostty;
    ".vimrc".source = ../../../dots/.vimrc;
    ".local/bin/ta".source = ../../../dots/tmux/ta;
  };

  home.sessionVariables = {
    CDPATH = "${config.home.homeDirectory}/.local/share/nvim/:$CDPATH";
  };

  home.shellAliases = {
    ll = "eza -la";
    ls = "eza";
    cat = "bat";
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
        eval "$(atuin init zsh ${atuinargs})"
        ta
      '';
    };

    fish = {
      enable = true;
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
    eza = {
      enable = true;
      icons = "auto";
    };

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
