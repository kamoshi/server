{ device, lib, ... }:
let
  devices = {
    aya = {
      name = "Aya";
      id = "K53ML2R-XXPRH3Z-SB7RKVP-UZCWTDA-636J5O4-442XL3U-O7ZA7Y4-K4THEQY";
    };
    momiji = {
      name = "Momiji";
      id = "24FX4TW-B2RVLIO-DXXDZWP-4XQAE4H-NHKLMLK-5SJZCIV-45OBS2N-MJEYNQ2";
    };
    hatate = {
      name = "Hatate";
      id = "IF63A73-XV6LEZS-UZH7DEU-CPOJVEN-OQ3CEWZ-KHVNC5U-KNFCLLD-S7MOXAW";
    };
    megumu = {
      name = "Megumu";
      id = "PDY7ZC6-GP7YQYO-QSA7HGR-BNWTEBQ-XYON6T4-RK365LH-JWCSYLF-UZQECQV";
    };
    nitori = {
      name = "Nitori";
      id = "4SIJHMJ-6RR5KGV-E53GPIR-MJOZ3PO-4KSKIXP-T7DYO3J-2AP2TGI-GD524A6";
    };
  };

  folders = {
    nix = {
      label = "Nix";
      id = "nix";
      path = {
        aya = "~/nix";
        momiji = "~/nix";
        megumu = "~/nix";
        nitori = "~/nix";
      };
    };
    workspace = {
      label = "Workspace";
      id = "workspace";
      path = {
        aya = "~/Desktop/Workspace";
        momiji = "~/Desktop/Workspace";
        megumu = "/data/sync/workspace";
      };
    };
  };

  filteredDevices =
    lib.filterAttrs (name: _: name != device) devices;

  filteredFolders =
    lib.mapAttrs (_: folder:
      let
        path = folder.path.${device};
        devices = lib.filter (d: d != device) (lib.attrNames folder.path);
      in
        folder // { inherit path devices; }
    )
      (lib.filterAttrs (_: folder: lib.hasAttr device folder.path) folders);

in {
  devices = filteredDevices;
  folders = filteredFolders;
}
