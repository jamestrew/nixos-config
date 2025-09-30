#!/usr/bin/env bash

# Power management script for eww control center

case "$1" in
    "sleep")
        systemctl suspend
        ;;
    "reboot")
        systemctl reboot
        ;;
    "shutdown")
        systemctl poweroff
        ;;
    "logout")
        hyprctl dispatch exit
        ;;
    *)
        echo "Usage: $0 {sleep|reboot|shutdown|logout}"
        exit 1
        ;;
esac