# shellcheck shell=bash
# Shared skill -> platform renderers.
#
# Each render_* function prints one skill's rendered content to stdout. Both
# scripts/convert.sh (which writes the committed platform files in the repo) and
# scripts/install-platform.sh (which writes into live platform dirs) source this
# file, so the per-platform formats are defined ONCE and can never drift between
# "what we commit" and "what we install".
#
# Contract: callers pass the RAW frontmatter name/description/body. YAML-quoted
# fields are escaped here; markdown formats (aider/copilot) take the raw text.
# Output is deterministic — no timestamps — so `convert.sh --all` is reproducible.

# --- Frontmatter extraction (shared so convert.sh and install-platform.sh agree) ---

# skill_field <file> <field> — value of a YAML frontmatter field, outer quotes stripped.
skill_field() {
  sed -n '/^---$/,/^---$/p' "$1" | grep "^${2}:" | sed "s/^${2}:[[:space:]]*//" | sed 's/^"\(.*\)"$/\1/' | head -1
}

# skill_body <file> — everything after the second `---` (the markdown body).
skill_body() {
  awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$1"
}

# Escape a value for use inside a double-quoted YAML scalar.
_yaml_escape() { printf '%s' "${1//\"/\\\"}"; }

render_cursor() { # desc body
  printf '%s\n' "---" "description: \"$(_yaml_escape "$1")\"" "globs:" "alwaysApply: false" "---" "$2"
}

render_windsurf() { # name desc body
  printf '%s\n' "---" "name: \"$(_yaml_escape "$1")\"" "description: \"$(_yaml_escape "$2")\"" "trigger: always_on" "---" "$3"
}

render_cline() { # body
  printf '%s\n' "$1"
}

render_antigravity() { # name desc body
  printf '%s\n' "---" "name: \"$(_yaml_escape "$1")\"" "description: \"$(_yaml_escape "$2")\"" "risk: low" "source: community" "---" "$3"
}

render_opencode() { # name desc body
  printf '%s\n' "---" "name: \"$(_yaml_escape "$1")\"" "description: \"$(_yaml_escape "$2")\"" "compatibility: opencode" "---" "$3"
}

render_augment() { # desc body
  printf '%s\n' "---" "type: auto" "description: \"$(_yaml_escape "$1")\"" "---" "$2"
}

render_aider() { # name desc body  (markdown block; raw text, no escaping)
  printf '\n---\n\n## %s\n> %s\n\n%s\n' "$1" "$2" "$3"
}

render_copilot() { # name desc body
  printf '\n## %s\n%s\n\n%s\n' "$1" "$2" "$3"
}
