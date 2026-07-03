#!/bin/bash
# AgentMaster Doctor — health-check installed skills, caches, and pins.
# Exit code: 0 if no FAILs, 1 otherwise. Missing files degrade to WARN.
#
# Usage: bash scripts/doctor.sh

SKILLS_DIR="$HOME/.claude/skills"
CACHE_DIR="$HOME/.claude/.agentmaster-cache"
PINS_FILE="$CACHE_DIR/agent-master/repos.pins"
MANIFEST="$CACHE_DIR/agent-master/repos.manifest"
OWNERS_FILE="$CACHE_DIR/.skill-owners"
LAST_UPDATE_FILE="$CACHE_DIR/.last-update"

PASS=0; WARN=0; FAIL=0

pass() { echo "  PASS  $*"; PASS=$((PASS+1)); }
warn() { echo "  WARN  $*"; WARN=$((WARN+1)); }
fail() { echo "  FAIL  $*"; FAIL=$((FAIL+1)); }
note() { echo "  NOTE  $*"; }

echo "AgentMaster Doctor"
echo "=================="

# --- Skills directory ---
echo ""
echo "Skills:"
if [ ! -d "$SKILLS_DIR" ]; then
  fail "skills directory missing: $SKILLS_DIR — run install"
else
  bad_md=0; bad_name=0; bad_desc=0; total=0
  for skill_dir in "$SKILLS_DIR"/*/; do
    [ ! -d "$skill_dir" ] && continue
    total=$((total+1))
    skill_name=$(basename "$skill_dir")
    md="$skill_dir/SKILL.md"
    if [ ! -f "$md" ]; then
      fail "$skill_name: no SKILL.md"
      bad_md=$((bad_md+1))
      continue
    fi
    fm_name=$(grep -m1 '^name:' "$md" 2>/dev/null | sed 's/^name:[[:space:]]*//; s/^["'\'']//; s/["'\'']$//')
    if [ -z "$fm_name" ]; then
      warn "$skill_name: SKILL.md has no 'name:' frontmatter"
      bad_name=$((bad_name+1))
    elif [ "$fm_name" != "$skill_name" ]; then
      warn "$skill_name: frontmatter name is '$fm_name' (mismatch)"
      bad_name=$((bad_name+1))
    fi
    if ! grep -qm1 '^description:' "$md" 2>/dev/null; then
      warn "$skill_name: SKILL.md has no 'description:' frontmatter"
      bad_desc=$((bad_desc+1))
    fi
  done
  [ "$bad_md" -eq 0 ] && pass "$total skills all have SKILL.md"
  [ "$bad_name" -eq 0 ] && pass "all frontmatter names match directory names"
  [ "$bad_desc" -eq 0 ] && pass "all skills have descriptions"
fi

# --- Cache repos ---
echo ""
echo "Caches:"
if [ ! -f "$MANIFEST" ]; then
  warn "manifest not cached yet: $MANIFEST — run /agent-master update"
else
  while IFS='|' read -r name url source; do
    [ -z "$name" ] && continue
    if [ -d "$CACHE_DIR/$name/.git" ]; then
      pass "$name cached ($(git -C "$CACHE_DIR/$name" rev-parse --short HEAD 2>/dev/null || echo '?'))"
    else
      warn "$name not cached — run /agent-master update"
    fi
  done < <(grep -Ev '^[[:space:]]*(#|$)' "$MANIFEST"; [ -f "$CACHE_DIR/repos.local" ] && grep -Ev '^[[:space:]]*(#|$)' "$CACHE_DIR/repos.local" || true)
fi
if [ -d "$CACHE_DIR/agent-master/.git" ]; then
  pass "agent-master self-update cache healthy"
else
  warn "agent-master cache missing .git — self-update will re-clone"
fi

# --- Pins ---
echo ""
echo "Pins:"
if [ ! -f "$PINS_FILE" ]; then
  note "no repos.pins — all repos track upstream HEAD"
else
  pin_count=0; pin_bad=0
  manifest_names=$( [ -f "$MANIFEST" ] && grep -Ev '^[[:space:]]*(#|$)' "$MANIFEST" | cut -d'|' -f1 || true)
  while IFS='=' read -r pname psha; do
    case "$pname" in \#*|"") continue ;; esac
    pin_count=$((pin_count+1))
    if ! echo "$manifest_names" | grep -qx "$pname"; then
      warn "pin '$pname' not in repos.manifest"
      pin_bad=$((pin_bad+1))
    fi
    if ! echo "$psha" | grep -qE '^[0-9a-f]{40}$'; then
      warn "pin '$pname' sha is not 40-char hex: $psha"
      pin_bad=$((pin_bad+1))
    fi
  done < "$PINS_FILE"
  if [ "$pin_count" -eq 0 ]; then
    note "repos.pins present but no pins set — all repos track upstream HEAD"
  elif [ "$pin_bad" -eq 0 ]; then
    pass "$pin_count pins valid"
  fi
fi

# --- Ownership ---
echo ""
echo "Ownership:"
if [ ! -f "$OWNERS_FILE" ]; then
  warn "no ownership records — run /agent-master update to build them"
else
  orphans=0
  for skill_dir in "$SKILLS_DIR"/*/; do
    [ ! -d "$skill_dir" ] && continue
    skill_name=$(basename "$skill_dir")
    if ! grep -q "^$skill_name=" "$OWNERS_FILE" 2>/dev/null; then
      orphans=$((orphans+1))
      if [ "$orphans" -le 10 ]; then
        note "orphan skill (no recorded owner, probably yours): $skill_name"
      fi
    fi
  done
  [ "$orphans" -gt 10 ] && note "... and $((orphans-10)) more orphans (run /agent-master update to rebuild ownership)"
  pass "$(grep -c '=' "$OWNERS_FILE" 2>/dev/null || echo 0) skills have recorded owners ($orphans orphans)"
fi

# --- Routing ---
echo ""
echo "Routing:"
UNROUTED_FILE="$CACHE_DIR/unrouted-skills.txt"
if [ ! -f "$UNROUTED_FILE" ]; then
  warn "unrouted-skills.txt not generated yet — run /agent-master update"
elif [ -s "$UNROUTED_FILE" ]; then
  n_unrouted=$(grep -c . "$UNROUTED_FILE")
  note "$n_unrouted skills installed but not in the routing table (see /agent-master routes):"
  head -5 "$UNROUTED_FILE" | sed 's/^/  NOTE    /'
  [ "$n_unrouted" -gt 5 ] && note "  ... and $((n_unrouted-5)) more"
else
  pass "all installed skills are reachable from the routing table"
fi
OVERRIDES_FILE="$CACHE_DIR/routing-overrides.md"
if [ -s "$OVERRIDES_FILE" ] && grep -qEv '^[[:space:]]*(#|$)' "$OVERRIDES_FILE"; then
  note "$(grep -cEv '^[[:space:]]*(#|$)' "$OVERRIDES_FILE") routing overrides active (see /agent-master routes)"
fi

# --- Tooling & freshness ---
echo ""
echo "Tooling:"
active_profile=$(cat "$CACHE_DIR/.profile" 2>/dev/null || echo full)
[ -z "$active_profile" ] && active_profile=full
if [ "$active_profile" = "full" ]; then
  pass "profile: full (everything syncs)"
elif grep -hEv '^[[:space:]]*(#|$)' "$CACHE_DIR/agent-master/profiles.manifest" "$CACHE_DIR/profiles.local" 2>/dev/null | cut -d'|' -f1 | grep -qx "$active_profile"; then
  pass "profile: $active_profile"
else
  warn "profile '$active_profile' unknown — updater will fall back to full"
fi
if command -v repomix >/dev/null 2>&1; then
  pass "repomix on PATH"
else
  warn "repomix not on PATH — repomix-pack skill won't work (npm install -g repomix)"
fi
if [ -f "$LAST_UPDATE_FILE" ]; then
  age=$(( ( $(date +%s) - $(cat "$LAST_UPDATE_FILE" 2>/dev/null || echo 0) ) / 86400 ))
  if [ "$age" -gt 7 ]; then
    warn "last sync was ${age}d ago — updates may be failing silently"
  else
    pass "last sync ${age}d ago"
  fi
else
  warn "never synced — run /agent-master update"
fi

# --- Summary ---
echo ""
echo "=================="
echo "Summary: $PASS pass, $WARN warn, $FAIL fail"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
