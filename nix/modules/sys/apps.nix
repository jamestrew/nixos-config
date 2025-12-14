{
  pkgs,
  inputs,
  system,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
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
    sqlite
    nh
    tldr
    jq
    socat
    lsof
    libnotify
    tokei
    devenv
    sops
    qalculate-gtk
    qbittorrent
    udiskie
    dust # A more intuitive du replacement
    gparted
    inetutils # telnet, etc
    gnome-disk-utility
    exfatprogs
    bottles

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

    flameshot
    legcord
    youtube-music
    fzf
    yazi
    vlc
    ghostty
    kitty
    nodePackages.npm
    nodePackages.nodejs
    yarn
    openssh
    unzip
    zip
    tree-sitter

    gimp
    go
    python314
    ruff
    uv
    delta
    starship
    docker

    luajit
    lua51Packages.lua
    lua-language-server
    stylua
    luajitPackages.luacheck
    emmylua-ls

    inputs.nix-ai-tools.packages.${system}.claude-code
    inputs.nix-ai-tools.packages.${system}.copilot-cli
    inputs.nix-ai-tools.packages.${system}.gemini-cli
    inputs.nix-ai-tools.packages.${system}.codex
    inputs.nix-ai-tools.packages.${system}.opencode
    handy

    bash-language-server
    nil # nix language server
    nixfmt-rfc-style
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
    copilot-language-server
    tailwindcss-language-server
    zls
  ];
}
