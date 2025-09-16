inputs@{ self, nixpkgs, nix-darwin, home-manager, ... }:
# Functions that takes a system's name and its configuration,
# and return the appropriate flake output.
let
  utilHome = import ./home.nix inputs;
  lib = nixpkgs.lib;

  maybeAttachHome = type: mesh: device:
    if device ? "home"
      then [
        home-manager."${type}Modules".home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users = device.home;
          home-manager.extraSpecialArgs = {
            inherit device mesh;
            utils = { home = utilHome; };
          };
        }
      ]
      else [];

  mkNixOS = meshFor: key: device:
    let
      mesh = meshFor key;
    in
      lib.nixosSystem {
        system = device.arch; # "x86_64-linux"
        modules = device.modules ++ maybeAttachHome "nixos" mesh device;
        specialArgs = {
          inherit self device mesh;
        };
      };

  mkDarwin = meshFor: key: device:
    let
      mesh = meshFor key;
    in
      nix-darwin.lib.darwinSystem {
        system = device.arch;
        modules = device.modules ++ maybeAttachHome "darwin" mesh device;
        specialArgs = {
          inherit self mesh device;
        };
      };

  mkHome = meshFor: key: device:
    let
      mesh = meshFor key;
    in
      home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${device.arch};

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        modules = device.modules;

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
        extraSpecialArgs = {
          inherit device mesh;
          utils = { home = utilHome; };
        };
      };

  meshFor = devices: folders: key: {
    devices =
      lib.pipe devices [
        (lib.filterAttrs (other: _: other != key))
        (lib.mapAttrs (_: device: { inherit (device) id name; }))
      ];
    folders =
      lib.pipe folders [
        (lib.filterAttrs (_: folder: lib.hasAttr key folder.path))
        (lib.mapAttrs (_: folder: folder // {
          path = folder.path.${key};
          devices = lib.filter (other: other != key) (lib.attrNames folder.path);
        }))
      ];
  };
in {
  inherit mkNixOS mkDarwin mkHome meshFor;
}
