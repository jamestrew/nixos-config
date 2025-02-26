{ inputs, ... }:
{

  imports = [
    ./apps.nix
    ./env.nix
    ./qtile.nix
    ./gaming.nix
    ./sops.nix
    ./sh.nix
    ./zen-browser.nix
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

  system.autoUpgrade.enable = true;
  system.autoUpgrade.dates = "weekly";

  nix.gc.automatic = true;
  nix.gc.dates = "weekly";
  nix.gc.options = "--delete-older-than 30d";
  nix.settings.auto-optimise-store = true;
}
