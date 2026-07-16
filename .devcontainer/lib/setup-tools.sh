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

# Installs GitHub's `gh` CLI as a portable, no-root binary. claudeme is the
# sole real owner of gh auth in this devcontainer — vscode gets a thin
# wrapper at ~/.local/bin/gh instead of its own binary (see
# _setup_tools_gh_install_wrapper_for_vscode) that re-execs into
# `sudo -u claudeme gh "$@"`, which vscode can already do passwordless (the
# same NOPASSWD rule the "Claude" terminal profile uses — see
# setup-claude-cli.sh). This makes claudeme the single real owner of
# ~/.config/gh, which matters because gh rewrites its credential files to
# mode 600 on almost every invocation, not just `gh auth login` — a
# genuinely shared/symlinked config (tried first) broke every time either
# identity touched gh, since ownership kept flipping between two different
# real OS users. With only one real owner, that's simply never a problem.
#
# Caveats: GH_TOKEN/other GH_* env vars set in a vscode shell won't reach
# the proxied call (sudo resets the environment by default, and this
# deliberately doesn't opt back in via -E since that would also leak
# vscode's PATH etc. into claudeme). And any git push gh triggers (e.g.
# `gh pr create`) now runs as claudeme even when invoked from a vscode
# shell — depends on claudeme's git credential helper actually working,
# which is a *separate*, pre-existing rough edge (claudeme's ~/.gitconfig
# is a stale one-time copy of vscode's — see CLAUDEME.md).
#
# No devcontainer feature for gh works without root here, so installing the
# real binary follows the same unprivileged-binary pattern as
# run-phpcalculator's setup-chrome-deps.sh: fetch the plain Linux tarball
# from GitHub's releases and drop it in claudeme's ~/.local/bin, which its
# ~/.profile already conditionally adds to PATH (a stock Debian skel
# default: `if [ -d "$HOME/.local/bin" ]; then PATH=...`).
_setup_tools_gh() {
    local user="claudeme"
    local home="/home/$user"
    local bin_dir="$home/.local/bin"

    # claudeme's ~/.config/gh volume mounts root-owned on creation (same
    # quirk as the claude-vscode/claude-cli volumes) — fix it every run.
    sudo mkdir -p "$home/.config/gh"
    sudo chown -R "$user:$user" "$home/.config/gh"

    _setup_tools_gh_install_wrapper_for_vscode

    if [ -x "$bin_dir/gh" ]; then
        echo "  ✓ gh already installed for $user ($("$bin_dir/gh" --version | head -1))"
        return
    fi

    local latest_tag
    latest_tag="$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest \
        | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')"
    if [ -z "$latest_tag" ]; then
        echo "  ✗ Could not determine latest gh release (network issue?), skipping"
        return
    fi

    local version="${latest_tag#v}"
    local url="https://github.com/cli/cli/releases/download/${latest_tag}/gh_${version}_linux_amd64.tar.gz"

    local tmp
    tmp="$(mktemp -d)"
    # mktemp -d defaults to mode 700 owned by whoever runs this script
    # (vscode, per devcontainer.json's remoteUser) — without this, the
    # sudo -u claudeme cp/tar access below fails with "Permission denied"
    # because claudeme can't even traverse into the directory.
    chmod 755 "$tmp"
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

    echo "  ✓ Installed gh ${latest_tag} to $bin_dir for $user (run 'gh auth login' as claudeme to authenticate — vscode proxies to it automatically)"
}

# vscode's `gh` is a wrapper, not a real binary: re-execs into claudeme via
# passwordless sudo (see _setup_tools_gh above for why). Regenerated every
# run — cheap, no network needed — rather than installed once, so edits to
# the wrapper itself always take effect on the next rebuild.
_setup_tools_gh_install_wrapper_for_vscode() {
    local vscode_bin="/home/vscode/.local/bin"
    mkdir -p "$vscode_bin"
    cat > "$vscode_bin/gh" <<'WRAPPER'
#!/bin/bash
exec sudo -H -u claudeme /home/claudeme/.local/bin/gh "$@"
WRAPPER
    chmod +x "$vscode_bin/gh"
    echo "  ✓ vscode's gh proxies to claudeme (sudo -u claudeme, passwordless)"
}
