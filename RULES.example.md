# Claude Rules — Your Name (@your-github-username)

These rules are ABSOLUTE. Never skip. Never override. Check before every action.

Copy this file to `~/.claude/RULES.md` and customize with your own values.

```bash
cp RULES.example.md ~/.claude/RULES.md
# Then edit ~/.claude/RULES.md with your info
```

---

## 1. No Claude Co-Author
Never add `Co-Authored-By: Claude` to any commit message. Ever.

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
  - Skill counts, category counts
  - Any user-facing text

**This is absolute. Never commit without checking every item above.**

## 3. Only Commit, Never Push
User pushes manually. Only commit. One-time exceptions only when user explicitly says so.

## 4. AgentMaster Auto-Updates
When AgentMaster runs, pull latest from all dependency repos in background. 6-hour cooldown.

## 5. GitHub Username
<!-- Replace with your GitHub username -->
Username is **your-github-username**.

## 6. Suggest on Real Gaps
When a real gap is hit, suggest best repos or technology to fill it.

## 7. Skill Repos → Skills Folder
When installing a new skill repo:
<!-- Replace with your preferred path -->
1. Move it to `D:/Coding/Agent-Skills/`
2. Ask user before updating AgentMaster repo

## 8. Best Free Sources First
When building anything, use best free sources first (free APIs, open-source libs, free tiers).

## 9. Code Reviews: Blunt Mode
When reviewing code:
- State facts, no sugar coating
- Every finding has file:line and a concrete fix
- Rate by severity (Critical/High/Medium/Low)
- End with one-line verdict

---

## Project Paths
<!-- Customize these paths for your setup -->
- Coding: `D:/Coding/`
- Agent Skills: `D:/Coding/Agent-Skills/`
- AgentMaster repo: `D:/Coding/AgentMaster/`
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
   - Replace paths with your actual project paths
   - Add or remove rules as needed

3. Claude will automatically read `~/.claude/RULES.md` at the start of every session.

4. To verify rules are loaded, ask Claude: "What rules do you have?"
