# Isolated `claudeme` user

## Use it

Terminal panel → dropdown next to `+` → **claude**.

Or manually:
```bash
sudo -u claudeme -i
```

**Do not use `su claudeme`** — that account's password is intentionally
locked (no one can ever log into it directly). Switching only works through
`sudo`, because of a NOPASSWD rule scoped to `vscode → claudeme` only.

If `CLAUDE_CODE_OAUTH_TOKEN` was set on the host before the container was
created, `claude` is ready to use immediately — no login, no onboarding
wizard (`~/.claude.json` is pre-seeded with onboarding marked complete, and
the token is exported from `~/.bashrc` on every login shell). Verify with:
```bash
claude /status
```
If the token wasn't set on the host, `claude` will prompt for an interactive
login the first time instead.

## Why it exists

Running `claude` as the same OS user the VS Code extension uses makes them
share `~/.claude/projects/<dir-hash>/` session storage — a background CLI
session and the extension can then collide over the same locked session:

```
Error: Session <uuid> is currently running as a background agent (bg).
```

`claudeme` has its own `$HOME`, so its own `~/.claude`, so no shared
session files, so no collision. The VS Code extension keeps running as
`vscode`, unaffected.

## Files

- `lib/setup-claude-cli.sh` — creates the user, the sudoers rule, workspace
  group access, shared umask, seeds `~/.claude.json` with onboarding
  pre-completed, seeds `~/.gitconfig` from vscode's (identity + credential
  helper), marks the workspace `safe.directory`, and injects
  `CLAUDE_CODE_OAUTH_TOKEN`/`DISABLE_AUTOUPDATER` into `claudeme`'s
  `~/.bashrc`. Takes the workspace folder path as its one argument — see
  `post-create.sh`, which captures it via `pwd` rather than hardcoding
  `/workspaces/phpcalculator`, since devcontainer.json doesn't pin
  `workspaceFolder` and the CLI mounts under `/workspaces/<local-folder-basename>`.
  Called from `post-create.sh` step `[2/7]`.
- `lib/setup-claude-vscode.sh` — the counterpart for the `vscode` user
  (permission fix; it gets `containerEnv` and `~/.gitconfig` for free and
  doesn't need the login-shell token injection `claudeme` needs). Also
  shadows `claude` with a bash function that refuses to run and points at
  the `claude` terminal profile instead — see below. Step `[1/7]`.
- `devcontainer.json` — adds the `claude` terminal profile (commented inline
  with the same explanation as above).

## Verify

```bash
# as claudeme:
whoami                          # claudeme
echo $HOME                      # /home/claudeme

# back in a normal (vscode) terminal:
ls /home/claudeme/.claude       # Permission denied — proves isolation
```

Shared file access (run first line as claudeme, second as vscode):
```bash
echo hi > backend/src/test.tmp          # as claudeme
echo bye >> backend/src/test.tmp && rm backend/src/test.tmp   # as vscode — should just work
```

## Known rough edges

- If `CLAUDE_CODE_OAUTH_TOKEN` isn't set on the host at container creation
  time, it never reaches `claudeme`'s `~/.bashrc` and it falls back to an
  interactive login, same as `vscode` did originally.
- The workspace root directory can't be re-grouped (it's the bind-mount
  point, Docker blocks `chgrp` on it), so it's `o+rwx` as a fallback.
  Everything below it is properly group-scoped.
- This only isolates `claudeme` from `vscode`. Two `claude` processes run
  as the *same* user in the *same* directory will still collide.
- The workspace is owned by `vscode` (uid 1000), not `claudeme` (uid 1001),
  so git would normally refuse to touch it ("detected dubious ownership").
  `setup-claude-cli.sh` adds the workspace folder to `claudeme`'s
  `safe.directory` list to work around this.
- `claude` typed into a `vscode` terminal now prints a redirect message and
  refuses to run (a bash function in `~/.bashrc` shadows it) — it doesn't
  touch the underlying PATH binary, so it only affects interactive shells,
  not the VS Code extension (which uses its own bundled binary anyway).
  Ordering matters here: `post-create.sh` sets up `vscode` (adding the ban)
  before `claudeme` (which seeds its `~/.bashrc` from vscode's on first
  boot) — so without a fix, claudeme's very first boot would inherit the
  ban too. `setup-claude-cli.sh` strips that specific block back out of
  claudeme's `~/.bashrc` unconditionally, every run, so it self-heals
  regardless of copy order.
- `claudeme`'s `~/.gitconfig` is a one-time copy of vscode's, taken at
  `postCreateCommand` time. If vscode's credential helper later changes
  (e.g. a VS Code Server update rotates the version-hashed helper path),
  `claudeme`'s copy goes stale until the container is rebuilt — it's never
  re-synced after the first seed.
