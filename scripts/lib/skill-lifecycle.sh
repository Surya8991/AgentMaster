# shellcheck shell=bash
# Shared installer/updater lifecycle. Requires git and the caller's report/record_owner.
# Replacement uses two renames with rollback: there is a brief visibility gap, not
# an atomic directory exchange. Staging and backup stay on the destination volume.
LIFECYCLE_SEEN=""
LIFECYCLE_REPOS=""
lifecycle_seen() { LIFECYCLE_SEEN="$LIFECYCLE_SEEN$1=$2
"; }
lifecycle_repo() { LIFECYCLE_REPOS="$LIFECYCLE_REPOS$1
"; }
lifecycle_hash() (
  set -o pipefail
  cd "$1" || exit 1
  find . -type f -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' file; do
    hash=$(git hash-object -- "$file") || exit 1
    printf '%s  %s\n' "$hash" "${file#./}"
  done | git hash-object --stdin
)
lifecycle_install() {
  local source="$1" skill="$2" repo="$3" previous override stage backup target digest url commit
  [[ "$skill" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || { report "Invalid skill name: $skill"; return 1; }
  target="$SKILLS_DIR/$skill"
  previous=$(awk -F= -v s="$skill" '$1==s {print $2; exit}' "$OWNERS_FILE" 2>/dev/null)
  override=$(awk -F= -v s="$skill" '$1==s {print $2; exit}' "$CACHE_DIR/collisions.local" 2>/dev/null || true)
  if { [ -e "$target" ] || [ -L "$target" ] || [ -n "$previous" ]; } && [ "$previous" != "$repo" ] && [ "$override" != "$repo" ]; then
    report "$repo: BLOCKED collision for $skill (owner: ${previous:-unowned}); override in collisions.local: $skill=$repo"
    return 1
  fi
  if [ -L "$target" ] || { [ -e "$target" ] && [ ! -d "$target" ]; }; then
    report "$repo: unsafe destination for $skill"; return 1
  fi
  if [ -L "${source%/}" ] || [ -n "$(find "$source" -type l -print -quit)" ]; then
    report "$repo: symlink in $skill; refusing managed install"; return 1
  fi
  stage=$(mktemp -d "$SKILLS_DIR/.am-stage-$skill.XXXXXX") || return 1
  backup="$stage.previous"
  if ! cp -R "$source/." "$stage/"; then rm -rf "$stage"; return 1; fi
  # Support upstream lowercase filenames, but require actual frontmatter fields.
  local doc="$stage/SKILL.md"
  [ -f "$doc" ] || doc="$stage/skill.md"
  if [ ! -s "$doc" ] || ! awk '
    { sub(/\r$/, "") }
    NR==1 { if ($0!="---") exit 1; next }
    /^---$/ { closed=1; exit }
    /^name:[[:space:]]*[^[:space:]]/ { name=1 }
    /^description:[[:space:]]*[^[:space:]]/ { description=1 }
    END { exit !(closed && name && description) }
  ' "$doc"; then
    report "$repo: invalid SKILL.md in $skill"; rm -rf "$stage"; return 1
  fi
  digest=$(lifecycle_hash "$stage") || { rm -rf "$stage"; return 1; }
  url=$(git -C "$source" config --get remote.origin.url 2>/dev/null || true)
  commit=$(git -C "$source" rev-parse HEAD 2>/dev/null || true)
  if ! mkdir -p "$CACHE_DIR/.provenance"; then rm -rf "$stage"; return 1; fi
  if ! printf 'repo=%s\nurl=%s\ncommit=%s\ninstalled_at=%s\nhash=%s\n' "$repo" "${url:-local}" "${commit:-unknown}" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$digest" > "$stage.provenance"; then rm -rf "$stage"; rm -f "$stage.provenance"; return 1; fi
  if ! cp "$OWNERS_FILE" "$stage.owners"; then rm -rf "$stage"; rm -f "$stage.provenance"; return 1; fi
  if [ -f "$CACHE_DIR/.provenance/$skill.txt" ] && ! cp "$CACHE_DIR/.provenance/$skill.txt" "$stage.old-provenance"; then
    rm -rf "$stage"; rm -f "$stage.provenance" "$stage.owners"; return 1
  fi
  if [ -d "$target" ] && ! mv "$target" "$backup"; then rm -rf "$stage"; rm -f "$stage.provenance" "$stage.owners" "$stage.old-provenance"; return 1; fi
  if ! mv "$stage" "$target"; then
    [ ! -d "$backup" ] || mv "$backup" "$target"
    rm -rf "$stage"; rm -f "$stage.provenance" "$stage.owners" "$stage.old-provenance"; return 1
  fi
  if ! mv "$stage.provenance" "$CACHE_DIR/.provenance/$skill.txt" || ! record_owner "$skill" "$repo"; then
    rm -rf "$target"; [ ! -d "$backup" ] || mv "$backup" "$target"
    cp "$stage.owners" "$OWNERS_FILE"
    if [ -f "$stage.old-provenance" ]; then
      mv "$stage.old-provenance" "$CACHE_DIR/.provenance/$skill.txt"
    else
      rm -f "$CACHE_DIR/.provenance/$skill.txt"
    fi
    rm -f "$stage.provenance" "$stage.owners"; return 1
  fi
  rm -rf "$backup"
  rm -f "$stage.owners" "$stage.old-provenance"
}
lifecycle_prune() {
  local apply="$1" skill repo expected actual metadata
  while IFS='=' read -r skill repo; do
    [[ "$skill" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || continue
    printf '%s' "$LIFECYCLE_REPOS" | grep -qxF "$repo" || continue
    if printf '%s' "$LIFECYCLE_SEEN" | grep -qxF "$repo=$skill"; then continue; fi
    [ -d "$SKILLS_DIR/$skill" ] || continue
    metadata="$CACHE_DIR/.provenance/$skill.txt"
    expected=$(sed -n 's/^hash=//p' "$metadata" 2>/dev/null || true)
    if [ "$(sed -n 's/^repo=//p' "$metadata" 2>/dev/null)" != "$repo" ] || [ -L "$SKILLS_DIR/$skill" ] || [ -n "$(find "$SKILLS_DIR/$skill" -type l -print -quit)" ] || [ -z "$expected" ]; then
      report "$repo: removed upstream: $skill (preserved: no trustworthy provenance)"; continue
    fi
    actual=$(lifecycle_hash "$SKILLS_DIR/$skill")
    if [ "$actual" != "$expected" ]; then
      report "$repo: removed upstream: $skill (preserved: locally modified)"; continue
    fi
    if [ "$apply" != 1 ]; then report "$repo: removed upstream: $skill (use --prune to remove)"; continue; fi
    rm -rf "$SKILLS_DIR/$skill"
    awk -F= -v s="$skill" '$1!=s' "$OWNERS_FILE" > "$OWNERS_FILE.prune"
    mv "$OWNERS_FILE.prune" "$OWNERS_FILE"
    rm -f "$metadata"
    report "$repo: pruned $skill"
  done < <(cat "$OWNERS_FILE")
}
