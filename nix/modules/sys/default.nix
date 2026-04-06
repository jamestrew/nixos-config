{ inputs, pkgs, isDarwin, lib, ... }:
{
  nixpkgs = {
    overlays = import ../../overlays {
      inherit inputs;
    };
    config.allowUnfree = true;
  };

  nix = {
    package = pkgs.nixVersions.stable;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      extra-substituters = [ "https://cache.numtide.com" ];
      extra-trusted-public-keys = [
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
    };
  };

  programs = {
    direnv.enable = true;
  };

  imports = [
    ./apps.nix
    ./env.nix
    ./sh.nix
  ] ++ lib.optionals isDarwin [
    ./karabiner.nix
  ];
}
