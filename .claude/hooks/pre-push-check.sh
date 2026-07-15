#!/usr/bin/env bash
# Gate for `git push` while sitting on a protected branch (main/master/develop,
# matching .github/workflows/ci.yml's trigger list, plus devops since that's
# also actively pushed to directly) - runs the same checks CI runs (composer
# test, npm lint, npm build) and blocks the push locally if any fail, instead
# of finding out only after CI runs remotely.
#
# Best-effort: matches on the *current branch*, not the push's actual target
# ref (parsing every valid `git push` invocation form isn't worth it for a
# convenience gate, not a security boundary). A compound command like
# `cmd && git push` also won't trigger the settings.json "if" filter, since
# that's a simple prefix match on the whole command string.
set -uo pipefail

PROTECTED='^(main|master|develop|devops)$'
current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"

if ! [[ "$current_branch" =~ $PROTECTED ]]; then
    exit 0
fi

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

failures=()

if ! (cd backend && XDEBUG_MODE=off composer test) >>"$LOG" 2>&1; then
    failures+=("backend: composer test")
fi
if ! (cd frontend && npm run lint) >>"$LOG" 2>&1; then
    failures+=("frontend: npm run lint")
fi
if ! (cd frontend && npm run build) >>"$LOG" 2>&1; then
    failures+=("frontend: npm run build")
fi

if [ "${#failures[@]}" -eq 0 ]; then
    exit 0
fi

joined="$(printf '%s, ' "${failures[@]}")"
joined="${joined%, }"
reason="Blocked push to '$current_branch' - failing checks: $joined. Last 25 log lines:
$(tail -25 "$LOG")"

jq -n --arg reason "$reason" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
