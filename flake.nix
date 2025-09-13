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
    shared = import ./shared inputs;
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
          ./hosts/aya
        ];
        home = {
          kamov = ./home/kamov;
        };
      };

      # momiji
      momiji = {
        id = "24FX4TW-B2RVLIO-DXXDZWP-4XQAE4H-NHKLMLK-5SJZCIV-45OBS2N-MJEYNQ2";
        name = "Momiji";
        type = Type.Home;
        arch = "x86_64-linux";
        modules = [
          ./home/kamov
        ];
      };

      # hatate
      hatate = {
        id = "IF63A73-XV6LEZS-UZH7DEU-CPOJVEN-OQ3CEWZ-KHVNC5U-KNFCLLD-S7MOXAW";
        name = "Hatate";
      };

      # megumu
      megumu = {
        id = "PDY7ZC6-GP7YQYO-QSA7HGR-BNWTEBQ-XYON6T4-RK365LH-JWCSYLF-UZQECQV";
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
    };

    meshFor = shared.meshFor devices folders;
  in
    {
      nixosConfigurations = lib.pipe devices [
        (lib.filterAttrs (matches Type.NixOS))
        (lib.mapAttrs (shared.mkNixOS meshFor))
      ];

      # Build darwin flake using:
      # $ darwin-rebuild build --flake .#aya
      darwinConfigurations = lib.pipe devices [
        (lib.filterAttrs (matches Type.Darwin))
        (lib.mapAttrs (shared.mkDarwin meshFor))
      ];

      homeConfigurations = lib.pipe devices [
        (lib.filterAttrs (matches Type.Home))
        (lib.mapAttrs (shared.mkHome meshFor))
      ];
    };
}
