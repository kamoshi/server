{ nixpkgs, ... }:
let
  symlink = config: dirs: nixpkgs.lib.genAttrs dirs (path: {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix/config/${path}";
  });
in {
  inherit symlink;
}
