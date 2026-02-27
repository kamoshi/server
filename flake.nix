{
  description = "rss-summarizer NixOS service";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    naersk.url = "github:nix-community/naersk";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, naersk, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = (import nixpkgs) {
          inherit system;
        };
        naersk-lib = pkgs.callPackage naersk { };
      in
      {
        packages.rss-summarizer = naersk-lib.buildPackage {
          src = ./.;
        };
        packages.default = self.packages.${system}.rss-summarizer;

        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [ cargo rustc rustfmt rustPackages.clippy ];
        };
      }
    ) // {
      nixosModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.services.rss-summarizer;
        in {
          options.services.rss-summarizer = {
            enable = lib.mkEnableOption "RSS Summarizer Service";
            port = lib.mkOption {
              type = lib.types.port;
              default = 3000;
              description = "Port to listen on.";
            };
            envFile = lib.mkOption {
              type = lib.types.path;
              default = "/var/lib/rss-summarizer/secrets.env";
              description = "Path to environment file.";
            };
            minifluxUrl = lib.mkOption {
              type = lib.types.str;
              default = "http://localhost:8080";
              description = "Miniflux API URL.";
            };
          };

          config = lib.mkIf cfg.enable {
            systemd.services.rss-summarizer = {
              description = "RSS Summarizer Daemon";
              wantedBy = [ "multi-user.target" ];
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];

              serviceConfig = {
                ExecStart = "${self.packages.x86_64-linux.rss-summarizer}/bin/rss-summarizer";
                DynamicUser = true;
                MemoryMax = "64M";
                EnvironmentFile = cfg.envFile;
                Environment = [
                  "PORT=${toString cfg.port}"
                  "MINIFLUX_URL=${cfg.minifluxUrl}"
                ];
                Restart = "always";
                RestartSec = "10s";

                # Hardening options
                CapabilityBoundingSet = "";
                NoNewPrivileges = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                PrivateTmp = true;
                PrivateDevices = true;
              };
            };
          };
        };
    };
}
