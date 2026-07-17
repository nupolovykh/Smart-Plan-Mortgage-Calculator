# Git credential postmortem — vscode / claudeme

Four root causes surfaced while giving `claudeme` and `vscode` — the two OS users sharing the
devcontainer — working, independent git credentials. Two were gaps the original setup never
covered; two were bugs hiding inside the fix itself. Filed as
[issue #11](https://github.com/nupolovykh/Smart-Plan-Mortgage-Calculator/issues/11), fixed in
[PR #12](https://github.com/nupolovykh/Smart-Plan-Mortgage-Calculator/pull/12). A rendered,
annotated version of this writeup is also available at:
https://claude.ai/code/artifact/bf2f890f-a4f7-4ee9-bf0c-fa9c63e5c2b2

## The filesystem, annotated

Where each piece of the problem actually lived — permission modes and ownership are what made
this hard, not the git config syntax itself.

```
/etc/gitconfig                              [system layer]
  credential.helper = ...                     VS Code's own injected helper — applies to
                                               every user in the container, including
                                               claudeme, unless overridden.

/home/vscode/                               [mode 700]
  ├─ .gitconfig                                identity, copied from the host machine
  ├─ .vscode-server/bin/<hash>/node            the binary /etc/gitconfig calls — blocked
  │                                            for claudeme: 700 shuts out group members
  │                                            entirely
  └─ .local/bin/gh                             wrapper: `sudo -u claudeme gh "$@"`

/tmp/                                        [per-connection]
  ├─ vscode-remote-containers-<id>.js          world-readable script the node binary runs —
  │                                            reads $REMOTE_CONTAINERS_IPC
  └─ …-ipc-<id>.sock                           live tunnel back to the host's VS Code
                                               extension — connect access owner-only, and the
                                               whole path is regenerated on every reconnect

/home/claudeme/                              [the fix lives here]
  ├─ .gitconfig                                identity + host-scoped credential.helper
  │                                            override
  ├─ .git-credentials                          static token, own file — not shared, not
  │                                            symlinked
  ├─ .config/gh/hosts.yml                      the one real gh login in the container
  └─ .local/bin/gh                             the one real gh binary

/workspaces/phpcalculator/.git/config        [repo-local, read last]
  credential.https://github.com.helper =       a stray empty reset, left over from earlier
                                               troubleshooting — this one line quietly
                                               overrode the entire global fix, for this repo
                                               only
```

## Four root causes

The first two are gaps the two-user split never accounted for. The last two are bugs that
only existed inside the fix itself — found by testing the fix, not by guessing.

### 1 · claudeme had an identity, but no credential path — *design gap*

**What broke:** `git push` as claudeme → `Permission denied`, immediately.

**Why:** claudeme was given a name and email, but never its own credential helper — so it
silently inherited `/etc/gitconfig`'s helper. That helper is a **live tunnel** to the host, not
a stored password: it only exists while a VS Code window is connected, its binary sits behind
vscode's `700` home directory, and its socket only accepts connections from its owner. All
three would have to be true at once for claudeme to use it — and by design, none of them ever
are.

**Fix:** stopped depending on that tunnel entirely — gave claudeme its own static credential
file instead.

### 2 · gh's shared config fought itself — *design gap*

**What broke:** sharing one `~/.config/gh` between both real users via one Docker volume —
whichever user hadn't run `gh` most recently would start failing.

**Why:** `gh` rewrites its own config to mode `600` (owner-only) on almost every invocation,
not just login. Two real OS users touching the same file meant ownership kept flipping between
them — each run silently locked the other one out.

**Fix:** claudeme became the sole real owner (own binary, own login); vscode's `gh` is now a
thin wrapper that proxies to claudeme via passwordless `sudo`. Nothing shared, nothing to fight
over.

### 3 · a stray leftover entry silently cancelled the fix — *bug in the fix*

**What broke:** after the static credential file was installed correctly, `git push` in this
repo still fell back to an interactive username prompt.

**Why:** git merges credential config from three layers, in this order — a later, matching
entry can override or reset an earlier one:

| Layer | File | State |
|---|---|---|
| System | `/etc/gitconfig` | the broken tunnel helper |
| Global | `~/.gitconfig` | correctly reset, then pointed at the new file |
| Local (wins) | `.git/config` | an old, empty reset — nothing after it |

An earlier ad-hoc `git config credential.https://github.com.helper ""` had been run without
`--global`, which defaults to the local, per-repo file. Local is read last, so its empty entry
wiped out an otherwise-correct global fix — for this one repo only.

**Fix:** `git config --list --show-origin --show-scope` named the exact file at fault;
`git config --local --unset-all credential.https://github.com.helper` removed it.

### 4 · the credential file's own format was silently wrong — *bug in the fix*

**What broke:** even after removing the stray override, push still failed — non-interactively
this time, with `could not read Username … No such device or address`.

**Why:** `git credential-store` needs a `user:password@host` shape. The stored line had the
token alone before the `@`, with no colon — which parses as a username with no password, and
(confirmed directly, with throwaway dummy tokens) a line in that shape is simply never returned
by a lookup. It looked present in the file; it was functionally invisible to git.

| | Format | Result |
|---|---|---|
| Before | `https://<token>@github.com` | matches nothing |
| After | `https://x-access-token:<token>@github.com` | resolves correctly |

**Fix:** rewrote the credential file using `x-access-token` as the username — the same
placeholder GitHub's own Apps/Actions tooling uses for a token-as-password credential.

## Current state

All four causes fixed and verified — `git push` authenticates cleanly as claudeme, the
container has been rebuilt, and vscode's independent copy of the same fix is in place.
