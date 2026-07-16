{
  isLinux,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  handy = inputs.llm-agents.packages.${system}.handy;
  # wtype shim for Handy: wait for physically-held modifiers (e.g. the SUPER
  # of the stop-dictation keybind) to be released before typing, otherwise
  # Hyprland reads the typed letters as SUPER+<letter> keybinds.
  handyWtypeShim = pkgs.writeShellScriptBin "wtype" ''
    exec ${pkgs.python3}/bin/python3 ${./wtype-wait-mods.py} ${pkgs.wtype}/bin/wtype "$@"
  '';
  # exec the original store binary (not a renamed copy) so the process comm
  # stays "handy" and the pkill -x handy toggle keybind keeps working
  handyWrapped = pkgs.symlinkJoin {
    name = "handy-wrapped";
    paths = [ handy ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm $out/bin/handy
      makeWrapper ${handy}/bin/handy $out/bin/handy \
        --prefix PATH : ${handyWtypeShim}/bin
    '';
  };
in
{
  environment.systemPackages =
    with pkgs;
    [
      vim
      wget
      nix-index
      nix-prefetch
      curl
      brave
      google-chrome
      git
      tmux
      bacon
      hyperfine
      bat
      ripgrep
      fd
      sd
      tree
      file
      sqlite
      nh
      tldr
      jq
      socat
      lsof
      tokei
      devenv
      sops
      dust
      inetutils
      htop
      (fenix.complete.withComponents [
        "cargo"
        "clippy"
        "rust-src"
        "rustc"
        "rustfmt"
      ])
      rust-analyzer-nightly
      gcc
      clang
      gnumake
      cmake
      gettext
      ninja
      ccache
      imagemagick
      ffmpeg
      discord
      fzf
      television
      yazi
      nodejs_24
      yarn
      openssh
      unzip
      zip
      tree-sitter
      go
      python314
      ruff
      uv
      delta
      starship
      docker
      luajit
      luajitPackages.luarocks
      lua51Packages.lua
      lua-language-server
      stylua
      luajitPackages.luacheck
      emmylua-ls
      emmylua-check
      inputs.llm-agents.packages.${system}.claude-code
      inputs.llm-agents.packages.${system}.claude-agent-acp
      inputs.llm-agents.packages.${system}.copilot-cli
      inputs.llm-agents.packages.${system}.gemini-cli
      inputs.llm-agents.packages.${system}.codex
      inputs.llm-agents.packages.${system}.codex-acp
      inputs.llm-agents.packages.${system}.opencode
      inputs.llm-agents.packages.${system}.pi
      inputs.llm-agents.packages.${system}.rtk
      inputs.llm-agents.packages.${system}.copilot-language-server
      handyWrapped
      whisper-cpp
      bash-language-server
      nil
      nixfmt
      basedpyright
      gopls
      libclang
      typescript
      bun
      pnpm
      typescript-language-server
      typescript-go
      emmet-language-server
      markdownlint-cli
      taplo
      biome
      vscode-langservers-extracted
      tailwindcss-language-server
      zls
      (if isLinux then vlc else vlc-bin)
    ]
    ++ lib.optionals isLinux [
      gimp
      libnotify
      thunar
      qalculate-gtk
      qbittorrent
      udiskie
      gparted
      gnome-disk-utility
      exfatprogs
      bottles
      dotool
      wtype
      zathura
      kooha
      flameshot
      pear-desktop
    ];
}
