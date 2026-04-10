{
  config,
  lib,
  pkgs,
  ...
}:
{
  options = {
    office.enable = lib.mkEnableOption "Enable office apps";
  };

  config = lib.mkIf config.office.enable {
    environment.systemPackages = with pkgs; [
      libreoffice-fresh
      onlyoffice-desktopeditors
    ];
  };
}
