{
  description = "Fukurou API Server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    naersk.url = "github:nix-community/naersk";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      naersk,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = (import nixpkgs) {
          inherit system;
        };
        naersk-lib = pkgs.callPackage naersk { };
      in
      {
        packages.fukurou = naersk-lib.buildPackage {
          src = ./.;
        };
        packages.default = self.packages.${system}.fukurou;

        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            cargo
            rustc
            rustfmt
            rustPackages.clippy
          ];
        };
      }
    )
    // {
      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.services.fukurou;
        in
        {
          options.services.fukurou = {
            enable = lib.mkEnableOption "Fukurou Service";

            port = lib.mkOption {
              type = lib.types.port;
              default = 3000;
              description = "Port to listen on.";
            };

            portInternal = lib.mkOption {
              type = lib.types.port;
              default = 3001;
              description = "Port to listen on. (internal)";
            };

            envFile = lib.mkOption {
              type = lib.types.path;
              default = "/var/lib/fukurou/secrets.env";
              description = "Path to environment file.";
            };
          };

          config = lib.mkIf cfg.enable {
            systemd.services.fukurou = {
              description = "Fukurou Daemon";
              wantedBy = [ "multi-user.target" ];
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];

              serviceConfig = {
                ExecStart = "${self.packages.x86_64-linux.fukurou}/bin/fukurou";
                DynamicUser = true;
                StateDirectory = "fukurou";
                MemoryMax = "64M";
                EnvironmentFile = cfg.envFile;
                Environment = [
                  "PORT=${toString cfg.port}"
                  "PORT_INTERNAL=${toString cfg.portInternal}"
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
