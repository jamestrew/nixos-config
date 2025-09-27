{
  config,
  pkgs,
  lib,
  ...
}:
{

  options = {
    qtile.enable = lib.mkEnableOption "Enable qtile window manager";
  };

  config = lib.mkIf config.qtile.enable {
    services.xserver = {
      enable = true;
      displayManager = {
        lightdm.enable = lib.mkForce true;
      };
      windowManager.qtile = {
        enable = true;
        extraPackages =
          python3Packages: with python3Packages; [
            qtile-extras
            dateutil
            dbus-next
            pyxdg
          ];
      };
    };

    # Disable other display managers when using qtile
    services.displayManager.sddm.enable = lib.mkForce false;
    services.displayManager.defaultSession = lib.mkForce "qtile";

    # X11/Qtile specific packages
    environment.systemPackages = with pkgs; [
      picom
      rofi
      dunst
      flameshot
      # Audio/media tools shared between WMs could be moved to a common module
      pavucontrol
      alsa-utils

      eww  # experimenting with widgets
    ];

    environment.variables = {
      CM_LAUNCHER = "rofi";
    };

    programs.gdk-pixbuf.modulePackages = [ pkgs.librsvg ];

    # Services that work with both X11 and Wayland
    services.clipmenu.enable = true;
    services.playerctld.enable = true;
  };
}
