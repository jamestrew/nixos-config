{ lib, config, pkgs, ... }:
with lib;
let
  pname = "zen-browser";
  version = "1.8.1b";
  src = pkgs.fetchurl {
    url = "https://github.com/zen-browser/desktop/releases/latest/download/zen-x86_64.AppImage";
    sha256 = "119gxhbwabl2zzxnm4l0vd18945mk2l0k12g5rf9x8v9lzsm7knn";
  };
  wrappedZen = pkgs.appimageTools.wrapType2 {
    inherit pname version src;
  };
in {
  options = {
    zen-browser.enable = lib.mkEnableOption "Enable zen browser app image";
  };

  config = lib.mkIf config.zen-browser.enable {
    environment.systemPackages = [ wrappedZen ];
  };
}
