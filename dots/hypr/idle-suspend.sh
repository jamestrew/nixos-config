#!/usr/bin/env bash
set -euo pipefail

# Runtime-only override: leave hypridle running for its sleep/resume hooks.
disabled="${XDG_RUNTIME_DIR:?}/hypridle-suspend-disabled"

case "${1:-status}" in
  status)
    if [[ -e "$disabled" ]]; then echo false; else echo true; fi
    ;;
  toggle)
    if [[ -e "$disabled" ]]; then rm -- "$disabled"; else touch -- "$disabled"; fi
    ;;
  warn)
    if [[ ! -e "$disabled" ]]; then
      notify-send "System Idle" "Suspending in 1 minute due to inactivity" -u critical
    fi
    ;;
  suspend)
    if [[ ! -e "$disabled" ]]; then systemctl suspend; fi
    ;;
  *)
    echo "Usage: $0 {status|toggle|warn|suspend}" >&2
    exit 2
    ;;
esac
