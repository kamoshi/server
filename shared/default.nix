{ self, nixpkgs, nix-darwin, home-manager, ... }:

# Functions that takes a system's name and its configuration,
# and return the appropriate flake output.
let
  lib = nixpkgs.lib;

  maybeAttachHome = type: mesh: system:
    if system ? "home"
      then [
        home-manager."${type}Modules".home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users = system.home;
          home-manager.extraSpecialArgs = {
            inherit mesh;
          };
        }
      ]
      else [];

  mkNixOS = meshFor: name: system:
    let
      mesh = meshFor name;
    in
      lib.nixosSystem {
        system = system.arch; # "x86_64-linux"
        modules = system.modules ++ maybeAttachHome "nixos" mesh system;
        specialArgs = {
          inherit self mesh;
        };
      };

  mkDarwin = meshFor: name: system:
    let
      mesh = meshFor name;
    in
      nix-darwin.lib.darwinSystem {
        modules = system.modules ++ maybeAttachHome "darwin" mesh system;
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
      lib.pipe devices [
        (lib.filterAttrs (name: _: name != device))
        (lib.mapAttrs (_: system: { inherit (system) id name; }))
      ];
    folders =
      lib.pipe folders [
        (lib.filterAttrs (_: folder: lib.hasAttr device folder.path))
        (lib.mapAttrs (_: folder: folder // {
          path = folder.path.${device};
          devices = lib.filter (d: d != device) (lib.attrNames folder.path);
        }))
      ];
  };
in {
  inherit mkNixOS mkDarwin mkHome meshFor;
}
