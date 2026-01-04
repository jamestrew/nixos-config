{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.spacemouse;
  wsCfg = config.spacemouse.websocket;

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
  ];
}
