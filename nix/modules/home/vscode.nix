# yikes
{
  config,
  lib,
  pkgs,
  ...
}:
{

  options = {
    vscode.enable = lib.mkEnableOption "Enable Visual Studio Code";
  };

  config = lib.mkIf config.vscode.enable {
    programs.vscode = {
      enable = true;

      profiles.default.extensions = with pkgs.vscode-extensions; [
        asvetliakov.vscode-neovim
      ];
    };
  };

}
