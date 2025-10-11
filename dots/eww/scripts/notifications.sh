#!/usr/bin/env bash

get_notification_info() {
  count=$(swaync-client --count 2>/dev/null || echo "0")
  count=${count:-0}

  if [ "$count" -gt 0 ]; then
    has_notifications="true"
  else
    has_notifications="false"
  fi

  echo "{\"count\": $count, \"has_notifications\": $has_notifications}"
}

case "${1:-}" in
  "")
    get_notification_info

    swaync-client --subscribe 2>/dev/null | while read -r line; do
      get_notification_info
    done
    ;;
  *)
    echo "Usage: $0" >&2
    echo "  No args: continuous monitoring" >&2
    exit 1
    ;;
esac
