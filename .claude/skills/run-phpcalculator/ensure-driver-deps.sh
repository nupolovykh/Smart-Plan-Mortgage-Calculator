#!/usr/bin/env bash
# Lazily installs the run-phpcalculator skill's own dependencies (the
# Playwright npm package + headless Chromium, via setup-chrome-deps.sh) the
# first time a Claude Code session starts in this repo, instead of eagerly
# on every devcontainer build (see .devcontainer/post-create.sh, which
# covers composer/npm/db but deliberately not this ~330MB download).
#
# Meant to be called from a SessionStart hook. Exits immediately once
# already installed, so re-invocation on every session start is cheap.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKER="$SCRIPT_DIR/node_modules/.driver-deps-ready"
LOG_FILE="$SCRIPT_DIR/.ensure-driver-deps.log"

[ -f "$MARKER" ] && exit 0

{
    echo "=== $(date -Is) installing run-phpcalculator driver deps ==="
    cd "$SCRIPT_DIR"
    npm install
    bash setup-chrome-deps.sh
    touch "$MARKER"
    echo "=== $(date -Is) done ==="
} >> "$LOG_FILE" 2>&1
