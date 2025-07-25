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
    inputs.nh.packages.${system}.nh
    tldr
    jq
    tokei
    sops
    qalculate-gtk
    qbittorrent
    udiskie
    dust # A more intuitive du replacement

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
    discord
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
