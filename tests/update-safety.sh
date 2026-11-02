#!/bin/bash
# Focused updater regression tests; no network and no real installation touched.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
task_tmp=$(mktemp -d)
trap 'rm -rf "$task_tmp"' EXIT
# Load only the pure helpers, never the updater entry point.
eval "$(sed -n '/^release_lock()/,/^if ! acquire_lock;/p' "$REPO/scripts/update.sh" | sed '$d')"
eval "$(sed -n '/^copy_skill()/,/^sync_skills()/p' "$REPO/scripts/update.sh" | sed '$d')"
LOCK_FILE="$task_tmp/lock"
LOCK_OWNER="bash:$$"
acquire_lock
# Age must not matter when the PID is live.
touch -t 200001010000 "$LOCK_FILE"
if acquire_lock; then echo 'FAIL: took live lock'; exit 1; fi
release_lock
# Use a child PID known to have exited, not a guessed unused PID.
sleep 0 & dead_pid=$!
wait "$dead_pid"
printf 'bash:%s\n' "$dead_pid" > "$LOCK_FILE"
acquire_lock
release_lock
printf 'powershell:123\n' > "$LOCK_FILE"
if acquire_lock; then echo 'FAIL: took foreign lock'; exit 1; fi
rm "$LOCK_FILE"
: > "$LOCK_FILE"
if acquire_lock; then echo 'FAIL: took legacy lock'; exit 1; fi
rm "$LOCK_FILE"
mkdir -p "$task_tmp/source/scripts" "$task_tmp/installed"
printf helper > "$task_tmp/source/scripts/helper"
printf 'new\n' > "$task_tmp/source/SKILL.md"
printf 'hidden\n' > "$task_tmp/source/.hidden"
SKILLS_DIR="$task_tmp/installed"
SYNC_FAILURES=0
owners=""
report() { printf '%s\n' "$*"; }
record_owner() { owners="$owners $1=$2"; }
copy_skill "$task_tmp/source" sample repo
printf 'changed\n' > "$task_tmp/source/SKILL.md"
copy_skill "$task_tmp/source" sample repo
cmp "$task_tmp/source/SKILL.md" "$SKILLS_DIR/sample/SKILL.md"
test -f "$SKILLS_DIR/sample/.hidden"
test ! -d "$SKILLS_DIR/sample/source"
cmp "$task_tmp/source/scripts/helper" "$SKILLS_DIR/sample/scripts/helper"
test ! -d "$SKILLS_DIR/sample/scripts/scripts"
before_owners="$owners"
printf 'blocked\n' > "$SKILLS_DIR/broken"
if copy_skill "$task_tmp/source" broken other; then echo 'FAIL: copy unexpectedly succeeded'; exit 1; fi
test "$SYNC_FAILURES" -eq 1
test "$owners" = "$before_owners"
echo 'PASS: updater locks, repeat copies, and failed-copy ownership'

# Exercise the complete failure-report/exit/cooldown path with a local dev cache.
fixture="$task_tmp/full"
mkdir -p "$fixture/cache/agent-master/skills/broken" "$fixture/skills"
: > "$fixture/cache/.dev"
: > "$fixture/cache/agent-master/repos.manifest"
printf 'skill body\n' > "$fixture/cache/agent-master/skills/broken/SKILL.md"
printf 'blocked\n' > "$fixture/skills/broken"
awk -v skills="$fixture/skills" -v cache="$fixture/cache" '
  /^SKILLS_DIR=/ { print "SKILLS_DIR=\"" skills "\""; next }
  /^CACHE_DIR=/ { print "CACHE_DIR=\"" cache "\""; next }
  { print }
' "$REPO/scripts/update.sh" > "$fixture/update.sh"
if bash "$fixture/update.sh" > "$fixture/output" 2>&1; then
  echo 'FAIL: full update returned success after copy failure'; exit 1
fi
grep -q 'Sync incomplete: 1 copy failures' "$fixture/cache/last-sync-report.txt"
test ! -e "$fixture/cache/.last-update"
test ! -s "$fixture/cache/.skill-owners"
test ! -e "$fixture/cache/.update-lock"
rm "$fixture/skills/broken"
bash "$fixture/update.sh" > "$fixture/output" 2>&1
test -f "$fixture/cache/.last-update"
grep -q '^broken=agent-master$' "$fixture/cache/.skill-owners"
echo 'PASS: full updater failure report, exit status, cooldown, and retry'
