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
  nix.package = pkgs.nixVersions.stable;

  system.autoUpgrade.enable = true;
  system.autoUpgrade.dates = "weekly";

  nix.gc.automatic = true;
  nix.gc.dates = "weekly";
  nix.gc.options = "--delete-older-than 30d";
  nix.settings.auto-optimise-store = true;
}
