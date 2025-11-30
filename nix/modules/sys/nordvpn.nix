{
  pkgs,
  lib,
  config,
  ...
}:
{
  options = {
    nordvpn.enable = lib.mkEnableOption "Enable NordVPN";
  };

  config = lib.mkIf config.nordvpn.enable {
    environment.systemPackages = [ pkgs.nur.repos.wingej0.nordvpn ];

    users.groups.nordvpn = { };

    users.users.jt.extraGroups = [ "nordvpn" ];

    systemd.services.nordvpnd = {
      description = "NordVPN Daemon";
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "systemd-resolved.service"
      ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.nur.repos.wingej0.nordvpn}/bin/nordvpnd";
        RuntimeDirectory = "nordvpn";
        RuntimeDirectoryMode = "0750";
        Group = "nordvpn";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
