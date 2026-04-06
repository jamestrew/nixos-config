{ ... }:
{
  nix.settings = {
    trusted-users = [ "jt" ];
    auto-optimise-store = true;
  };

  system.autoUpgrade = {
    enable = true;
    dates = "weekly";
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
}
