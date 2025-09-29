#!/usr/bin/env bash

# Hyprland workspace widget for eww

generate_workspaces() {
    local monitor_id=$1
    if ! command -v hyprctl &> /dev/null || ! command -v jq &> /dev/null; then
        echo "(label :text \"Error: hyprctl or jq not found\")"
        return
    fi
    local monitors_json; monitors_json=$(hyprctl monitors -j)
    if [ $? -ne 0 ]; then echo "(label :text \"err: hyprctl monitors failed\")"; return; fi
    local workspaces_json; workspaces_json=$(hyprctl workspaces -j)
    if [ $? -ne 0 ]; then echo "(label :text \"err: hyprctl workspaces failed\")"; return; fi
    local active_ws; active_ws=$(echo "$monitors_json" | jq ".[] | select(.id == $monitor_id) | .activeWorkspace.id")
    local widget_content="(box :orientation \"horizontal\" :spacing 2"
    for i in {1..7}; do
        local ws_info; ws_info=$(echo "$workspaces_json" | jq ".[] | select(.id == $i)")
        class="workspace"
        if [ -n "$ws_info" ]; then
            if [ "$(echo "$ws_info" | jq '.windows')" -gt 0 ]; then
                class="$class occupied"
            fi
        fi
        if [ "$active_ws" == "$i" ]; then
            class="$class active"
        fi
        widget_content="$widget_content (button :class \"$class\" :onclick \"hyprctl dispatch workspace $i\" \"$i\")"
    done
    widget_content="$widget_content)"
    echo "$widget_content"
}


monitor_id="${1:-0}"

# Initial generation
generate_workspaces "$monitor_id"

# Find socket path
SOCKET_PATH=$(find /tmp/hypr/ -type f -name ".socket2.sock" 2>/dev/null | head -n 1)

# Listen for events if socat and socket are available
if command -v socat &> /dev/null && [ -n "$SOCKET_PATH" ]; then
    socat -u UNIX-CONNECT:"$SOCKET_PATH" - | while read -r event; do
        case "$event" in
            workspace* | createworkspace* | destroyworkspace* | monitor* | activewindow*) 
                generate_workspaces "$monitor_id"
                ;; 
        esac
    done
else
    # Fallback for when socat is not installed or socket not found
    while true; do
        sleep 2
        generate_workspaces "$monitor_id"
    done
fi