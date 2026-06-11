{
  config,
  pkgs,
  ...
}:
let
  cursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 22;
  };

  link = config.lib.file.mkOutOfStoreSymlink;
  dots = "${config.home.homeDirectory}/nixos-config/dots";

  # Geo-scheduled blue-light filter. Toggles hyprsunset between night (warm/dim)
  # and day (neutral) based on the sun's position via `sunwait poll`. Uses the
  # hardware CTM path (hyprsunset) instead of sunsetr, whose repeated blocking
  # gamma writes caused the ~60s display stutter (psi4j/sunsetr#21). It writes
  # the CTM only on an actual day<->night change, so the 5-min reconcile timer
  # never causes a redundant (hitch-inducing) write.
  bluelight-auto = pkgs.writeShellApplication {
    name = "bluelight-auto";
    runtimeInputs = [
      pkgs.sunwait
      pkgs.hyprland
    ];
    text = ''
      lat="43.700114N"
      lon="79.416306W"
      night_temp=3300
      night_gamma=90
      day_temp=6500
      day_gamma=100
      state="''${XDG_RUNTIME_DIR:-/tmp}/bluelight-auto.state"

      # sunwait poll exit codes: 2 = day/twilight, 3 = night, anything else = error.
      rc=0
      sunwait poll "$lat" "$lon" || rc=$?
      case "$rc" in
        2) want=day ;;
        3) want=night ;;
        *) echo "sunwait poll failed (rc=$rc); leaving state unchanged"; exit 0 ;;
      esac

      prev="$(cat "$state" 2>/dev/null || true)"
      if [ "$want" = "$prev" ]; then
        exit 0  # no transition -> no CTM write
      fi

      if [ "$want" = night ]; then
        temp=$night_temp
        gamma=$night_gamma
      else
        temp=$day_temp
        gamma=$day_gamma
      fi

      # Only record the new state once hyprsunset has accepted it, so a daemon
      # that isn't up yet (e.g. right at login) simply retries on the next tick.
      if hyprctl hyprsunset temperature "$temp" && hyprctl hyprsunset gamma "$gamma"; then
        echo "$want" > "$state"
      else
        echo "hyprsunset not reachable yet; will retry next tick"
      fi
    '';
  };
in
{
  obsidian.enable = true;
  vscode.enable = true;

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "jt";
  home.homeDirectory = "/home/jt";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "26.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    bluelight-auto

    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
    ".config/eww".source = link "${dots}/eww";
    ".config/hypr".source = link "${dots}/hypr";
    ".config/wofi".source = ../../../dots/wofi;
    ".config/swaync".source = ../../../dots/swaync;
    ".config/zathura".source = ../../../dots/zathura;
    ".config/discord/settings.json".source = ../../../dots/discord/settings.json;
    # ".config/qtile".source = link "${dots}/qtile";
    # ".config/picom".source = ../../../dots/picom;
    # ".config/rofi".source = ../../../dots/rofi;

  };

  gtk = {
    enable = true;
    cursorTheme = cursor;
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

  home.pointerCursor = {
    x11.enable = true;
    gtk.enable = true;
    inherit (cursor) name package size;
  };

  # Drive the geo-scheduled blue-light filter. The exec-once in hyprland.lua
  # applies the correct state at login; this timer reconciles it every 5 min so
  # the dusk/dawn flip lands within ~5 min of true sunset/sunrise, with no
  # hard-coded times to drift across seasons.
  systemd.user.services.bluelight-auto = {
    Unit.Description = "Reconcile hyprsunset day/night by sun position";
    Service = {
      Type = "oneshot";
      ExecStart = "${bluelight-auto}/bin/bluelight-auto";
    };
  };

  systemd.user.timers.bluelight-auto = {
    Unit.Description = "Periodically reconcile hyprsunset day/night";
    Timer = {
      OnStartupSec = "1min";
      OnUnitActiveSec = "5min";
    };
    Install.WantedBy = [ "timers.target" ];
  };

}
