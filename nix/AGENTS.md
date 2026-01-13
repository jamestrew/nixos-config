# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Structure

Personal NixOS configuration using flakes and home-manager.

- `flake.nix` - Main flake defining nixosConfiguration for host "nixos"
- `hosts/main/` - Host-specific system config and home-manager entry point
- `modules/sys/` - System-level NixOS modules (apps, env, gaming, hyprland, qtile, nordvpn, etc)
- `modules/home/` - Home-manager modules
- `overlays/` - Nixpkgs overlays
- `secrets/` - sops-nix encrypted secrets
- `../dots/` - Dotfiles (nvim, tmux, hypr, etc) symlinked by home-manager

## Key Flake Inputs

- `nixpkgs` (unstable), `nixpkgs-stable` (nixos-25.11)
- `home-manager` (github:nix-community/home-manager @ fbd566923adcfa67be512a14a79467e2ab8a5777)
- `sops-nix` - secrets management
- `lanzaboote` - secure boot support
- `fenix` - Rust toolchain
- `nur` - Nix User Repository

## System Architecture

Main configuration loads `hosts/main/configuration.nix`, which:
1. Imports `modules/sys` (system modules)
2. Enables custom modules via boolean flags (qtile.enable, hyprland.enable, gaming.enable, nordvpn.enable)
3. Configures home-manager for user "jt" with `hosts/main/home.nix` + `modules/home`

Home-manager uses out-of-store symlinks to `../dots/` for frequently-edited configs (nvim, tmux, hypr, etc).

## Build/Deploy Commands

```bash
# Rebuild system (nh uses NH_FLAKE env var)
nh os switch

# Update flake inputs
nh os switch --update

# Test config without switching
nh os test

# Home-manager only
home-manager switch --flake .#jt@nixos
```

## Module Pattern

Custom modules in `modules/sys/` use `mkIf config.<name>.enable` pattern. To add functionality:
1. Create module file in `modules/sys/`
2. Import in `modules/sys/default.nix`
3. Enable in `hosts/main/configuration.nix` via `<name>.enable = true;`

## Environment Variables

- `FLAKE` and `NH_FLAKE` point to `/home/jt/nixos-config/nix` (set in home.nix)
- `EDITOR` is nvim
