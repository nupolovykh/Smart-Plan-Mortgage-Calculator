#!/bin/bash
set -e  # abort on first error

# Fix up the vscode user's Claude account for use with the VS Code extension.
# A freshly-created named volume mounts root-owned, so ownership needs fixing
# on first boot; after that this function just verifies and blocks direct CLI use.
setup_claude_vscode() {
    # ~/.claude volume mounts root-owned on creation — fix it once, then it stays fixed
    if [ ! -w "/home/vscode/.claude" ]; then
        sudo chown -R vscode:vscode /home/vscode/.claude
        echo "  ✓ Permissions fixed"
    else
        echo "  ✓ Permissions are correct"
    fi

    # Block direct `claude` CLI invocation for vscode — the VS Code extension
    # already runs its own bundled binary, and a second CLI session would collide with it.
    local marker_start="# >>> claude-cli-ban >>>"
    local marker_end="# <<< claude-cli-ban <<<"
    local bashrc="/home/vscode/.bashrc"

    # Strip any previous copy of the block so re-running this script is idempotent
    sudo sed -i "/^${marker_start//\//\\/}\$/,/^${marker_end//\//\\/}\$/d" "$bashrc"

    # Append a shell function that overrides `claude` with an error + pointer to alternatives
    {
        cat <<BLOCK
$marker_start
claude() {
    echo "claude is disabled for the vscode user" >&2
    return 1
}
$marker_end
BLOCK
    } | sudo tee -a "$bashrc" >/dev/null
    echo "  ✓ Blocked direct 'claude' CLI invocation for vscode user"
}
