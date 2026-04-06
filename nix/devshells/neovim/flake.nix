# Neovim dev flake — build deps from the nightly overlay, manual build from source.
#
# Persistent via direnv from ~/projects/neovim:
#   echo 'use flake ~/nixos-config/nix/devshells/neovim' > .envrc && direnv allow
#
{
  description = "neovim dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      neovim-nightly-overlay,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);

      # Compute all per-system outputs in one pass so neovim-dev is defined once.
      systemOutputs = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          # Re-import nixpkgs with the overlay applied. We then override
          # tree-sitter back to the system version to avoid the bundled
          # tree-sitter's fetchCargoVendor FOD hash mismatch.
          overlayPkgs = import nixpkgs {
            inherit system;
            overlays = [ neovim-nightly-overlay.overlays.default ];
          };

          neovim-dev = overlayPkgs.neovim-unwrapped.override {
            tree-sitter = pkgs.tree-sitter;
          };

          # Use llvm stdenv on linux so llvm-symbolizer can decode ASAN reports
          stdenv = if pkgs.stdenv.isLinux then pkgs.llvmPackages_latest.stdenv else pkgs.stdenv;
        in
        {
          packages.default = neovim-dev;

          devShells.default = (pkgs.mkShell.override { inherit stdenv; }) {
            name = "neovim-dev";
            inputsFrom = [ neovim-dev ];
            packages = with pkgs; [
              ccache
              ninja
              llvmPackages_latest.llvm
              (python3.withPackages (ps: [ ps.msgpack ]))
              (writeShellScriptBin "nvim-install" "nix profile add path:${self}#packages.${system}.default")
            ];
            shellHook = ''
              export VIMRUNTIME=$PWD/runtime
              export ASAN_SYMBOLIZER_PATH=${pkgs.llvmPackages_latest.llvm}/bin/llvm-symbolizer
              export ASAN_OPTIONS="log_path=./asan.log:abort_on_error=1"
            '';
          };
        }
      );
    in
    {
      packages = builtins.mapAttrs (_: s: s.packages) systemOutputs;
      devShells = builtins.mapAttrs (_: s: s.devShells) systemOutputs;
    };
}
