#!/usr/bin/env bash
input=$(cat)

CONTEXT_WINDOW_USED_PERCENTAGE=$(echo "$input" | jq -r '.context_window.used_percentage // 0 | floor')
COST_TOTAL_COST_USD=$(echo "$input" | jq -r '.cost.total_cost_usd // 0 | . * 100 | floor / 100 | tostring | if . | contains(".") then . else . + ".00" end | if (. | split(".")[1] | length) == 1 then . + "0" else . end')
MODEL_DISPLAY_NAME=$(echo "$input" | jq -r '.model.display_name')
FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
FIVE_H_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
WEEK=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
WEEK_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

rel_time() {
  local diff=$(( $1 - $(date +%s) ))
  [ "$diff" -le 0 ] && echo "now" && return
  local d=$(( diff / 86400 )) h=$(( (diff % 86400) / 3600 )) m=$(( (diff % 3600) / 60 ))
  local dh=$(awk "BEGIN {printf \"%.1f\", $h + $m/60}")
  [ "$d" -gt 0 ] && echo "${d}d${dh}h" || echo "${dh}h"
}

LIMITS=""
[ -n "$FIVE_H" ] && LIMITS=" | 5h: $(printf '%.0f' "$FIVE_H")%${FIVE_H_RESET:+ ($(rel_time "$FIVE_H_RESET"))}"
[ -n "$WEEK" ] && LIMITS="${LIMITS} 7d: $(printf '%.0f' "$WEEK")%${WEEK_RESET:+ ($(rel_time "$WEEK_RESET"))}"

echo "Context used: ${CONTEXT_WINDOW_USED_PERCENTAGE}% | Cost: \$${COST_TOTAL_COST_USD} | Model: $MODEL_DISPLAY_NAME${LIMITS}"
