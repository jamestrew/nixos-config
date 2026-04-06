#!/usr/bin/env bash
input=$(cat)
title="Claude - $(echo "$input" | jq -r '.cwd')"
message=$(echo "$input" | jq -r '.message // "Task completed"')

if command -v notify-send &>/dev/null; then
    notify-send "$title" "$message"
elif command -v osascript &>/dev/null; then
    osascript - "$title" "$message" <<'EOF'
on run argv
  display notification (item 2 of argv) with title (item 1 of argv)
end run
EOF
fi
