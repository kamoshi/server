{
  description = "System configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    # aarch64-darwin
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # dotfiles
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # secrets
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, sops-nix, ... }:
  let
    util = import ./util inputs;
    lib = nixpkgs.lib;

    Type = {
      NixOS  = 0;
      Darwin = 1;
      Home   = 2;
    };

    matches = type: _: system:
      system ? "type" && system.type == type;

    devices = {
      # aya
      aya = {
        id = "K53ML2R-XXPRH3Z-SB7RKVP-UZCWTDA-636J5O4-442XL3U-O7ZA7Y4-K4THEQY";
        name = "Aya";
        type = Type.Darwin;
        arch = "aarch64-darwin";
        modules = [
          # Let Determinate Nix handle Nix configuration
          ({ ... }: { nix.enable = false; })
          sops-nix.darwinModules.sops
          ./hosts/aya
        ];
        home = {
          kamov = ./home/kamov;
        };
        vpn = {
          ip = "10.0.0.4";
          pubkey = "sJ5ri5XPMgsMsHTZVR9mzo02JRubA13Zoh6lKNMTqEE=";
        };
      };

      # momiji
      momiji = {
        id = "24FX4TW-B2RVLIO-DXXDZWP-4XQAE4H-NHKLMLK-5SJZCIV-45OBS2N-MJEYNQ2";
        name = "Momiji";
        type = Type.Home;
        arch = "x86_64-linux";
        modules = [
          inputs.sops-nix.homeManagerModules.sops
          ./home/kamov
        ];
        vpn = {
          ip = "10.0.0.2";
          pubkey = "9UISV736vJr39rHCvTuJeF72vjSxnD8DJgF0NZYzLTU=";
        };
      };

      # hatate
      hatate = {
        id = "IF63A73-XV6LEZS-UZH7DEU-CPOJVEN-OQ3CEWZ-KHVNC5U-KNFCLLD-S7MOXAW";
        name = "Hatate";
        vpn = {
          ip = "10.0.0.3";
          pubkey = "ro/HmBKJv/U2gWHByO88eBFeNoG9tOSPn37daENA6zY=";
        };
      };

      # megumu
      megumu = {
        id = "3R3IGHH-6Y2WZHC-R6EYP3U-55TP653-I4UMF3V-KIY3DUA-GCEQRYS-3BXBBQD";
        name = "Megumu";
        type = Type.NixOS;
        arch = "x86_64-linux";
        modules = [
          sops-nix.nixosModules.sops
          ./hosts/megumu
        ];
        home = {
          kamov = ./home/server;
        };
        vpn = {
          ip = "10.0.0.1";
          pubkey = "DML57aZ4EKYT330ncFL5j6aj4wlWyArfKzwjuCF0jAs=";
          server = true;
          endpoint = "94.130.182.219";
        };
      };

      # nitori
      nitori = {
        id = "4SIJHMJ-6RR5KGV-E53GPIR-MJOZ3PO-4KSKIXP-T7DYO3J-2AP2TGI-GD524A6";
        name = "Nitori";
        type = Type.Home;
        arch = "x86_64-linux";
        modules = [
          ./home/work
        ];
      };
    };

    folders = {
      nix = {
        id = "nix";
        label = "Nix";
        path = {
          aya = "~/nix";
          momiji = "~/nix";
          megumu = "~/nix";
          nitori = "~/nix";
        };
      };
      workspace = {
        id = "workspace";
        label = "Workspace";
        path = {
          aya = "~/Desktop/Workspace";
          momiji = "~/Desktop/Workspace";
          megumu = "/data/sync/workspace";
        };
      };
      calibre = {
        id = "calibre";
        label = "Calibre";
        path = {
          aya = "~/calibre";
          momiji = "~/calibre";
          megumu = "/data/sync/calibre";
        };
      };
      photos = {
        id = "photos";
        label = "Photos";
        path = {
          aya = "~/Desktop/Photos";
          hatate = "~/DCIM";
          momiji = "~/Desktop/Photos";
        };
      };
    };

    meshFor = util.meshFor devices folders;
    vpnFor = util.vpnFor devices;
  in
    {
      nixosConfigurations = lib.pipe devices [
        (lib.filterAttrs (matches Type.NixOS))
        (lib.mapAttrs (key: device: device // { inherit key; }))
        (lib.mapAttrs (util.mkNixOS meshFor vpnFor))
      ];

      # Build darwin flake using:
      # $ darwin-rebuild build --flake .#aya
      darwinConfigurations = lib.pipe devices [
        (lib.filterAttrs (matches Type.Darwin))
        (lib.mapAttrs (key: device: device // { inherit key; }))
        (lib.mapAttrs (util.mkDarwin meshFor vpnFor))
      ];

      homeConfigurations = lib.pipe devices [
        (lib.filterAttrs (matches Type.Home))
        (lib.mapAttrs (key: device: device // { inherit key; }))
        (lib.mapAttrs (util.mkHome meshFor vpnFor))
      ];
    };
}
