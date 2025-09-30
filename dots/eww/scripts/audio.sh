#!/usr/bin/env bash

# Unified audio script for eww
# Usage:
#   audio.sh              -> continuous monitoring (for deflisten)
#   audio.sh up           -> increase volume
#   audio.sh down         -> decrease volume
#   audio.sh toggle_mute  -> toggle mute

get_audio_info() {
  volume=$(amixer get Master 2>/dev/null | grep -o '[0-9]*%' | head -1 | tr -d '%')
  mute_status=$(amixer get Master 2>/dev/null | grep -o '\[on\]\|\[off\]' | head -1)

  volume=${volume:-50}
  mute_status=${mute_status:-"[on]"}

  if [ "$mute_status" = "[off]" ]; then
    muted_bool="true"
  else
    muted_bool="false"
  fi

  echo "{\"volume\": $volume, \"muted\": $muted_bool}"
}

update_eww_audio() {
  audio_data=$(get_audio_info)
  eww update audio-info="$audio_data" 2>/dev/null
  echo "$audio_data"
}

case "${1:-}" in
  "up")
    amixer set Master 1%+ unmute >/dev/null 2>&1
    update_eww_audio
    ;;
  "down")
    amixer set Master 1%- unmute >/dev/null 2>&1
    update_eww_audio
    ;;
  "toggle_mute")
    amixer set Master toggle >/dev/null 2>&1
    update_eww_audio
    ;;
  "")
    # No arguments - continuous monitoring mode
    get_audio_info

    while true; do
      sleep 2
      get_audio_info
    done
    ;;
  *)
    echo "Usage: $0 [up|down|toggle_mute]" >&2
    echo "  No args: continuous monitoring" >&2
    echo "  up:      increase volume" >&2
    echo "  down:    decrease volume" >&2
    echo "  toggle_mute: toggle mute" >&2
    exit 1
    ;;
esac
