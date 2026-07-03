#!/bin/bash
# AgentMaster Routes — routing log, active overrides, and unrouted skills.
#
# Usage: bash scripts/routes.sh

CACHE_DIR="$HOME/.claude/.agentmaster-cache"
LOG_FILE="$CACHE_DIR/routing-log.txt"
OVERRIDES_FILE="$CACHE_DIR/routing-overrides.md"
UNROUTED_FILE="$CACHE_DIR/unrouted-skills.txt"

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
