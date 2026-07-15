#!/bin/bash
set -e  # abort on first error

# Installs every external tool this devcontainer needs, in one place. Kept
# separate from the identity/permission scripts (setup-claude-vscode.sh,
# setup-claude-cli.sh) — "what binaries exist on this system" and "who is
# this user" are different concerns, even though some of these tools (vim,
# gh) happen to only ever be used by claudeme.
setup_tools() {
    _setup_tools_vim
    _setup_tools_sqlite3
    _setup_tools_gh
}

# claudeme's $EDITOR/$VISUAL is vim — the base image only ships vim-tiny
# (/usr/bin/vi), not the full vim binary that name resolves to.
_setup_tools_vim() {
    if ! command -v vim &>/dev/null; then
        sudo apt-get update && sudo apt-get install -y vim
        echo "  ✓ Installed vim"
    else
        echo "  ✓ vim already installed"
    fi
}

# Used by post-create.sh itself (DB init/seed) and available to both users
# at runtime.
_setup_tools_sqlite3() {
    if ! command -v sqlite3 &>/dev/null; then
        sudo apt-get update && sudo apt-get install -y sqlite3
        echo "  ✓ Installed sqlite3"
    else
        echo "  ✓ sqlite3 already available"
    fi
}

# Installs GitHub's `gh` CLI as a portable, no-root binary for claudeme (used
# by the open-pr skill to actually create PRs). No devcontainer feature for
# gh works without root here, so this follows the same unprivileged-binary
# pattern as run-phpcalculator's setup-chrome-deps.sh: fetch the plain Linux
# tarball from GitHub's releases and drop the binary in ~/.local/bin, which
# claudeme's ~/.profile already conditionally adds to PATH (a stock Debian
# skel default: `if [ -d "$HOME/.local/bin" ]; then PATH=...`).
#
# Only installs the binary - `gh auth login` is interactive and must be run
# by a human; this script never touches auth, and auth doesn't persist
# across rebuilds either (~/.config/gh isn't on the claude-cli volume).
_setup_tools_gh() {
    local user="claudeme"
    local home="/home/$user"
    local bin_dir="$home/.local/bin"

    if [ -x "$bin_dir/gh" ]; then
        echo "  ✓ gh already installed for $user ($("$bin_dir/gh" --version | head -1))"
        return
    fi

    local latest_tag
    latest_tag="$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest \
        | grep -m1 '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')"
    if [ -z "$latest_tag" ]; then
        echo "  ✗ Could not determine latest gh release (network issue?), skipping"
        return
    fi

    local version="${latest_tag#v}"
    local url="https://github.com/cli/cli/releases/download/${latest_tag}/gh_${version}_linux_amd64.tar.gz"

    local tmp
    tmp="$(mktemp -d)"
    if ! curl -fsSL "$url" -o "$tmp/gh.tar.gz"; then
        echo "  ✗ Failed to download gh ${latest_tag}, skipping"
        rm -rf "$tmp"
        return
    fi
    tar -xzf "$tmp/gh.tar.gz" -C "$tmp"

    sudo -u "$user" mkdir -p "$bin_dir"
    sudo -u "$user" cp "$tmp/gh_${version}_linux_amd64/bin/gh" "$bin_dir/gh"
    sudo -u "$user" chmod +x "$bin_dir/gh"
    rm -rf "$tmp"

    echo "  ✓ Installed gh ${latest_tag} to $bin_dir for $user (run 'gh auth login' to authenticate)"
}
