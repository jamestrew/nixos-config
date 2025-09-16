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
      waybar
      wofi
      wl-clipboard
      grim
      slurp

      # Hypr ecosystem
      hyprlock
      hypridle
      hyprpaper
      hyprpicker
      hyprsunset

      # Notification system
      swaynotificationcenter

      # Audio/media tools (shared with qtile, could be moved to common module)
      playerctl
      pavucontrol
      alsa-utils
    ];

    # Use SDDM for better multi-monitor support instead of tuigreet
    # Only enable SDDM if qtile is not enabled
    services.displayManager.sddm = lib.mkIf (!config.qtile.enable) {
      enable = true;
      wayland.enable = true;
    };
    
    # Disable greetd when using Hyprland
    services.greetd.enable = lib.mkForce false;

    # XDG portals for desktop integration
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

    # Services that work with both X11 and Wayland
    services.clipmenu.enable = true;
    services.playerctld.enable = true;
  };
}

