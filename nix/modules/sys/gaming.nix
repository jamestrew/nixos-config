{
  pkgs,
  lib,
  config,
  ...
}:
{

  options = {
    gaming.enable = lib.mkEnableOption "Enable gaming packages";
  };

  config = lib.mkIf config.gaming.enable {
    programs.steam.enable = true;
    environment.systemPackages = with pkgs; [
      protonup-ng # steam proton thing, get STEAM_EXTRA_COMPAT_TOOLS_PATH env var and run `protonup`
    ];
    environment.variables = {
      STEAM_EXTRA_COMPAT_TOOLS_PATH = "~/.steam/root/compatibilitytools.d";
    };
  };

}
