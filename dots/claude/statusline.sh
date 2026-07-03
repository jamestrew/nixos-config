#!/usr/bin/env bash
input=$(cat)

# Pull everything in one jq pass (tab-separated). `read` treats tab as
# whitespace and collapses adjacent tabs, so an empty effort field would shift
# every later column left; emit "-" as a sentinel and strip it below.
IFS=$'\t' read -r MODEL EFFORT CTX_SIZE CTX_USED CTX_PCT IN OUT CACHE_READ COST < <(
  echo "$input" | jq -r '[
    .model.display_name,
    (.effort.level // "-"),
    (.context_window.context_window_size // 0),
    (.context_window.total_input_tokens // 0),
    (.context_window.used_percentage // 0),
    (.context_window.current_usage.input_tokens // 0),
    (.context_window.current_usage.output_tokens // 0),
    (.context_window.current_usage.cache_read_input_tokens // 0),
    (.cost.total_cost_usd // 0)
  ] | @tsv'
)
[ "$EFFORT" = "-" ] && EFFORT=""

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

# Cache-hit rate is derived: cached reads over the input-only context total.
CH=$(awk "BEGIN {t=$CTX_USED; printf \"%.1f\", (t>0 ? $CACHE_READ/t*100 : 0)}")
PCT=$(awk "BEGIN {printf \"%.1f\", $CTX_PCT}")
COST_FMT=$(awk "BEGIN {printf \"%.3f\", $COST}")

echo "${MODEL}${EFFORT:+ $EFFORT} · $(abbrev "$CTX_USED")/$(abbrev "$CTX_SIZE") ${PCT}% · ↑$(abbrev "$IN") ↓$(abbrev "$OUT") R$(abbrev "$CACHE_READ") CH${CH}% \$${COST_FMT}"
