#!/usr/bin/env bash

generate_workspaces() {
  local monitor_id=$1
  monitors_json=$(hyprctl monitors -j)
  workspaces_json=$(hyprctl workspaces -j)
  local active_ws; active_ws=$(echo "$monitors_json" | jq ".[] | select(.id == $monitor_id) | .activeWorkspace.id")
  local widget_content="(box :orientation \"horizontal\" :spacing 2"
  for i in {1..10}; do
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
    widget_content="$widget_content (button :class \"$class\" :onclick \"hyprctl dispatch focusworkspaceoncurrentmonitor $i\" \"$i\")"
  done
  widget_content="$widget_content)"
  echo "$widget_content"
}


monitor_id="${1:-0}"

generate_workspaces "$monitor_id"

socat -u UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" - | while read -r _line; do
generate_workspaces "$monitor_id"
done
