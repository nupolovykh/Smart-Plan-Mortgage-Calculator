# Dependency updates

Updates land on `deps` without a human and reach `main` through one reviewed
pull request. Built for an **archived** project: nobody is watching, so the
design optimises for "keeps working unattended" over "clever".

```
Dependabot ─▶ PR ─▶ CI ──green on this exact commit──▶ squash-merged into deps
                                                              │
                                          promotion PR (CI runs on the result)
                                                              │
                                                       ◀ human merges ▶
                                                              ▼
                                                             main
                                                              │
                                        deps re-cut from main ┘
```

## Branch contract

| Branch | Who writes | History |
|---|---|---|
| `main` | humans only | amend-only — the archive's history stays flat |
| `deps` | bots only (Dependabot, Actions) | **disposable**, re-cut from `main` after every promotion |

`deps` holding nothing but bot commits is not a style rule, it is what makes the
rest work — see below.

## Why `deps` is reset, never merged

The usual design keeps the integration branch level by merging `main` into it.
That design breaks: `deps` exists to change lockfiles, `main` changes lockfiles,
and lockfiles conflict on nearly every line. GitHub answers `409 Merge conflict`,
no token changes that, and a human has to resolve a generated file by hand.

`deps` does not need merging, because **every bot commit is regenerable**. Reset
the branch and Dependabot re-reads the manifest, sees the old versions, and
raises the same bumps on its next scan. So the branch is thrown away and re-cut
from `main` instead of merged into. No merge, no conflict, no human.

The guard in `deps-promote.yml` is what keeps that assumption true: one non-bot
commit on `deps` and the workflow resets nothing and turns red. The single
exception is a commit that is provably `main`'s own amended-away tip (detected
via `github.event.before` on the force-push), which is debris, not work.

Every state the two branches can be in is handled. *Adds content* below means
`deps`'s tip commit points at a different tree than the commit the two branches
split from. It is not "the compare endpoint reported changed files", which is
cached and wrong just after a merge, and it is not "`deps` differs from the tip
of `main`", which stops being the same question the moment `main` moves on —
and a push to `main` is what triggers this workflow:

| `main` vs `deps` | Cause | Action |
|---|---|---|
| identical | steady state | nothing |
| ahead, adds content | updates collected | open/refresh the promotion PR |
| ahead, adds nothing | one full cycle's leftover merge | reset `deps` |
| behind | promotion merged with a merge commit | fast-forward `deps` |
| diverged, adds nothing | promotion squash-merged, or `main` moved on | reset `deps` |
| diverged, adds content, promotion open | `main` moved on under real bumps | merge `main` in through `update-branch`, keep the bumps |
| diverged, adds content, no promotion | same, nothing to merge through | open the promotion as it stands |
| diverged, amended tip | `git commit --amend` on `main` | reset `deps`, bumps re-raised |
| diverged, real human commit | someone pushed to `deps` | refuse, run turns red |

The `update-branch` row is the one that is easy to get wrong. Treating every
divergence as a rewrite and re-cutting the branch means the update queue
restarts from nothing on every single commit to `main` — and on every security
fix, once those are enabled. Only a genuine force-push re-cuts it now.

## Why there is no checkout

Neither automation workflow checks out the repository — every step is a `gh api`
call. There is no working tree and no on-disk script for a push to `deps` to
poison, so a job holding `contents: write` can never be made to execute code
that came from the branch it writes to. This is why no `ref:` pin is needed:
the class of problem it defends against does not exist here.

## Why updates are ungrouped

Grouping trades away the property that matters most when nobody is watching.
One pull request per bump means a bump that breaks the build blocks only itself
and the rest still land. Inside a group, one bad member holds back every good
one until a human splits it out. Dependabot rebases the losers of a lockfile
race by itself, so the queue drains without help — measured on this repository:
nine updates, two days, zero left open.

## Why `npm audit` is not in CI

It answers a question about the global advisory database, not about the commit
under test. A newly published advisory turns every open pull request red at once
— including the bump that fixes it — and in a repository where green CI is what
merges updates, that stops updates from landing exactly when they matter most.
It runs weekly in `security-audit.yml` and blocks nothing.

## How silence is broken

An unattended repository's real failure mode is not a bad merge, it is a queue
that quietly stops moving. The only notification that reaches anyone is a failed
workflow run, which GitHub emails to the repository owner. So:

- the weekly sweep **exits non-zero** when a Dependabot pull request has been
  open and unmerged for 14 days, or when one passed CI and the merge was refused
  (that one is the automation's own fault and fails immediately);
- `deps-promote.yml` exits non-zero when the branch contract is violated;
- `security-audit.yml` turns red on a new high-severity advisory.

A green run genuinely means nothing needs attention.

## Known limits

- **Security updates never reach `deps`.** `target-branch` is a version-update
  option; a fix raised from a Dependabot alert goes to the default branch
  whatever `dependabot.yml` says. Nothing in a repository can redirect it. The
  sweep lists those pull requests and turns red once they are 14 days old, so
  they cannot be invisible — but a human merges them. This is also why the
  branch is called `deps` and not `security`: security updates are the one kind
  it does not carry.
- **The gate is only as good as CI.** There are no frontend tests here, so
  `CI Pipeline` green on a React or Vite bump means "it type-checks, lints and
  builds", not "the calculator still computes the right payment" — and the
  price/annuity formula is duplicated between `MortgageValidator.php` and
  `App.tsx`. Auto-merge does not make the suite stronger; it makes its gaps land
  faster. Frontend tests are Task 2 in `tasks/01-improvement-tasks.md`.
- **Actions are pinned to major tags, not commit SHAs.** A retargeted tag would
  execute in a job holding a write token. Pinning to SHAs closes that, and
  Dependabot still updates them; it is the obvious next hardening step.
- **The automation runs on a personal access token, not `GITHUB_TOKEN`.** See
  *The token* below. Two limits disappeared with it and are recorded here so
  nobody reintroduces them: `GITHUB_TOKEN` may not write `.github/workflows/`,
  which left every action bump unmergeable whenever it sat behind its base; and
  it could not ask for help either, because `@dependabot rebase` from
  `github-actions[bot]` is answered *"Sorry, only users with push access can use
  that command"*. The promotion also no longer parks a second CI entry at
  `action_required`, because it is opened by a real account.
- **A sweep can be cancelled while it is queued.** `concurrency` with
  `cancel-in-progress: false` keeps exactly one run waiting per group; during a
  burst of events the waiting one is cancelled by the next. Nothing is lost —
  every sweep re-reads state from the API rather than from the event — so a
  `cancelled` sweep in the run list is expected, not a fault. Each push to
  `main` also spends one sweep that exits `skipped`, because `workflow_run`
  fires for CI runs of every event type and only `pull_request` ones matter.

## The token

`dependabot-auto-merge.yml` and `deps-promote.yml` authenticate as the repository
secret `DEPS_PAT`. Nothing else does: `ci.yml` and `security-audit.yml` never see
it.

That split is the reason a personal access token is acceptable here at all. Those
two are the only workflows that check out the repository and run third-party code
— `npm ci`, `composer install`, the test suites. The two that hold the token do
no checkout at all; every step is an API call, so there is no working tree, no
script on disk that a push to `deps` could poison, and no package install that
could read the environment. Grep for `actions/checkout` in either file and the
count is zero. Keep it that way: adding a checkout step to a workflow that holds
`DEPS_PAT` hands the token to whatever the update being tested chooses to run.

What it must be able to do: read and write contents, read and write pull
requests, read and write Actions, and write files under `.github/workflows/`.

When it expires both workflows start failing with 401. The weekly sweep turns
red, which is the intended notification, but that is up to seven days of a queue
that has silently stopped. Renew it before the expiry date rather than after the
first red run.

The design and these two workflow files are shared with
`QA-web-labprojects-python`, where they were measured end to end against real
updates; that repository's `docs/dependency-updates.md` carries the timings and
`docs/porting-the-dependency-pipeline.md` the checklist this repository was
ported with.

## Repository settings this depends on

Not in the repository, so listed here:

1. **Settings → Secrets and variables → Actions**: `DEPS_PAT` — see above.
   Without it both automation workflows fail immediately with 401.
2. **Settings → Actions → General → Workflow permissions**: *Allow GitHub
   Actions to create and approve pull requests* — ticked. Without it the
   promotion pull request cannot be opened and the step fails with 403.
3. **Settings → General → Pull Requests**: squash merging enabled.
4. **Settings → Advanced Security → Dependabot alerts**: enabled. Without it no
   advisory is ever detected, and the sweep's check for a security update
   stranded on `main` can never fire, because no such pull request is raised.
5. **Branch protection on `main`: require a pull request, and tick *Do not allow
   bypassing the above settings*.** The second half is what actually stops a
   direct push by an administrator. Leave *Require approvals* unticked — its
   minimum is 1, and a repository with one maintainer cannot satisfy it. Do not
   add required status checks from a matrix: the check names carry the matrix
   values, so renaming one entry blocks every future pull request permanently.

## Running it by hand

```
Actions → Dependency promotion → Run workflow   # creates/realigns deps, opens the promotion PR
Actions → Dependency auto-merge → Run workflow  # sweeps; one log line per open update
```

Both are safe to run repeatedly: they read state and act only where there is
something to do.
