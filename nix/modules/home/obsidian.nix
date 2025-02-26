{
  config,
  lib,
  pkgs,
  ...
}:
{

  options = {
    obsidian.enable = lib.mkEnableOption "Enable Obsidian";
  };

  config = lib.mkIf config.obsidian.enable {
    home.packages = with pkgs; [
      obsidian
    ];

    # sync with dropbox
    # might need to run `dropbox start` to auth and start syncing
    services.dropbox.enable = true;
  };

}
