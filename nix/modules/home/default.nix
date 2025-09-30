{ inputs, ... }:
{
  imports = [
    ./obsidian.nix
    ./home.nix
    ./sops.nix
    ./vscode.nix
  ];
}
