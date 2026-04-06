{
  isDarwin,
  lib,
  ...
}:
{
  imports = [
    ./obsidian.nix
    ./home.nix
    ./vscode.nix
  ]
  ++ lib.optionals (!isDarwin) [
    ./sops.nix
  ];
}
