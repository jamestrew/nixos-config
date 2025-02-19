#!/usr/bin/env bash

xrandr \
  --output DP-2 --mode 3440x1440 --pos 0x1080 --rotate normal \
  --output HDMI-1 --mode 1920x1080 --pos 760x0 --rotate normal \
  --output DP-1 --off \
  --output DP-3 --off

picom --experimental-backends &
# clipmenud &
# nitrogen --restore &
discord &
youtube-music &
# obsidian &
ghostty &
firefox &
fcitx5 &

