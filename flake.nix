{
  description = "System configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    # Sops-nix - secret provisioning
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, sops-nix, nix-darwin, home-manager, ... }: {
    # aya
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#aya
    darwinConfigurations."aya" = nix-darwin.lib.darwinSystem {
      modules = [
        home-manager.darwinModules.home-manager
        ./hosts/aya
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.kamov = import ./home/kamov;
        }
      ];
      specialArgs = {
        inherit self;
      };
    };

    # momiji
    homeConfigurations."momiji" =
      let
        system = "x86_64-linux";
        pkgs = nixpkgs.legacyPackages.${system};
      in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          # Specify your home configuration modules here, for example,
          # the path to your home.nix.
          modules = [ ./home/kamov ];

          # Optionally use extraSpecialArgs
          # to pass through arguments to home.nix
        };

    # megumu
    nixosConfigurations = {
      megumu = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          sops-nix.nixosModules.sops
          ./hosts/megumu
        ];
      };
    };
  };
}
