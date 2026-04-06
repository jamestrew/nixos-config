{
  description = "nixos config";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "nixpkgs/nixos-25.11";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # get signed bootloader for secure boot (mostly for win11 dual boot secure boot)
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.3";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents.url = "github:numtide/llm-agents.nix";
    handy.url = "github:cjpais/Handy";

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      nix-homebrew,
      home-manager,
      lanzaboote,
      nur,
      ...
    }@inputs:
    let
      mkPlatformArgs =
        system:
        let
          isDarwin = builtins.match ".*-darwin" system != null;
        in
        {
          inherit system isDarwin;
          isLinux = !isDarwin;
        };
    in
    {
      nixosConfigurations.nixos =
        let
          platform = mkPlatformArgs "x86_64-linux";
        in
        nixpkgs.lib.nixosSystem {
          inherit (platform) system;
          specialArgs = {
            inherit inputs;
          }
          // platform;
          modules = [
            nur.modules.nixos.default
            lanzaboote.nixosModules.lanzaboote
            inputs.handy.nixosModules.default
            ./hosts/main/configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = platform;
                users.jt = {
                  imports = [
                    ./hosts/main/home.nix
                    ./modules/home
                  ];
                };
                sharedModules = [
                  inputs.sops-nix.homeManagerModules.sops
                  inputs.handy.homeManagerModules.default
                ];
                backupFileExtension = "backup";
              };
            }
          ];
        };

      darwinConfigurations."Jamess-MacBook-Air" =
        let
          platform = mkPlatformArgs "aarch64-darwin";
        in
        nix-darwin.lib.darwinSystem {
          inherit (platform) system;
          specialArgs = {
            inherit inputs self;
          }
          // platform;
          modules = [
            nix-homebrew.darwinModules.nix-homebrew
            ./hosts/mac/configuration.nix
            home-manager.darwinModules.home-manager
            {
              networking.hostName = "Jamess-MacBook-Air";

              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = platform;
                users.jt = {
                  imports = [
                    ./hosts/mac/home.nix
                    ./modules/home
                  ];
                };
                sharedModules = [ inputs.sops-nix.homeManagerModules.sops ];
                backupFileExtension = "backup";
              };
            }
          ];
        };

    };
}
