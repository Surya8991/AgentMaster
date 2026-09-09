#!/bin/bash
# AgentMaster Routes — routing log, active overrides, and unrouted skills.
#
# Usage:
#   bash scripts/routes.sh              # recent routes, overrides, unrouted skills
#   bash scripts/routes.sh analyze      # rank repeated misroutes + busiest categories

CACHE_DIR="$HOME/.claude/.agentmaster-cache"
LOG_FILE="$CACHE_DIR/routing-log.txt"
OVERRIDES_FILE="$CACHE_DIR/routing-overrides.md"
UNROUTED_FILE="$CACHE_DIR/unrouted-skills.txt"

# --- analyze mode: turn the write-only log into actionable signal ---
if [ "${1:-}" = "analyze" ] || [ "${1:-}" = "--analyze" ]; then
  echo "AgentMaster Route Analysis"
  echo "=========================="
  if [ ! -s "$LOG_FILE" ]; then
    echo "(no routing log yet — entries appear as /agent-master routes tasks)"
    exit 0
  fi
  total=$(grep -c . "$LOG_FILE")
  corr=$(grep -c 'corrected ->' "$LOG_FILE" 2>/dev/null || true)
  echo ""
  echo "Total routes logged:      $total"
  echo "Corrections (misroutes):  ${corr:-0}"
  echo ""
  echo "Most-corrected target skills (where you had to redirect):"
  if [ "${corr:-0}" -gt 0 ]; then
    grep 'corrected ->' "$LOG_FILE" | sed 's/.*corrected ->[[:space:]]*//' | awk '{print $1}' \
      | sort | uniq -c | sort -rn | head -10 | sed 's/^/  /'
    echo ""
    echo "  -> Consider adding these as routing-overrides or table rows."
  else
    echo "  (none — no corrections recorded)"
  fi
  echo ""
  echo "Busiest categories:"
  awk -F'|' 'NF>=3 {gsub(/^[[:space:]]+|[[:space:]]+$/,"",$3); if ($3!="") print $3}' "$LOG_FILE" \
    | sort | uniq -c | sort -rn | head -10 | sed 's/^/  /'
  exit 0
fi

echo "AgentMaster Routing"
echo "==================="

echo ""
echo "Recent routes (last 15):"
if [ -s "$LOG_FILE" ]; then
  tail -15 "$LOG_FILE" | sed 's/^/  /'
else
  echo "  (no routing log yet — entries appear as /agent-master routes tasks)"
fi

echo ""
echo "Active overrides (take precedence over the routing table):"
if [ -s "$OVERRIDES_FILE" ] && grep -qEv '^[[:space:]]*(#|$)' "$OVERRIDES_FILE"; then
  grep -Ev '^[[:space:]]*(#|$)' "$OVERRIDES_FILE" | sed 's/^/  /'
else
  echo "  (none — corrections to misroutes will be recorded here)"
fi

echo ""
echo "Unrouted skills (installed but not in the routing table):"
if [ -s "$UNROUTED_FILE" ]; then
  sed 's/^/  /' "$UNROUTED_FILE"
else
  echo "  (none — or run /agent-master update to regenerate)"
fi
