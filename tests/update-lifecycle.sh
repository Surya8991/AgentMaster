#!/bin/bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
task_tmp=$(mktemp -d)
trap 'rm -rf "$task_tmp"' EXIT
. "$REPO/scripts/lib/skill-lifecycle.sh"
CACHE_DIR="$task_tmp/cache"; SKILLS_DIR="$task_tmp/skills"; OWNERS_FILE="$CACHE_DIR/.skill-owners"
mkdir -p "$CACHE_DIR" "$SKILLS_DIR" "$task_tmp/source/scripts"
: > "$OWNERS_FILE"
report() { echo "$*"; }
record_owner() {
  awk -F= -v s="$1" '$1!=s' "$OWNERS_FILE" > "$OWNERS_FILE.next"
  printf '%s=%s\n' "$1" "$2" >> "$OWNERS_FILE.next"
  mv "$OWNERS_FILE.next" "$OWNERS_FILE"
}
printf '%s\n' '---' 'name: sample' 'description: test' '---' body > "$task_tmp/source/SKILL.md"
echo old > "$task_tmp/source/scripts/old"
lifecycle_install "$task_tmp/source" sample alpha
test -s "$CACHE_DIR/.provenance/sample.txt"
# Cross-owner collisions are denied without touching installed files.
if lifecycle_install "$task_tmp/source" sample beta; then exit 1; fi
grep -qx 'sample=alpha' "$OWNERS_FILE"
echo sample=beta > "$CACHE_DIR/collisions.local"
lifecycle_install "$task_tmp/source" sample beta
grep -qx 'sample=beta' "$OWNERS_FILE"
# A deleted upstream support file disappears after the next successful replacement.
rm "$task_tmp/source/scripts/old"
echo new > "$task_tmp/source/scripts/new"
lifecycle_install "$task_tmp/source" sample beta
test ! -e "$SKILLS_DIR/sample/scripts/old"
# Failed final rename restores previous installation and provenance.
echo preserved > "$SKILLS_DIR/sample/scripts/new"
previous_metadata=$(cat "$CACHE_DIR/.provenance/sample.txt")
mv() {
  if [[ "$1" == *'.am-stage-sample.'* ]] && [[ "$1" != *.previous ]] && [ "$2" = "$SKILLS_DIR/sample" ]; then return 1; fi
  command mv "$@"
}
if lifecycle_install "$task_tmp/source" sample beta; then exit 1; fi
unset -f mv
grep -qx preserved "$SKILLS_DIR/sample/scripts/new"
test "$(cat "$CACHE_DIR/.provenance/sample.txt")" = "$previous_metadata"
# Metadata failures roll back files, provenance, and even a partial owner write.
saved_owner=$(declare -f record_owner)
record_owner() { echo corrupt > "$OWNERS_FILE"; return 1; }
if lifecycle_install "$task_tmp/source" sample beta; then exit 1; fi
eval "$saved_owner"
grep -qx preserved "$SKILLS_DIR/sample/scripts/new"
grep -qx sample=beta "$OWNERS_FILE"
test "$(cat "$CACHE_DIR/.provenance/sample.txt")" = "$previous_metadata"
# Invalid staged docs preserve the installed skill.
echo invalid > "$task_tmp/source/SKILL.md"
if lifecycle_install "$task_tmp/source" sample beta; then exit 1; fi
grep -qx preserved "$SKILLS_DIR/sample/scripts/new"
# Name/description in the body cannot satisfy missing frontmatter fields.
printf '%s\n' '---' 'other: value' '---' 'name: sample' 'description: body only' > "$task_tmp/source/SKILL.md"
if lifecycle_install "$task_tmp/source" sample beta; then exit 1; fi
grep -qx preserved "$SKILLS_DIR/sample/scripts/new"
printf '%s\n' '---' 'name: sample' 'description: missing closing delimiter' > "$task_tmp/source/SKILL.md"
if lifecycle_install "$task_tmp/source" sample beta; then exit 1; fi
grep -qx preserved "$SKILLS_DIR/sample/scripts/new"
# Modified skills survive prune; unchanged removed skills require explicit opt-in.
lifecycle_repo beta
lifecycle_prune 1
test -d "$SKILLS_DIR/sample"
printf '%s\n' '---' 'name: sample' 'description: test' '---' body > "$task_tmp/source/SKILL.md"
lifecycle_install "$task_tmp/source" sample beta
lifecycle_prune 0
test -d "$SKILLS_DIR/sample"
# Seen in another manifest subset: must not prune.
lifecycle_seen beta sample
lifecycle_prune 1
test -d "$SKILLS_DIR/sample"
LIFECYCLE_SEEN=""
lifecycle_prune 1
test ! -e "$SKILLS_DIR/sample"
test ! -s "$OWNERS_FILE"
mkdir -p "$task_tmp/unicode"
printf one > "$task_tmp/unicode/$(printf '\xee\x80\x80').txt"
printf two > "$task_tmp/unicode/$(printf '\xf0\x90\x80\x80').txt"
test "$(lifecycle_hash "$task_tmp/unicode")" = 9fa6732b91070cc091259c2467561c884bbfa5b6
echo 'PASS: staged replacement, rollback, collisions, provenance, and safe opt-in prune'
