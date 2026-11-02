# Routing evaluation: 2026-11-02

## Result

The blinded model pilot agreed with all **43/43 primary-category labels** across
the 27 routing categories. The deterministic baseline also passes these cases.
There were no observed category errors to justify changing the routing table or
adding skills on this evidence.

[Predictions](../tests/evaluations/2026-11-02/predictions.json),
[metadata](../tests/evaluations/2026-11-02/metadata.json), and the three adjacent
batch files preserve each decision, selected entry skill, and explanation.

```sh
node scripts/routing.js evaluate --predictions tests/evaluations/2026-11-02/predictions.json
```

## Method and limits

The source was commit `42689df1b416676f4e83b6399cb19157b83e3ff5`. Three Codex
subagents started with fresh contexts and received only the canonical skill and
blinded ID/prompt pairs, split into batches of 15, 14 and 14. Expected labels and
the deterministic classifier were withheld. Predictions were captured before
scoring; no labels or routing rules were changed to improve the score.

This is an actual model dry-run pilot, but **not** 43 independent fresh-session
production runs. Each batch shared context, only one pass was sampled, and the
curated corpus reflects rules already present in the skill. The exact model
snapshot was not exposed. The result measures primary-category agreement only;
entry skills were recorded but not independently scored. No domain task was
executed, so completion, cost, latency, tool health and user satisfaction remain
unmeasured. This is not evidence of 100% accuracy on arbitrary requests.

## Operational gaps found

The local default Claude installation produced 27 available checks, 18 unknown
checks, and two missing CLI checks: `dap` and `agent-browser`. These are checks,
not unique skills (some targets appear in multiple categories). Plugin inventories
and REA/IDA MCP health were not supplied, so unknown results remain unknown.
This filesystem check is not a claim about the active Codex tool registry.
No missing tools were installed or configured.

The pushed CI run failed in Linux PowerShell because Windows-style separators
were passed to native Git and .NET file APIs. The follow-up replaces those paths
with portable separators and adds stronger ownership/provenance/native-path
assertions to the locked dependency tests.

## Process for the next evaluation

1. Keep this pilot immutable; append new dated evaluations with source/model
   provenance and a corpus hash.
2. Collect naturally occurring, anonymized requests that were not used to write
   the routing rules. Assign expected primary and acceptable secondary routes
   before running the agent. Use one fresh context per request and repeat runs
   when assessing consistency.
3. For real tasks, distinguish category correctness, selected entry skill,
   prerequisite readiness, task outcome (`completed`, `blocked`, `failed`, or
   `not_run`), and whether the user corrected the route. Do not count a category
   match as task success. Omit private prompt content from shared reports.
4. Fix prerequisite failures before adding overlapping skills. Add a new skill
   only for a recurring uncovered task, after license, collision and runtime
   prerequisite checks. A perfect score on this small corpus is a reason to
   expand the evaluation, not the dependency catalog.
