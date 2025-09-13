# System Configurations

This repository contains declarative system configurations for all of my
computers using Nix flakes. Each host also has its own unique ID which is used
for syncing with Syncthing.

## Features

- Darwin support via `nix-darwin`
- Home environment management via `home-manager`
- Secrets provisioning via `sops-nix`
- Fully integrated with Syncthing

## Hosts

| Host     | Type           | Description                                                    | Build Command                           |
| -------- | -------------- | -------------------------------------------------------------- | --------------------------------------- |
| `aya`    | macOS (Darwin) | Uses `nix-darwin` and `home-manager`.                          | `darwin-rebuild switch --flake .#aya`   |
| `momiji` | Arch Linux     | Home environment configuration via `home-manager`.             | `home-manager switch --flake .#momiji`  |
| `megumu` | NixOS          | Full NixOS system configuration; includes `sops-nix` module.   | `nixos-rebuild switch --flake .#megumu` |
| `nitori` | Arch Linux     | Home environment configuration via `home-manager`.             | `home-manager switch --flake .#nitori`  |
