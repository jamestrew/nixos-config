{
  config,
  pkgs,
  self,
  ...
}:
let
  defaultShell = pkgs.fish;
in
{
  imports = [ ../../modules/sys/default.nix ];

  defaultShell = defaultShell;

  users.knownUsers = [ "jt" ];
  users.users.jt = {
    uid = 501;
    home = "/Users/jt";
    shell = config.defaultShell;
  };

  environment.shells = [
    config.defaultShell
  ];

  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    autoMigrate = true;
    user = "jt";
  };

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "uninstall";
    };
    brews = [ "openssh" ];
    casks = [ "handy" ];
  };

  nixpkgs = {
    hostPlatform = "aarch64-darwin";
  };

  system.configurationRevision = self.rev or self.dirtyRev or null;

  karabiner.enable = true;

  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = true;
  };

  system.defaults = {
    dock.autohide = true;
    finder.AppleShowAllExtensions = true;
  };

  system.primaryUser = "jt";
  system.stateVersion = 6;
}
