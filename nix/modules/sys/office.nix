{
  config,
  lib,
  pkgs,
  ...
}:
let
  pptxPython = pkgs.python314.withPackages (
    ps: with ps; [
      markitdown
      defusedxml
      pillow
      lxml
    ]
  );
in
{
  options = {
    office.enable = lib.mkEnableOption "Enable office apps";
  };

  config = lib.mkIf config.office.enable {
    environment.systemPackages = with pkgs; [
      libreoffice-fresh
      onlyoffice-desktopeditors
      poppler-utils
      gcc
      (lib.hiPrio pptxPython)
    ];
  };
}
