---
name: open-pr
description: Draft (and, once confirmed, create) a GitHub pull request for the current branch of the mortgage calculator repo, with a test-plan grounded in this repo's real commands and cross-references to tasks/01-improvement-tasks.md. Use when asked to open/create a PR or prepare a PR description.
---

Repo: `github.com/nupolovykh/Smart-Plan-Mortgage-Calculator`. No PR template
or CONTRIBUTING doc exists — conventions below are reverse-engineered from
history (`git log`), not written down elsewhere, so keep this file in sync
if that changes.

## Prerequisite: `gh` CLI

Actually *creating* the PR needs `gh` (`gh pr create`). Check first:
```bash
command -v gh
gh auth status
```
As of 2026-07 `gh` is installed at `~/.local/bin/gh` (a no-root portable
binary from `github.com/cli/cli/releases` — `claudeme` has no root, so a
normal package-manager install wasn't an option; see
`.claude/skills/run-phpcalculator/setup-chrome-deps.sh` for the same
unprivileged-binary pattern used elsewhere in this repo), but it is
**not authenticated**. Auth is interactive (`gh auth login`) — don't
attempt it yourself, ask the user to run it. If a future container
rebuild loses `~/.local/bin` (it's on the container overlay, not a
volume) and `gh` is missing again, don't reinstall it yourself either —
ask first, same as auth. Fall back to producing the drafted title/body as
plain text so the user can paste it into GitHub's "New pull request" UI
by hand.

## Drafting the PR

1. **Determine the diff**: `git log <base>..HEAD --oneline` and
   `git diff <base>...HEAD` — see the base-branch note below for what
   `<base>` should be.
2. **Actually run the checks**, don't just template placeholders for them:
   - `cd backend && composer test`
   - `cd frontend && npm run lint`
   - `cd frontend && npm run build`
   Report real pass/fail in the test-plan, not a generic checklist.
3. **If the diff touches `backend/src/MortgageValidator.php` or
   `frontend/src/App.tsx`**: run the `check-validator-sync` skill first
   and fold its verdict into the PR description (either "pricing logic
   verified in sync" or a called-out discrepancy — don't open the PR
   silently if it found drift).
4. **Cross-reference the backlog**: skim `tasks/01-improvement-tasks.md`'s
   20 items — if this change implements one, name it in the description
   ("Implements Task N: ...") instead of leaving the connection implicit.
5. **Title**: short, imperative, matches this repo's actual history style
   (e.g. "Fix broken payment method bank logos with self-hosted assets",
   "Switch devcontainer Claude setup to isolated claudeme user") — not
   Conventional-Commits (`feat:`/`fix:` prefixes aren't used here).

## Base branch

This repo has used `master` as the main line, with `develop` and `devops`
as integration branches for feature/infra work respectively (see e.g. PR
#8 merging `develop`→`master`, PR #7 merging `devops`→`master`). There's no
hard rule visible in history for which one a given change should target —
if it isn't obvious from the branch you're already on (e.g. a branch named
`devops/...` clearly targets `devops`), ask the user which base branch to
use rather than assuming `master`.

## Creating it

Creating a PR is visible to others and not something to do silently —
confirm the drafted title/body with the user before running `gh pr create`,
even if they're the one who asked for "a PR" in the first place (per this
project's standing rule on actions that affect shared state). Once
confirmed:
```bash
git push -u origin HEAD
gh pr create --base <base> --title "..." --body "$(cat <<'EOF'
...
EOF
)"
```
Return the PR URL when done.
