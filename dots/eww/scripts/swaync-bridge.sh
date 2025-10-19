#!/usr/bin/env bash

set -euo pipefail

# swaync event stream -> eww bridge. Forwards JSON to stdout (for deflisten)
# while also syncing the control-center window visibility with swaync.


open_control_center() {
  eww open control-center >/dev/null 2>&1 || true
}

close_control_center() {
  eww close control-center >/dev/null 2>&1 || true
}

prev_visible=""

while IFS= read -r line; do
  [ -z "$line" ] && continue

  printf '%s\n' "$line"

  visible_flag=$(jq -r 'try .visible catch empty' <<<"$line" 2>/dev/null || echo "")

  if [[ "$visible_flag" == "true" || "$visible_flag" == "false" ]]; then
    if [[ "$visible_flag" != "$prev_visible" ]]; then
      case "$visible_flag" in
        true)
          open_control_center
          ;;
        false)
          close_control_center
          ;;
      esac
      prev_visible="$visible_flag"
    fi
  fi
done < <(swaync-client --subscribe 2>/dev/null)
