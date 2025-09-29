#!/usr/bin/env bash

# Hyprland layout/mode widget for eww

generate_layout_widget() {
    if ! command -v hyprctl &> /dev/null || ! command -v jq &> /dev/null;
 then
        echo "(label :text \"E\")"
        return
    fi
    local active_window; active_window=$(hyprctl activewindow -j 2>/dev/null)
    local is_floating="false"
    if [ -n "$active_window" ]; then
        is_floating=$(echo "$active_window" | jq -r '.floating')
    fi
    local layout_icon="󰙀" # Tiling icon
    if [ "$is_floating" == "true" ]; then
        layout_icon="󰀜" # Floating icon
    fi
    echo "(label :class \"layout\" :text \"$layout_icon\")"
}

# Initial generation
generate_layout_widget

# Find socket path
SOCKET_PATH=$(find /tmp/hypr/ -type f -name ".socket2.sock" 2>/dev/null | head -n 1)

if command -v socat &> /dev/null && [ -n "$SOCKET_PATH" ]; then
    socat -u UNIX-CONNECT:"$SOCKET_PATH" - | while read -r event;
 do
        case "$event" in
            activewindow* | changefloatingmode*) 
                generate_layout_widget
                ;; 
        esac
    done
else
    while true; do
        sleep 2
        generate_layout_widget
    done
fi
