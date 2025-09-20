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
    git
    github-cli
    tmux
    bacon
    hyperfine
    bat
    ripgrep
    fd
    tree
    sqlite
    nh
    tldr
    jq
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
    ruff
    uv
    delta
    starship
    docker
    claude-code
    gemini-cli
    opencode
    codex

    lua-language-server
    stylua
    luajitPackages.luacheck
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
    emmet-language-server
    markdownlint-cli
    taplo
    biome
    vscode-langservers-extracted
    copilot-language-server
    tailwindcss-language-server
  ];
}
