{
  config,
  pkgs,
  lib,
  ...
}:
{

  options = {
    hyprland.enable = lib.mkEnableOption "Enable hyprland window manager";
  };

  config = lib.mkIf config.hyprland.enable {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    # Wayland/Hyprland specific packages
    environment.systemPackages = with pkgs; [
      # Core Wayland tools
      wofi
      wl-clipboard
      grim
      slurp
      swaynotificationcenter
      eww

      # Hypr ecosystem
      hyprlock
      hypridle
      hyprpaper
      hyprpicker
      hyprpolkitagent

      # Audio/media tools (shared with qtile, could be moved to common module)
      playerctl
      pavucontrol
      alsa-utils
      cliphist  # clipboard manager
    ];

    xdg.portal = {
      enable = true;
      wlr.enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };

    # Audio system
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    programs.gdk-pixbuf.modulePackages = [ pkgs.librsvg ];

    services.playerctld.enable = true;
  };
}

