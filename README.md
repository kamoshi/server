# System Configurations

This repository contains declarative system configurations for multiple systems using Nix flakes.

## Features

- Darwin support via `nix-darwin`.
- Home environment management via `home-manager`.
- Secrets provisioning via `sops-nix`.
- Modular and reusable host definitions.
- Flake-based for reproducibility and easy updates.

## Hosts

| Host     | Type           | Description                                                    | Build Command                           |
| -------- | -------------- | -------------------------------------------------------------- | --------------------------------------- |
| `aya`    | macOS (Darwin) | Uses `nix-darwin` and `home-manager`.                          | `darwin-rebuild switch --flake .#aya`   |
| `momiji` | Arch Linux     | Home environment configuration via `home-manager`.             | `home-manager switch --flake .#momiji`  |
| `megumu` | NixOS          | Full NixOS system configuration; includes `sops-nix` module.   | `nixos-rebuild switch --flake .#megumu` |
