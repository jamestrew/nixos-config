# Hyprland Setup Notes

## Overview
This is a Hyprland setup for NixOS using flakes and home-manager, designed to mimic the existing qtile configuration as closely as possible.

## Configuration Structure

### NixOS Module (`nix/modules/sys/hyprland.nix`)
- **Purpose**: System-level Hyprland setup and dependencies
- **Key Features**:
  - Enables Hyprland with XWayland support
  - Installs Wayland/Hyprland packages (waybar, wofi, grim, slurp, etc.)
  - Sets up Hypr ecosystem tools (hyprlock, hypridle, hyprpaper, hyprsunset)
  - Configures greetd display manager for Wayland
  - Enables audio (PipeWire) and desktop integration (XDG portals)

### Dotfiles (`dots/hyprland/`)
- **hyprland.conf**: Main Hyprland configuration mimicking qtile keybinds and behavior
- **waybar/**: Status bar configuration with OneDark theme
- **wofi/**: Application launcher configuration

## Key Mappings (Qtile → Hyprland)

### Window Management
- `Super+J/K`: Focus prev/next window (same)
- `Super+Shift+J/K`: Move windows (same)
- `Super+H/L`: Resize windows (same)
- `Super+Space`: Toggle fullscreen (same)
- `Super+F`: Toggle floating (same)
- `Super+C`: Kill window (same)

### Application Launchers
- `Super+P`: Launch wofi (replaces rofi)
- `Super+O`: Application submenu (same structure as qtile KeyChord)
  - `T`: Terminal (ghostty)
  - `B`: Browser (brave)
  - `D`: Discord
  - `R`: File manager (ghostty -e yazi)
  - `O`: Obsidian

### Screenshots
- `Super+Shift+S`: Interactive screenshot (grim + slurp, replaces flameshot)

### Media Keys
- Volume, media controls: Same as qtile

## Tool Replacements

| Qtile/X11 | Hyprland/Wayland | Notes |
|-----------|------------------|-------|
| rofi | wofi | Application launcher |
| flameshot | grim + slurp | Screenshots |
| dunst | swaync | Notifications with control center |
| redshift | hyprsunset | Blue light filtering |
| picom | Built-in | Compositor effects |
| qtile status bar | waybar | Status bar |

## Theme
- **Colors**: OneDark theme (same as qtile)
- **Fonts**: Source Code Pro (monospace)
- **Styling**: Consistent across waybar, wofi, and Hyprland

## Services Migration

### Moving from qtile.nix to hyprland.nix:
- Audio tools (pavucontrol, alsa-utils): Shared between both
- clipmenu, playerctld: Shared services
- X11-specific: picom, rofi, dunst → stay in qtile.nix
- Wayland-specific: waybar, wofi, swaync → in hyprland.nix

## Next Steps

1. **Enable the module**: Add `hyprland.enable = true;` to configuration.nix
2. **Link dotfiles**: Add hyprland configs to home.nix:
   ```nix
   ".config/hypr".source = ../../../dots/hyprland;
   ```
3. **Disable qtile services when using Hyprland**: Conditional redshift, etc.
4. **Test and iterate**: Fine-tune keybinds, colors, and behavior

## Troubleshooting

### Common Issues:
- **Missing desktop session**: Make sure NixOS module is enabled
- **Audio not working**: Check PipeWire service status
- **Apps not launching**: Verify XDG portals are working
- **Screenshots not working**: Check grim/slurp installation

### Debugging Commands:
```bash
# Check Hyprland status
hyprctl version
hyprctl monitors

# Check services
systemctl --user status pipewire
systemctl status greetd

# Test tools
waybar &
wofi --show run
swaync-client -t
```

## Recent Fixes

1. **Fixed Hyprland config options**:
   - `new_is_master` → `new_status = master`
   - `drop_shadow` → `dropshadow`

2. **Updated monitor setup** to match qtile startup script:
   ```
   monitor=DP-2,3440x1440@60,0x1080,1
   monitor=HDMI-1,1920x1080@60,760x0,1
   ```

3. **Fixed wofi theme** to match rofi Arc-Dark style:
   - Width: 800px (matching rofi)
   - Arc-Dark color scheme
   - Better font and styling

4. **Fixed tuigreet startup logs**:
   - Added `vt = 7` to use VT 7
   - Added `--remember` flags for session persistence

5. **Added startup applications** from qtile startup.sh:
   - fcitx5, dropbox, discord, youtube-music, udiskie, brave

## Configuration Files Location

```
dots/hypr/               # Note: directory is 'hypr' not 'hyprland'
├── hyprland.conf        # Main Hyprland config
├── waybar/
│   ├── config.json      # Waybar modules and layout
│   └── style.css        # OneDark styling
└── wofi/
    ├── config           # Wofi behavior (800px width)
    └── style.css        # Arc-Dark inspired styling
```



# Critical Issues - RESOLVED

## Fixed Issues:

- [x] **qtile functionality broken** -> Fixed by adding proper X11 display manager (lightdm) to qtile.nix
- [x] **waybar config not working** -> Fixed by linking `~/.config/waybar` separately using the `link` function
- [x] **wofi config needs similar treatment** -> Fixed by linking `~/.config/wofi` separately using the `link` function  
- [x] **hyprland monitor config** -> Fixed positioning:
  - HDMI-1 (1080p): `760x0` (centered on top)
  - DP-2 (1440p): `0x1080` (bottom, full width)
- [x] **switch off tuigreet** -> Replaced with SDDM which supports:
  - Multi-monitor scaling
  - No systemd log conflicts
  - Better Wayland support

## Solutions Applied:

### 1. Qtile Fix (`qtile.nix`)
```nix
services.xserver = {
  enable = true;
  displayManager = {
    lightdm.enable = lib.mkDefault true;
  };
  // ... rest of qtile config
};
```

### 2. Hyprland Display Manager (`hyprland.nix`) 
```nix
# Use SDDM instead of tuigreet
services.displayManager.sddm = {
  enable = lib.mkDefault true;
  wayland.enable = true;
};
services.greetd.enable = lib.mkForce false;
```

### 3. Config Linking (`home.nix`)
```nix
".config/hypr".source = link "${dots}/hypr";
".config/waybar".source = link "${dots}/hypr/waybar";  # Separate link for waybar
".config/wofi".source = link "${dots}/hypr/wofi";      # Separate link for wofi
```

### 4. Monitor Layout (`hyprland.conf`)
```
# 1080p centered above 1440p
monitor=HDMI-1,1920x1080@60,760x0,1      # Top, centered
monitor=DP-2,3440x1440@60,0x1080,1       # Bottom, full width
```

## Testing:
1. `sudo nixos-rebuild switch` to apply system changes
2. `home-manager switch` to apply home config changes  
3. Reboot and test both window managers from SDDM


