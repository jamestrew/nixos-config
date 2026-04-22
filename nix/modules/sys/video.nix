{
  config,
  lib,
  pkgs,
  ...
}:
{
  options = {
    video.enable = lib.mkEnableOption "Enable video creation and editing apps";
  };

  config = lib.mkIf config.video.enable {
    environment.systemPackages = with pkgs; [
      obs-studio
      kdePackages.kdenlive
    ];
  };
}
