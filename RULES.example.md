# Claude Rules — Your Name (@your-github-username)

These rules are ABSOLUTE. Never skip. Never override. Check before every action.

Copy this file to `~/.claude/RULES.md` and customize with your own values.

```bash
cp RULES.example.md ~/.claude/RULES.md
# Then edit ~/.claude/RULES.md with your info
```

---

## 1. No AI Co-Author
Never add `Co-Authored-By` lines to any commit message.

## 2. Pre-Commit Checklist (NEVER SKIP)
Before EVERY commit, verify ALL of these:
- [ ] Run lint/build — zero errors
- [ ] Scan for leaked secrets (API keys, tokens, passwords, .env values)
- [ ] Verify functionality works (dev server, browser, CLI)
- [ ] Update ALL doc refs:
  - README.md (badges, counts, tables, descriptions)
  - Help buttons/dialogs in UI
  - Publishing guides
  - Install/uninstall scripts
  - Version numbers (manifest, package.json, help text)
  - Repo structure trees in docs
  - Feature counts, category counts
  - Any user-facing text that references features, limits, or versions

**This is absolute. Never commit without checking every item above.**

## 3. Only Commit, Never Push
User pushes manually. Only commit. One-time exceptions only when user explicitly says so.

## 4. Auto-Updates
<!-- Optional: configure auto-update behavior for your skill orchestrator -->
When the orchestrator runs, pull latest from all dependency repos in background. Set a cooldown (e.g. 6 hours) to avoid spamming.

## 5. GitHub Username
<!-- Replace with your GitHub username -->
Username is **your-github-username**.

## 6. Suggest on Real Gaps
When a real gap is hit (missing tool, skill, or capability), suggest best repos or technology to fill it. Don't wait to be asked.

## 7. Skill Repos Organization
When installing a new skill repo:
<!-- Replace with your preferred path -->
1. Move it to your skills folder (e.g. `~/projects/agent-skills/`)
2. Ask before updating the orchestrator repo

## 8. Best Free Sources First
When building anything, use best free sources first (free APIs, open-source libs, free tiers). Then paid repos/resources. Don't default to paid solutions.

## 9. Code Reviews: Blunt Mode
When reviewing code:
- State facts, no sugar coating
- Every finding has file:line and a concrete fix
- Rate by severity (Critical/High/Medium/Low)
- End with one-line verdict

---

## Project Paths
<!-- Customize these paths for your setup -->
- Coding root: `~/projects/`
- Agent Skills: `~/projects/agent-skills/`
- Orchestrator repo: `~/projects/AgentMaster/`
- Claude skills: `~/.claude/skills/`
- This file (local): `~/.claude/RULES.md`

---

## How to Use

1. Copy this file to your Claude config:
   ```bash
   cp RULES.example.md ~/.claude/RULES.md
   ```

2. Edit `~/.claude/RULES.md` with your actual values:
   - Replace `your-github-username` with your GitHub username
   - Replace all paths with your actual project paths
   - Add or remove rules as needed
   - Remove HTML comments after filling in values

3. Claude will automatically read `~/.claude/RULES.md` at the start of every session.

4. To verify rules are loaded, ask Claude: "What rules do you have?"
