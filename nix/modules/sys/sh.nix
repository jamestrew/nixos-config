{
  config,
  lib,
  pkgs,
  ...
}:
{

  options = {
    defaultShell = lib.mkOption {
      default = pkgs.zsh;
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
            if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
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
