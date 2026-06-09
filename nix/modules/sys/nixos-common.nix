{ lib, ... }:
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

  systemd.timers.fstrim.timerConfig = {
    OnCalendar = lib.mkForce "Mon 04:00";
    RandomizedDelaySec = "1h";
    Persistent = false;
  };
}
