{ self, nixpkgs, nix-darwin, home-manager, ... }:

# Functions that takes a system's name and its configuration,
# and return the appropriate flake output.
let
  lib = nixpkgs.lib;

  mkNixOS = meshFor: name: system:
    let
      mesh = meshFor name;
    in
      lib.nixosSystem {
        system = system.arch; # "x86_64-linux"
        modules = system.modules;
        specialArgs = {
          inherit mesh;
        };
      };

  mkDarwin = meshFor: name: system:
    let
      mesh = meshFor name;
    in
      nix-darwin.lib.darwinSystem {
        modules = system.modules ++ lib.mkIf (system ? "home") [
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users = system.home;
            home-manager.extraSpecialArgs = {
              inherit mesh;
            };
          }
        ];
        specialArgs = {
          inherit self mesh;
        };
      };

  mkHome = meshFor: name: system:
    let
      mesh = meshFor name;
    in
      home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system.arch};

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        modules = system.modules;

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
        extraSpecialArgs = {
          inherit mesh;
        };
      };

  meshFor = devices: folders: device: {
    devices =
      lib.filterAttrs (name: _: name != device) devices;
    folders =
      lib.mapAttrs (_: folder:
        let
          path = folder.path.${device};
          devices = lib.filter (d: d != device) (lib.attrNames folder.path);
        in
          folder // { inherit path devices; }
      )
        (lib.filterAttrs (_: folder: lib.hasAttr device folder.path) folders);
  };
in {
  inherit mkNixOS mkDarwin mkHome meshFor;
}
