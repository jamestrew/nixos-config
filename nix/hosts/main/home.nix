{ config, pkgs, ... }:
let
  mkOutOfStoreSymlink = config.lib.file.mkOutOfStoreSymlink;

  cursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 22;
  };
in
{
  imports = [
    ../home.nix
  ];

  services.redshift = {
    enable = true;
    temperature.night = 3000;
    latitude = 43.66;
    longitude = -79.38;
    settings.redshift.brightness-day = "1";
    settings.redshift.brightness-night = "0.85";
    tray = true;
  };
  services.flameshot.enable = true;

  gtk = {
    enable = true;
    cursorTheme = cursor;
  };

  home.pointerCursor = {
    x11.enable = true;
    gtk.enable = true;
    inherit (cursor) name package size;
  };

  home.file = {
    ".config/qtile".source = mkOutOfStoreSymlink /home/jt/nixos-config/dots/qtile;
    ".config/picom".source = mkOutOfStoreSymlink /home/jt/nixos-config/dots/picom;
    ".config/rofi".source = mkOutOfStoreSymlink /home/jt/nixos-config/dots/rofi;
    ".config/zathura".source = mkOutOfStoreSymlink /home/jt/nixos-config/dots/zathura;
    ".config/discord/settings.json".source =
      mkOutOfStoreSymlink /home/jt/nixos-config/dots/discord/settings.json;
  };
}
