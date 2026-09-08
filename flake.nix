{
  description = "Fukurou API Server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      lib = nixpkgs.lib;

      serverSystem = "x86_64-linux";
      serverPkgs = import nixpkgs { system = serverSystem; };

      devSystems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      fukurou = serverPkgs.rustPlatform.buildRustPackage {
        pname = "fukurou";
        version = "0.1.0";
        src = ./.;

        cargoLock.lockFile = ./Cargo.lock;

        nativeBuildInputs = with serverPkgs; [ pkg-config ];
        buildInputs = with serverPkgs; [ sqlite ];
      };
    in
    {
      packages.${serverSystem} = {
        inherit fukurou;
        default = fukurou;
      };

      devShells = lib.genAttrs devSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            nativeBuildInputs = with pkgs; [
              cargo
              rustc
              rustfmt
              rustPackages.clippy
              pkg-config
            ];
            buildInputs = with pkgs; [ sqlite ];
          };
        }
      );

      nixosModules.default =
        { config, lib, ... }:
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
                ExecStart = "${fukurou}/bin/fukurou";
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
