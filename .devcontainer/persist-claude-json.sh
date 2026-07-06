#!/bin/bash
set -e

# -- Persist ~/.claude.json across rebuilds --
# ~/.claude.json lives next to ~/.claude/ but can't be volume-mounted
# directly: a fresh named volume has no content, so Docker materializes the
# mount target as an empty directory instead of a file, which breaks any
# code expecting to read/write it as JSON (this bit us once already).
# Instead, store the real file inside the ~/.claude volume (which mounts
# cleanly as a directory) and symlink it back into place.
persist_claude_json() {
    local link="/home/vscode/.claude.json"
    local store="/home/vscode/.claude/claude.json"

    # Clean up a stray root-owned directory left by the old broken volume mount
    if [ -d "$link" ] && [ ! -L "$link" ]; then
        sudo rm -rf "$link"
        echo "  ✓ Removed stray directory from previous broken mount"
    fi

    if [ -L "$link" ]; then
        echo "  ✓ Already symlinked into persisted volume"
    elif [ -f "$store" ]; then
        ln -s "$store" "$link"
        echo "  ✓ Linked existing persisted config"
    elif [ -f "$link" ]; then
        mv "$link" "$store"
        ln -s "$store" "$link"
        echo "  ✓ Migrated existing config into persisted volume"
    else
        local latest_backup
        latest_backup=$(ls -t /home/vscode/.claude/backups/.claude.json.backup.* 2>/dev/null | head -1)
        if [ -n "$latest_backup" ]; then
            cp "$latest_backup" "$store"
            echo "  ✓ Restored config from latest backup"
        else
            echo '{}' > "$store"
            echo "  - No existing config or backup found; created empty config"
        fi
        ln -s "$store" "$link"
    fi
}
