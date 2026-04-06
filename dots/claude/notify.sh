#!/usr/bin/env bash
input=$(cat)
title="Claude - $(echo "$input" | jq -r '.cwd')"
message=$(echo "$input" | jq -r '.message // "Task completed"')

if command -v notify-send &>/dev/null; then
    notify-send "$title" "$message"
elif command -v osascript &>/dev/null; then
    osascript -e "display notification \"$message\" with title \"$title\""
fi
