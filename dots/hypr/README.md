
## TODOS

### critical

- [x] clipmenu broken
- [x] scrolling slow
- [x] what are these mouse binding?

    ```
    bindm = $mainMod, mouse:272, movewindow
    bindm = $mainMod, mouse:273, resizewindow
    ```

- [x] `grim -g "$(slurp)"` not saving copy to clipboard
- [x] opening workspaces on different monitors by simply focusing on it first
- [x] neovim copilot can't accept suggestions?


### enhancements

- [ ] eww laggy af reacting to workspace changes
- [ ] more descriptive workspace names?
- [x] tweak program binds
- [ ] tweak layout settings

## Screenshots

Super+Shift+S opens Flameshot's editor with clipboard output. The Hyprland
startup/shutdown hooks manage NixOS's graphical-session target, which the
desktop portal requires for capture.

Regression check (captures and discards the image, without changing the clipboard):

```bash
timeout 10s env QT_QPA_PLATFORM=wayland flameshot full --raw > /dev/null
```

## Automatic suspend

Click the sleep / coffee icon in either Eww bar to toggle the 30-minute
idle suspend and its 29-minute warning. Yellow coffee means disabled; blue
sleep means enabled. Hover for details. Both bars
refresh their state every second. Manual suspend and display sleep/resume
hooks are unaffected.

The override lives in `$XDG_RUNTIME_DIR`, so it resets when that runtime
directory is cleared (normally on final logout, always on reboot).
The toggle gates timeout actions; it does not restart hypridle's timers.

After changing this config, run `eww reload` and restart hypridle:
`pkill -x hypridle; nohup hypridle > "$XDG_RUNTIME_DIR/hypridle.log" 2>&1 &`.

Regression check: `bash hypr/idle-suspend.test.sh` (no real suspend calls).
