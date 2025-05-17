{ inputs, ... }:
{
  imports = [
    ./obsidian.nix
    ./sh.nix
    ./sops.nix
    ./vscode.nix
  ];
}
