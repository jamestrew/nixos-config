{ pkgs, inputs, system, ... }:
{
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    nix-index
    nix-prefetch
    curl
    firefox
    google-chrome # sometimes firefox is doodoo
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
    sops

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

    gimp
    go
    ruff
    uv
    delta
    starship
    docker

    lua-language-server
    bash-language-server
    stylua
    nil # nix language server
    nixfmt-rfc-style
    basedpyright
    gopls
    libclang
    deno
    emmet-language-server
    markdownlint-cli
    taplo
    biome
    vscode-langservers-extracted
  ];
}
