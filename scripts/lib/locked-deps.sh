# shellcheck shell=bash
# Internal interface for dependencies.py apply. Never fall back to local pins.
locked_pin() {
  local line name sha result="" count=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [[ ! "$line" =~ ^([a-zA-Z0-9._-]+)=([a-fA-F0-9]{40}|[a-fA-F0-9]{64})$ ]]; then
      echo "Invalid locked dependency pin" >&2; return 1
    fi
    name=${line%%=*}; sha=${line#*=}
    if [ "$name" = . ] || [ "$name" = .. ]; then echo "Invalid locked repo name" >&2; return 1; fi
    if [ "$name" = "$1" ]; then result=$sha; count=$((count + 1)); fi
  done <<< "${AGENTMASTER_LOCK_PINS:-}"
  if [ "$count" -ne 1 ]; then echo "Missing or duplicate locked pin: $1" >&2; return 1; fi
  printf '%s\n' "$result" | tr 'A-F' 'a-f'
}

locked_checkout() {
  local name="$1" url="$2" path="$3" pin actual
  pin=$(locked_pin "$name") || return 1
  if [ -L "$path" ] || [ -L "$path/.git" ]; then echo "Locked cache must not be a symlink: $name" >&2; return 1; fi
  if [ ! -d "$path/.git" ]; then
    if [ -e "$path" ]; then echo "Locked cache is not a Git repo: $name" >&2; return 1; fi
    git clone --no-checkout --quiet "$url" "$path" || return 1
  fi
  git -C "$path" fetch --depth 1 --quiet "$url" "$pin" || return 1
  git -C "$path" checkout --detach --force --quiet "$pin" || return 1
  git -C "$path" clean -fdxq || return 1
  actual=$(git -C "$path" rev-parse HEAD) || return 1
  if [ "$actual" != "$pin" ]; then echo "Locked HEAD mismatch: $name" >&2; return 1; fi
  git -C "$path" remote set-url origin "$url" || return 1
}

locked_preflight() {
  local name url source exclude
  # First check every selected pin before fetching any repo.
  while IFS='|' read -r name url source exclude; do
    [ -n "$name" ] || continue
    repo_in_profile "$name" || continue
    locked_pin "$name" >/dev/null || return 1
  done < <(read_manifest)
  while IFS='|' read -r name url source exclude; do
    [ -n "$name" ] || continue
    repo_in_profile "$name" || continue
    locked_checkout "$name" "$url" "$CACHE_DIR/$name" || return 1
    if [ ! -d "$CACHE_DIR/$name/$source" ]; then echo "Locked skill source missing: $name/$source" >&2; return 1; fi
  done < <(read_manifest)
}

locked_verify() {
  local pin actual
  pin=$(locked_pin "$1") || return 1
  actual=$(git -C "$2" rev-parse HEAD) || return 1
  [ "$actual" = "$pin" ] || { echo "Locked HEAD changed: $1" >&2; return 1; }
}
