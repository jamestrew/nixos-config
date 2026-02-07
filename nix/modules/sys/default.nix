{ inputs, pkgs, ... }:
{

  imports = [
    ./apps.nix
    ./env.nix
    ./gaming.nix
    ./qtile.nix
    ./hyprland.nix
    ./sh.nix
    ./sops.nix
    ./nordvpn.nix
    ./spacemouse.nix
  ];

  nixpkgs = {
    overlays = import ../../overlays {
      inherit inputs;
    };
    config.allowUnfree = true;
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.trusted-users = [
    "jt"
  ];
  nix.settings.extra-substituters = [ "https://cache.numtide.com" ];
  nix.settings.extra-trusted-public-keys = [
    "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
  ];
  nix.package = pkgs.nixVersions.stable;

  system.autoUpgrade.enable = true;
  system.autoUpgrade.dates = "weekly";

  nix.gc.automatic = true;
  nix.gc.dates = "weekly";
  nix.gc.options = "--delete-older-than 30d";
  nix.settings.auto-optimise-store = true;
}
