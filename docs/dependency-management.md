# Reviewing and managing installed skills

The ordinary installer/updater stays available in Bash and PowerShell. Optional
reviewed-lock commands require Python 3 and Git; routing diagnostics require Node.js.
Neither feature installs its runtime automatically.

## Preview and reproducible installation

Run from a committed AgentMaster checkout. Preview clones dependencies into a
temporary directory and prints candidate revisions, commit summaries/diff statistics
when the prior revision is available, skill additions/replacements, exclusions,
collisions and removal candidates. It does not modify installed skills, caches,
ownership records or cooldowns. It contacts configured Git remotes.

```sh
python scripts/dependencies.py preview --profile full
python scripts/dependencies.py preview --profile full --write-lock reviewed-lock.json
```

Use the installed profile instead of `full` when appropriate. Preview includes
`repos.local`, `profiles.local` and `collisions.local` from the default cache.
`--cache-dir` and `--skills-dir` support inspecting a different installation.
Existing reviewed lockfiles are never silently overwritten.

Review the printed upstream changes and lockfile, then explicitly apply it:

```sh
python scripts/dependencies.py apply --lock reviewed-lock.json --mode install
python scripts/dependencies.py apply --lock reviewed-lock.json --mode update
```

The lock records full Git commit IDs, repository URLs, manifest rows, profile
rules and collision overrides. Apply rejects changed configuration, missing pins,
dirty tracked source, or an AgentMaster checkout different from the locked revision.
Locked updates require the installed profile to match; locked installs select it.
Dependency revisions are fetched and verified before skill writes. Local pins do
not override a reviewed lock, and failures never fall back to upstream HEAD.

Locked mode skips self-update and the ordinary installer's unpinned Repomix package
installation. It reproduces the selected skill sources, not external MCP servers,
CLI packages, model versions, or the entire machine environment. Manually installed
skills remain outside the lock. This is an opt-in mode: ordinary automatic updates
continue to follow their configured pins/default branches.

## Collision protection and provenance

Install/update refuses to replace a skill owned by another repository, or an
existing unowned skill. To deliberately transfer ownership, add an exact line to
`~/.claude/.agentmaster-cache/collisions.local`:

```text
skill-name=chosen-repository-name
```

This is an explicit override, not a wildcard allowlist. If two selected repositories
keep supplying the same name, the nonchosen one will still report a blocked
collision; exclude that skill from its manifest entry for a clean sync.

Successful installations record `repo`, `url`, `commit`, `installed_at` (UTC), and
a content inventory `hash` in `.agentmaster-cache/.provenance/<skill>.txt`.
Local non-Git sources are labelled `local`/`unknown`, not assigned invented commits.

Each skill is copied and validated in a staging directory before replacement.
Replacement uses two directory renames and rollback on failure. There is a brief
visibility gap between renames; this is not a crash-proof atomic directory exchange
or an all-repositories transaction. Old support files disappear on replacement.
Symlinks/reparse points are rejected for managed installation and pruning.

## Removed upstream skills

Ordinary updates only report skills no longer found upstream. Removal is opt-in:

```sh
bash scripts/update.sh --prune
```

```powershell
.\scripts\update.ps1 -Prune
```

Pruning runs only after a successful sync, combines all manifest subsets for each
repository, checks ownership and recorded content hashes, and preserves modified
or unprovenanced skills. Profile/exclusion filtering is not evidence of upstream
deletion. Inspect preserved files yourself; pruning does not adopt or delete them.

## Routing checks

```sh
node scripts/routing.js evaluate
node scripts/routing.js availability
node scripts/routing.js evaluate --predictions captured-results.json
```

The offline benchmark covers all 27 categories and ambiguous prompts. It tests a
deterministic signal baseline, not live LLM accuracy. Captured model predictions
can be scored against the same corpus. Availability checks distinguish missing
local skills from unknown plugin inventories and configured-but-unverified MCP
servers. See [routing diagnostics](../scripts/routing.md) for input formats.
