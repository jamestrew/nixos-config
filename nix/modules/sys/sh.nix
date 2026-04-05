{
  config,
  lib,
  pkgs,
  ...
}:
{

  options = {
    defaultShell = lib.mkOption {
      default = pkgs.fish;
      type = lib.types.package;
      description = "The shell to use";
    };
  };

  config = {
    programs = {
      zsh.enable = true;
      fish.enable = true;

      bash.interactiveShellInit = (
        if config.defaultShell == pkgs.fish then
          ''
            if [[ $(ps -p "$PPID" -o comm= 2>/dev/null || true) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
            then
              shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
              exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
            fi
          ''
        else
          ""
      );
    };
  };

}
