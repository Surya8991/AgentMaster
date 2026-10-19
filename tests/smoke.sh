#!/bin/bash
# AgentMaster smoke tests — no network, no ~/.claude required. Safe to run in CI.
# Validates skill frontmatter, convert.sh determinism, and scaffold output.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
pass() { echo "  PASS  $*"; }
bad()  { echo "  FAIL  $*"; fail=1; }

echo "AgentMaster smoke tests"
echo "======================="

# 1. Every source skill has name + description frontmatter, name matching its dir.
echo "Skill frontmatter:"
for d in "$REPO"/skills/*/; do
  n="$(basename "$d")"; f="$d/SKILL.md"
  if [ ! -f "$f" ]; then bad "$n: missing SKILL.md"; continue; fi
  fn="$(sed -n 's/^name:[[:space:]]*//p' "$f" | head -1 | tr -d '"'\''')"
  if [ "$fn" != "$n" ]; then bad "$n: frontmatter name is '$fn'"; else pass "$n frontmatter"; fi
  grep -q '^description:' "$f" || bad "$n: no description"
done

# 2. convert.sh --all is deterministic (no drift vs committed files).
#    (.antigravity used to embed today's date; it no longer does — renderers in
#    scripts/lib/skill-render.sh are timestamp-free — but it stays out of the path list
#    below to keep this check independent of commit timing after a local regen.)
echo "convert.sh determinism:"
if bash "$REPO/scripts/convert.sh" --all >/dev/null 2>&1; then
  if command -v git >/dev/null && git -C "$REPO" rev-parse >/dev/null 2>&1; then
    if [ -n "$(git -C "$REPO" status --porcelain -- skills 2>/dev/null)" ]; then
      # Sources are mid-edit, so regenerated platform files legitimately differ from
      # HEAD — that's not a determinism failure. CI runs on a clean tree where this
      # branch is not taken, so the "forgot to regenerate" gate still fires there.
      echo "  SKIP  drift check (skills/ has uncommitted changes)"
    else
      drift="$(git -C "$REPO" status --porcelain -- \
        .cursor .windsurf .clinerules .codex .gemini .opencode .augment \
        CONVENTIONS.md .github/copilot-instructions.md 2>/dev/null)"
      if [ -n "$drift" ]; then
        bad "committed platform files are stale — run convert.sh --all and commit:"; echo "$drift" | sed 's/^/        /'
      else
        pass "platform files in sync with sources"
      fi
    fi
  else
    pass "convert.sh --all ran (not a git tree; drift check skipped)"
  fi
else
  bad "convert.sh --all exited non-zero"
fi

# 3. scaffold apply creates the 4-file spine with a correct CLAUDE.md pointer.
echo "scaffold apply:"
tmp="$(mktemp -d)"
( cd "$tmp" && bash "$REPO/scripts/scaffold.sh" apply >/dev/null 2>&1 )
for f in AGENTS.md CLAUDE.md PROJECTLOG.md README.md; do
  if [ -f "$tmp/$f" ]; then pass "created $f"; else bad "scaffold did not create $f"; fi
done
if [ "$(cat "$tmp/CLAUDE.md" 2>/dev/null | tr -d '[:space:]')" = "@AGENTS.md" ]; then
  pass "CLAUDE.md is @AGENTS.md pointer"
else
  bad "CLAUDE.md is not the @AGENTS.md pointer"
fi
rm -rf "$tmp"

# 4. Every script parses (bash -n).
echo "Script syntax:"
for s in "$REPO"/*.sh "$REPO"/scripts/*.sh "$REPO"/scripts/lib/*.sh "$REPO"/tests/*.sh; do
  if bash -n "$s" 2>/dev/null; then pass "$(basename "$s")"; else bad "$(basename "$s"): syntax error"; fi
done

echo "======================="
if [ "$fail" -eq 0 ]; then echo "ALL SMOKE TESTS PASSED"; else echo "SMOKE TESTS FAILED"; exit 1; fi
