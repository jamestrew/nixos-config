{
  config,
  pkgs,
  ...
}:
let
  link = config.lib.file.mkOutOfStoreSymlink;
  dots = "${config.home.homeDirectory}/nixos-config/dots";
  user = config.home.username;

  npmglobal = "${config.home.homeDirectory}/.npm-global";
in
{

  # I don't like the read-only store symlinks
  # and I don't like managing everything via hm configs, makes making small
  # frequent changes a pita
  home.file = {
    ".config/nvim".source = link "${dots}/nvim";
    ".config/tmux".source = link "${dots}/tmux";
    ".config/eww".source = link "${dots}/eww";
    ".config/atuin".source = ../../../dots/atuin;
    ".config/starship.toml".source = ../../../dots/starship.toml;
    ".config/yazi".source = ../../../dots/yazi;
    ".config/ghostty".source = ../../../dots/ghostty;
    ".config/hypr".source = link "${dots}/hypr";
    ".config/wofi".source = link "${dots}/wofi";
    ".config/swaync".source = link "${dots}/swaync";
    # ".config/qtile".source = link "${dots}/qtile";
    # ".config/picom".source = ../../../dots/picom;
    # ".config/rofi".source = ../../../dots/rofi;
    ".config/zathura".source = ../../../dots/zathura;
    ".config/discord/settings.json".source = ../../../dots/discord/settings.json;
    ".vimrc".source = ../../../dots/.vimrc;
    ".local/bin/ta".source = ../../../dots/tmux/ta;

    ".config/opencode/opencode.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      permission = {
        edit = "ask";
        bash = "ask";
        webfetch = "ask";
      };
      autoupdate = false;
      share = "manual";
    };

    ".npmrc".text = ''
      prefix=${npmglobal}
    '';
  };

  home.sessionVariables = {
    CDPATH = "${config.home.homeDirectory}/.local/share/nvim/:$CDPATH";
  };

  home.shellAliases = {
    ll = "eza -lah --git --group-directories-first";
    ls = "eza";
    cat = "bat";
    dash = "gh dash";
  };

  home.sessionPath = [
    "/home/${user}/.cargo/bin"
    "/home/${user}/go/bin"
    "/home/${user}/apps/neovim/bin"
    "${npmglobal}/bin" # naughty npm global install path
  ];

  programs = {
    fish = {
      enable = true;
      interactiveShellInit = ''
        set fish_greeting

        ta
      '';
      functions = {
        gitignore = "curl -sL https://www.gitignore.io/api/$argv";
        ns = {
          description = "Nix shell with multiple packages";
          body = ''
            if test (count $argv) -eq 0
                echo "Usage: ns <package1> <package2> ..."
                return 1
            end
            set -l prefixed (printf "nixpkgs#%s " $argv)
            eval nix shell --impure $prefixed
          '';
        };
        newproj = {
          description = "Create a new project with a default structure";
          body = ''
            if test (count $argv) -ne 1
                echo "Usage: newproj <project-name | git@github.com:owner/repo.git>"
                return 1
            end

            set -l proj_name $argv[1]
            set -l proj_root ~/projects
            mkdir -p $proj_root

            if string match -qr '^(git@|https://).+(\.git)?$' $proj_name
                set -l repo_path (string replace -r '\.git$' "" $proj_name)
                set -l repo_name (basename $repo_path)
                if not git clone $proj_name $proj_root/$repo_name
                    echo "Failed to clone $proj_name"
                    return $status
                end
                echo "Cloned $proj_name into $proj_root/$repo_name"
                return 0
            end

            mkdir -p $proj_root/$proj_name
            echo "Project $proj_root/$proj_name created..."
          '';
        };
        mkcd = {
          description = "Make and change into a new directory";
          body = ''
            if test (count $argv) -ne 1
                echo "Usage: mkcd <directory-name>"
                return 1
            end
            mkdir -p $argv[1]
            cd $argv[1]
          '';
        };
      };
    };

    atuin = {
      enable = true;
      package = pkgs.atuin;
      flags = [
        "--disable-up-arrow"
      ];
      settings = {
        search_mode = "fuzzy";
        style = "compact";
      };
    };

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
      ignores = [
        ".direnv"
        ".claude"
        "CLAUDE.md"
      ];
      settings = {
        user = {
          name = "James Trew";
          email = "j.trew10@gmail.com";
        };
        core.editor = "nvim";
        merge.conflictStyle = "zdiff3";
        diff = {
          colorMoved = "plain";
          algorithm = "histogram";
          renames = true;
          mnemonicPrefix = true;
        };
        color.ui = true;
        push = {
          default = "simple";
          autoSetupRemote = true;
          followTags = true;
        };
        fetch = {
          prune = true;
          # pruneTags = true;
          all = true;
        };
        commit.verbose = true;
        pull.enabled = true;
        rerere = {
          enabled = true;
          autoupdate = true;
        };
        rebase = {
          autoSquash = true;
          autoStash = true;
          updateRefs = true;
        };
        branch.sort = "-committerdate";
        tag.sort = "version:refname";
        init.defaultBranch = "master";
        help.autocorrect = "prompt";
      };
    };

    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        navigate = true;
        light = false;
        lineNumbers = true;
        side-by-side = true;
      };
    };

    jujutsu = {
      enable = true;
      settings = {
        user = {
          name = "James Trew";
          email = "j.trew10@gmail.com";
        };
        ui = {
          pager = ":builtin";
          streampager.interface = "quit-if-one-page";
          default-command = "st";
        };
      };
    };

    jjui.enable = true;

    gh = {
      enable = true;
      settings = {
        browser = "xdg-open";
      };
      extensions = [
        pkgs.gh-dash
        pkgs.gh-copilot
      ];
    };

    fzf = {
      enable = true;
      defaultCommand = "fd -td";
    };

  };

}
