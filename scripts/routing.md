# Offline routing diagnostics

Requires Node.js; no packages, network calls, tool installation, or configuration changes.

```sh
node scripts/routing.js baseline "Fix copy for our launch"
node scripts/routing.js evaluate
node scripts/routing.js availability
node scripts/routing.js availability --skills-dir /path/to/skills --plugins loaded-skills.json --mcp-config mcp.json --json
```

The baseline extracts signal words from the canonical `skills/agent-master/SKILL.md`
table and applies a small explicit set of context rules. It is a deterministic
regression aid, not the agent's natural-language router and not an LLM accuracy
measurement. The corpus in `tests/routing-cases.json` covers every primary category
plus ambiguous prompts. It intentionally records one primary category even when
the agent should combine skills. Session overrides, secondary skills, and
conversation context are outside this baseline's scope.

To measure a real agent, run each corpus prompt through its `/agent-master route`
command in a fresh context and capture the primary category as a JSON object:

```json
{"build":"Build/Create","refactor":"Refactor","debug":"Debug/Fix"}
```

Include every corpus ID, then run:

```sh
node scripts/routing.js evaluate --predictions captured-results.json
```

Missing predictions count as failures; unknown IDs are rejected. Store the agent,
model, skill revision, and run date alongside the captured file for repeatability.
CI runs only the offline baseline and scorer tests; it makes no model calls.

Availability checks use `scripts/routing-requirements.json`, whose categories and
referenced skills are checked against the source table. They report each entry or
conditional route target individually: missing an optional alternative does not
mean the entire category is unusable. A smaller install profile can intentionally
leave targets missing.

Local skills are checked for a skill file. Plugin targets remain `unknown` unless
`--plugins` supplies a JSON array of fully qualified loaded names such as
`["anthropic-skills:running-marketing"]`. Missing names in that explicit inventory
are reported as missing. The checker does not assume files expose the host's
plugin registry.

For REA/IDA tools, `--mcp-config` accepts JSON with `mcpServers` or `servers` objects.
Recognized server keys are in the requirements registry. Absent/disabled entries
are missing; present entries are only `configured`, not proven healthy. Without
an explicit file, MCP status is unknown. TOML and host-specific registries are not
read automatically. No command, credential, or environment values are printed.
Native providers such as Ghidra or IDA Pro and server reachability require separate
runtime verification. CLI prerequisites are checked on PATH without execution.

Exit codes: `0` means no failed benchmark cases or known missing requirements;
`1` means a benchmark failure or missing requirement; `2` means invalid input or
a stale registry. Unknown prerequisites do not produce a false healthy claim.
Both doctor scripts include the availability check when Node.js is available.
