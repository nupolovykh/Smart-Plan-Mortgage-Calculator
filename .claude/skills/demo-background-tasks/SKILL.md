---
name: demo-background-tasks
description: Demonstrate Claude Code's background execution mechanisms — backgrounded bash commands, background subagents, and Monitor event streams — using this repo's backend as a sandbox. Use when asked to demo, show off, test, or explain background/async task capabilities.
---

This isn't about the mortgage calculator app itself — it uses the PHP backend
as a convenient, disposable sandbox to demonstrate three *independent*
background mechanisms available in Claude Code. Each produces a
distinguishable kind of notification, so running all three side by side
makes the difference concrete instead of abstract.

Requires the backend to be installed (see
`../run-phpcalculator/SKILL.md` for full setup — `composer install` +
SQLite db). All paths below are relative to the repo root.

## Demo 1 — backgrounded bash command

Run something real (not just `sleep`) so there's an actual pass/fail to check:

```bash
cd backend && composer test > /tmp/test.log 2>&1 &
```
Use the Bash tool's `run_in_background: true` rather than shell `&` directly —
it gets you an automatic completion notification.

**Gotcha:** this suite runs in ~5ms. It can finish before you'd meaningfully
react to a notification, or even complete without a separate notification
firing at all if it's already done by the time you check. Don't rely on the
notification alone — read `/tmp/test.log` directly to confirm:
```bash
cat /tmp/test.log   # expect: OK (11 tests, 15 assertions)
```

## Demo 2 — background subagent

Spawn an `Explore` agent for a real multi-step search, not a one-liner grep,
so it takes long enough to demonstrate running independently:

```
Agent(subagent_type: "Explore", run_in_background: true,
  description: "Find all TODO/FIXME comments in repo",
  prompt: "Search the repo for TODO/FIXME/XXX/HACK comments across PHP, TS,
  SQL, and shell files, excluding node_modules/vendor/.git/dist. Report
  file:line and text, grouped by file.")
```

This is qualitatively different from Demo 1: it's a whole separate reasoning
process (several tool calls, tens of seconds), not a single shell command.
You keep working; the result arrives as a `<task-notification>` when it's
done. (Result on this repo, for reference: zero TODO-style comments exist —
the backlog lives entirely in `tasks/01-improvement-tasks.md` instead.)

## Demo 3 — Monitor (event-driven, not polling)

Start a **second, disposable** backend instance on a scratch port so you don't
disturb whatever's already running on :8000, with its own log file to tail:

```bash
cd backend
php -S 0.0.0.0:8001 src/api.php > /tmp/backend-8001.log 2>&1 &
disown
curl -sf http://localhost:8001/api/areas >/dev/null && echo up
```

Arm a Monitor on that log, watching for each incoming request:

```
Monitor(command: "tail -f /tmp/backend-8001.log | grep --line-buffered Accepted",
  description: "new requests to backend-8001", persistent: false, timeout_ms: 300000)
```

Then trigger it:
```bash
curl http://localhost:8001/api/promos
```

**Gotchas:**
- `tail -f` replays the last existing lines in the file the moment it's
  armed — the *first* notification you get is that replay, not a live event.
  Only a `curl` sent *after* arming produces a genuinely new one.
- Without `persistent: true`, the Monitor auto-expires after `timeout_ms`
  (default 300000ms / 5 min) and sends a `[Monitor timed out — re-arm if
  needed.]` notification. That's expected teardown, not a failure.
- **Never `rm` + `touch` the log file while the php server is still running
  to "reset" it.** The process holds its stdout/stderr fd open to the old
  inode and keeps writing there forever (Unix unlink semantics — the path
  and the file aren't the same thing). `touch` at that path creates a
  *different* inode, so `tail -f` on the path sees nothing new — the
  server's real output goes into a file no path points to anymore. A silent
  Monitor timeout is the symptom (confirm via `ls -la /proc/<pid>/fd/1` —
  `(deleted)` means this happened). To actually get a clean log, kill the
  process and restart it so it reopens the path fresh.

## Cleanup

```bash
pkill -f "php -S 0.0.0.0:8001" 2>/dev/null
rm -f /tmp/backend-8001.log /tmp/test.log
```
If the Monitor hasn't already timed out on its own, stop it with `TaskStop`
(find its task ID via `TaskList` if it's out of context).

## What each demo actually proves

| Mechanism | Scope | Notification shape |
|---|---|---|
| Bash `run_in_background` | one shell command | single completion event |
| Background `Agent` | a whole sub-task (multi-step reasoning) | single completion event, richer result |
| `Monitor` | a long-lived stream | one event *per matching line*, until timeout/exit |

None of these are "only for long commands" — the common thread is *not
blocking the current turn*, at whatever scope (one command, one sub-task, or
an ongoing stream) the work actually needs.
