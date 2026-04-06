{
  config,
  lib,
  ...
}:
let
  ghosttyId = "^com\\.mitchellh\\.ghostty$";

  nonTerminal = {
    type = "frontmost_application_unless";
    bundle_identifiers = [ ghosttyId ];
  };

  inTerminal = {
    type = "frontmost_application_if";
    bundle_identifiers = [ ghosttyId ];
  };

  pcKey = key: {
    type = "basic";
    from = {
      key_code = key;
      modifiers = {
        mandatory = [ "control" ];
        optional = [ "any" ];
      };
    };
    to = [ { key_code = key; modifiers = [ "command" ]; } ];
    conditions = [ nonTerminal ];
  };

  karabinerConfig = builtins.toJSON {
    global = {
      check_for_updates_on_startup = false;
      show_in_menu_bar = true;
    };
    profiles = [
      {
        name = "Default";
        selected = true;
        complex_modifications.rules = [
          {
            description = "PC-style shortcuts in non-terminal apps";
            manipulators = map pcKey [ "c" "v" "z" "x" "a" "w" "t" "n" "f" "s" ];
          }
          {
            description = "Terminal copy/paste (ctrl+shift+c/v) in ghostty";
            manipulators = [
              {
                type = "basic";
                from = {
                  key_code = "c";
                  modifiers = { mandatory = [ "control" "shift" ]; optional = [ "caps_lock" ]; };
                };
                to = [ { key_code = "c"; modifiers = [ "command" ]; } ];
                conditions = [ inTerminal ];
              }
              {
                type = "basic";
                from = {
                  key_code = "v";
                  modifiers = { mandatory = [ "control" "shift" ]; optional = [ "caps_lock" ]; };
                };
                to = [ { key_code = "v"; modifiers = [ "command" ]; } ];
                conditions = [ inTerminal ];
              }
            ];
          }
        ];
        virtual_hid_keyboard = {
          country_code = 0;
          keyboard_type_v2 = "ansi";
        };
      }
    ];
  };
in
{
  options.karabiner.enable = lib.mkEnableOption "karabiner-elements key remapper";

  config = lib.mkIf config.karabiner.enable {
    homebrew.casks = [ "karabiner-elements" ];

    home-manager.users.jt = {
      home.file.".config/karabiner/karabiner.json".text = karabinerConfig;
    };
  };
}
