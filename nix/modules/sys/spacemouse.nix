{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.spacemouse;
  wsCfg = config.spacemouse.websocket;
  browseCfg = config.spacemouse.browse;

  browsePython = pkgs.python3.withPackages (ps: [ ps.evdev ]);
  browsePackage = pkgs.writeScriptBin "spacemouse-browse" ''
    #!${browsePython}/bin/python3
    ${builtins.readFile ./spacemouse-browse.py}
  '';
  wsCertFile = "${wsCfg.package}/${pkgs.python3Packages.python.sitePackages}/spacenav_ws/certs/ip.crt";

  spacenavWsPackage = pkgs.python3Packages.buildPythonApplication rec {
    pname = "spacenav-ws";
    version = "0.1.5";
    pyproject = true;

    src = pkgs.fetchFromGitHub {
      owner = "RmStorm";
      repo = "spacenav-ws";
      rev = "ff33555d0ad1219cccca9e2120c48c4d4f41a2d5";
      hash = "sha256-RH1lz/nc/FUR7VMKixpSzgeR9xgF2HGcePYVRDjKuVg=";
    };

    build-system = [ pkgs.python3Packages.hatchling ];

    propagatedBuildInputs = with pkgs.python3Packages; [
      fastapi
      numpy
      scipy
      typer
      uvicorn
      websockets
      rich
    ];

    postPatch = ''
      # Avoid changing view extents on button events to prevent Onshape stretching.
      substituteInPlace src/spacenav_ws/controller.py \
        --replace '            await self.remote_write("view.extents", [c * 1.2 for c in model_extents])' ""
    '';

    postInstall = ''
      cert_dir="$out/${pkgs.python3Packages.python.sitePackages}/spacenav_ws/certs"
      mkdir -p "$cert_dir"
      cp -r "$src/src/spacenav_ws/certs/"* "$cert_dir/"
    '';

    meta = with lib; {
      description = "SpaceNav WebSocket Bridge for using a 3dConnexion spacemouse with Onshape";
      homepage = "https://github.com/RmStorm/spacenav-ws";
      license = licenses.mit;
      mainProgram = "spacenav-ws";
    };
  };
in
{
  options = {
    spacemouse = {
      enable = lib.mkEnableOption "Enable 3Dconnexion SpaceMouse support";
      websocket = {
        enable = lib.mkEnableOption "Enable spacenav-ws WebSocket bridge";
        host = lib.mkOption {
          type = lib.types.str;
          default = "127.51.68.120";
          description = "Host address for the spacenav-ws server.";
        };
        port = lib.mkOption {
          type = lib.types.port;
          default = 8181;
          description = "Port for the spacenav-ws server.";
        };
        package = lib.mkOption {
          type = lib.types.package;
          default = spacenavWsPackage;
          description = "spacenav-ws package to use for the service.";
        };
      };
      browse = {
        enable = lib.mkEnableOption "SpaceMouse browser scrolling (virtual scroll wheel + back/forward buttons)";
        browsers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "brave-browser"
            "firefox"
            "chromium-browser"
            "zen"
          ];
          description = "Hyprland window classes treated as browsers (case-insensitive).";
        };
        excludeTitle = lib.mkOption {
          type = lib.types.str;
          default = "onshape";
          description = "Case-insensitive regex; scrolling is disabled while the focused window title matches (keeps Onshape on spacenav-ws).";
        };
        speed = lib.mkOption {
          type = lib.types.float;
          default = 1.0;
          description = "Scroll speed multiplier (1.0 = ~25 wheel notches/s at full deflection).";
        };
        deadzone = lib.mkOption {
          type = lib.types.int;
          default = 30;
          description = "Axis deadzone out of ~350 full deflection.";
        };
        invertScroll = lib.mkEnableOption "inverted vertical scroll direction";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      hardware.spacenavd.enable = true;
      environment.systemPackages = [ pkgs.spnavcfg ];
    })

    (lib.mkIf wsCfg.enable {
      hardware.spacenavd.enable = true;
      environment.systemPackages = [ wsCfg.package ];
      security.pki.certificateFiles = [ wsCertFile ];

      systemd.services.spacenav-ws = {
        description = "spacenav-ws WebSocket bridge for 3Dconnexion SpaceMouse";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network.target"
          "spacenavd.service"
        ];
        requires = [ "spacenavd.service" ];
        serviceConfig = {
          ExecStart = "${wsCfg.package}/bin/spacenav-ws serve --host ${wsCfg.host} --port ${toString wsCfg.port}";
          Restart = "on-failure";
          RestartSec = 2;
        };
      };
    })

    (lib.mkIf browseCfg.enable {
      hardware.spacenavd.enable = true;
      environment.systemPackages = [ browsePackage ];

      # Guarantee /dev/uinput exists and the active seat user can open it,
      # independent of whatever other packages (dotool) provide.
      hardware.uinput.enable = true;
      services.udev.extraRules = ''
        KERNEL=="uinput", TAG+="uaccess"
      '';

      # User service: needs the Hyprland IPC socket, so it can't be a system
      # unit. wantedBy default.target because graphical-session.target never
      # starts under this Hyprland setup. The daemon itself waits/retries for
      # the spacenavd and Hyprland sockets.
      systemd.user.services.spacemouse-browse = {
        description = "SpaceMouse browser scrolling daemon";
        wantedBy = [ "default.target" ];
        serviceConfig = {
          ExecStart = lib.concatStringsSep " " (
            [
              "${browsePackage}/bin/spacemouse-browse"
              "--browsers ${lib.concatStringsSep "," browseCfg.browsers}"
              "--exclude-title '${browseCfg.excludeTitle}'"
              "--speed ${toString browseCfg.speed}"
              "--deadzone ${toString browseCfg.deadzone}"
            ]
            ++ lib.optional browseCfg.invertScroll "--invert"
          );
          Restart = "on-failure";
          RestartSec = 2;
        };
      };
    })
  ];
}
