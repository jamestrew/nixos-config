{
  lib,
  config,
  pkgs,
  system,
  ...
}:
with lib;
let
  pname = "zen-browser";
  version = "1.8.1b";
  src = pkgs.fetchurl {
    url = "https://github.com/zen-browser/desktop/releases/latest/download/zen-x86_64.AppImage";
    sha256 = "119gxhbwabl2zzxnm4l0vd18945mk2l0k12g5rf9x8v9lzsm7knn";
  };
  appimageContents = pkgs.appimageTools.extract {
    inherit pname version src;
  };

  wrappedZen = pkgs.appimageTools.wrapType2 {
    inherit pname version src;
    extraInstallCommands = ''
      # Install .desktop file
      install -m 444 -D ${appimageContents}/zen.desktop $out/share/applications/${pname}.desktop
      # Install icon
      install -m 444 -D ${appimageContents}/zen.png $out/share/icons/hicolor/128x128/apps/${pname}.png
    '';

    meta = {
      platforms = [ system ];
    };
  };
in
{
  options = {
    zen-browser.enable = lib.mkEnableOption "Enable zen browser app image";
  };

  config = lib.mkIf config.zen-browser.enable {
    environment.systemPackages = [ wrappedZen ];
    programs.nix-ld.enable = true;
  };
}
