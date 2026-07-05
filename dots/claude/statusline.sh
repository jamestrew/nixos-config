#!/usr/bin/env bash
input=$(cat)

# Pull everything in one jq pass (tab-separated). `read` treats tab as
# whitespace and collapses adjacent tabs, so an empty effort field would shift
# every later column left; emit "-" as a sentinel and strip it below.
IFS=$'\t' read -r MODEL EFFORT CTX_SIZE CTX_USED CTX_PCT IN OUT CACHE_READ COST FIVE_H FIVE_H_RESET WEEK WEEK_RESET < <(
  echo "$input" | jq -r '[
    .model.display_name,
    (.effort.level // "-"),
    (.context_window.context_window_size // 0),
    (.context_window.total_input_tokens // 0),
    (.context_window.used_percentage // 0),
    (.context_window.current_usage.input_tokens // 0),
    (.context_window.current_usage.output_tokens // 0),
    (.context_window.current_usage.cache_read_input_tokens // 0),
    (.cost.total_cost_usd // 0),
    (.rate_limits.five_hour.used_percentage // "-"),
    (.rate_limits.five_hour.resets_at // "-"),
    (.rate_limits.seven_day.used_percentage // "-"),
    (.rate_limits.seven_day.resets_at // "-")
  ] | @tsv'
)
[ "$EFFORT" = "-" ]      && EFFORT=""
[ "$FIVE_H" = "-" ]      && FIVE_H=""
[ "$FIVE_H_RESET" = "-" ] && FIVE_H_RESET=""
[ "$WEEK" = "-" ]        && WEEK=""
[ "$WEEK_RESET" = "-" ]  && WEEK_RESET=""

abbrev() {
  local n=$1
  if [ "$n" -ge 1000000 ]; then
    awk "BEGIN {printf \"%.1fM\", $n/1000000}"
  elif [ "$n" -ge 1000 ]; then
    awk "BEGIN {printf \"%.0fk\", $n/1000}"
  else
    echo "$n"
  fi
}

rel_time() {
  local diff=$(( $1 - $(date +%s) ))
  [ "$diff" -le 0 ] && echo "now" && return
  local d=$(( diff / 86400 )) h=$(( (diff % 86400) / 3600 )) m=$(( (diff % 3600) / 60 ))
  local dh=$(awk "BEGIN {printf \"%.1f\", $h + $m/60}")
  [ "$d" -gt 0 ] && echo "${d}d${dh}h" || echo "${dh}h"
}

# Cache-hit rate is derived: cached reads over the input-only context total.
CH=$(awk "BEGIN {t=$CTX_USED; printf \"%.1f\", (t>0 ? $CACHE_READ/t*100 : 0)}")
PCT=$(awk "BEGIN {printf \"%.1f\", $CTX_PCT}")
COST_FMT=$(awk "BEGIN {printf \"%.3f\", $COST}")

LIMITS=""
[ -n "$FIVE_H" ] && LIMITS="5h: $(printf '%.0f' "$FIVE_H")%${FIVE_H_RESET:+ ($(rel_time "$FIVE_H_RESET"))}"
[ -n "$WEEK" ]   && LIMITS="${LIMITS:+$LIMITS }7d: $(printf '%.0f' "$WEEK")%${WEEK_RESET:+ ($(rel_time "$WEEK_RESET"))}"

echo "${MODEL}${EFFORT:+ $EFFORT} · $(abbrev "$CTX_USED")/$(abbrev "$CTX_SIZE") ${PCT}% · ↑$(abbrev "$IN") ↓$(abbrev "$OUT") R$(abbrev "$CACHE_READ") CH${CH}% \$${COST_FMT}${LIMITS:+ · $LIMITS}"
