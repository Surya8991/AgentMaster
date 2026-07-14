---
type: auto
description: "Use when the user wants to open, launch, start, or view the Claude Code task dashboard / Kanban board — a live web UI showing tasks across sessions (pending / in-progress / completed), dependencies, timeline, and activity. Wraps the standalone claude-task-viewer Express app. Not for creating or editing tasks (Claude Code owns task state); this only observes."
---

Launches and manages the **claude-task-viewer** dashboard — a real-time Kanban board that reads `~/.claude` task JSON and serves it in the browser. Observation only: Claude Code controls task state, this just visualizes it.

## Resolve the app directory

The app lives outside `~/.claude/skills` (it's a full Node app, not a skill). Its location is stored in a config file so this skill stays portable:

```bash
CFG="$HOME/.claude/.agentmaster-cache/task-viewer.path"
APP_DIR="$(cat "$CFG" 2>/dev/null)"
```

If `$CFG` is missing or `$APP_DIR` doesn't contain `server.js`, tell the user the app isn't installed/registered and ask for its path, then write it back:
`printf '%s' "<path>" > "$CFG"`. Do not guess absolute paths.

## Commands

Default (no arg) or `start`:
1. Read `$APP_DIR` as above.
2. Ensure deps exist: if `$APP_DIR/node_modules` is missing, run `npm install` in `$APP_DIR` first.
3. Start the server **in the background** and open the browser:
   `PORT=<port-if-given> node "$APP_DIR/server.js" --open`
   - Default port is **3456**; it auto-increments if busy (unless `PORT` is set).
   - Run it as a background process so it keeps serving after this turn.
4. Report the URL it printed (`http://localhost:<port>`).

`status`: `curl -s -o /dev/null -w '%{http_code}' http://localhost:3456` (try the reported port) — 200 means running.

`stop`: kill the running server process.
- Windows: `taskkill //F //IM node.exe` is too broad — prefer finding the PID bound to the port. If unsure, tell the user which PID/port and let them confirm.
- Unix: `pkill -f "server.js"` scoped to this app.

## Notes

- The viewer reads task data from `$CLAUDE_DIR` (defaults to `~/.claude`). Override with `CLAUDE_DIR=<path>` or `--dir <path>` if the user keeps tasks elsewhere.
- It's read-only over tasks; never claim it can create/modify/delete task state on Claude's behalf.
- This is a long-running server. Don't block the conversation waiting on it — start it detached and move on.
