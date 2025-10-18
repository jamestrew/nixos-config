#!/usr/bin/env bash

set -euo pipefail

# swaync event stream -> eww bridge. Forwards JSON to stdout (for deflisten)
# while also syncing the control-center window visibility with swaync.

eww_bin=${EWW_BINARY:-eww}

open_control_center() {
  "$eww_bin" open control-center >/dev/null 2>&1 || true
}

close_control_center() {
  "$eww_bin" close control-center >/dev/null 2>&1 || true
}

while IFS= read -r line; do
  [ -z "$line" ] && continue

  printf '%s\n' "$line"

  visible_flag=$(jq -r 'try .visible catch empty' <<<"$line" 2>/dev/null || echo "")

  case "$visible_flag" in
    true)
      open_control_center
      ;;
    false)
      close_control_center
      ;;
  esac
done < <(swaync-client --subscribe 2>/dev/null)
