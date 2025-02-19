{
  description = "qtile dev";

  # i'm not sure if this is right
  # qtile path is different from the base nixos qtile path
  # should really study up on how to do shit like this
  inputs = {
    main-flake.url = "path:../nix";
  };

  outputs =
    { self, main-flake }:
    let
      pkgs = main-flake.nixosConfigurations.nixos.pkgs;
      system = pkgs.system;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        name = "qtile-dev-shell";
        buildInputs = with pkgs; [
          python3Packages.qtile
          python3Packages.qtile-extras
          python3Packages.python-dateutil

          (writeShellApplication {
            name = "classname";
            runtimeInputs = [ xorg.xprop ];
            text = ''
              xprop | grep WM_CLASS | awk '{print $4}'
            '';
          })
        ];
      };
    };
}
