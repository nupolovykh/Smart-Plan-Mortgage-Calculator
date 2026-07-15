#!/bin/bash
set -e  # abort on first error

# Run CLI-only Claude Code sessions as a separate OS user ("claudeme").
# Reason: the VS Code extension and a `claude` CLI process running as the
# same user share ~/.claude/projects/<dir-hash>/ session storage, so a
# background CLI session can collide with the extension trying to
# resume/lock the same session. A separate user means a separate $HOME
# (and ~/.claude), so there's nothing to collide over.
setup_claude_cli() {
    local user="claudeme"
    local home="/home/$user"
    local workspace="${1:?setup_claude_cli requires the workspace folder path as \$1}"

    # Create the isolated user, in the vscode group so it can share the workspace
    if id "$user" &>/dev/null; then
        echo "  ✓ User $user already exists"
    else
        sudo useradd -m -s /bin/bash -G vscode "$user"
        echo "  ✓ Created user $user (home + vscode group membership)"
    fi

    # Docker pre-creates $home as root (to have a mount point for the claude-cli
    # volume) before useradd runs, so useradd -m leaves ownership untouched —
    # fix it or claudeme can't write to its own $HOME.
    if [ "$(stat -c %U "$home")" != "$user" ]; then
        sudo chown "$user:$user" "$home"
        echo "  ✓ Fixed ownership of $home"
    fi

    # Same pre-existing-$home quirk makes useradd skip the /etc/skel copy
    # entirely, so claudeme has no ~/.profile. Without it, `sudo -u claudeme -i`
    # (a login shell) never sources ~/.bashrc (only ~/.profile does that).
    if [ ! -f "$home/.profile" ] && [ -f /etc/skel/.profile ]; then
        sudo cp /etc/skel/.profile "$home/.profile"
        sudo chown "$user:$user" "$home/.profile"
        echo "  ✓ Seeded ~/.profile from /etc/skel (chains into ~/.bashrc)"
    fi

    # vscode's passwordless sudo only covers becoming root, not arbitrary users —
    # grant it permission to switch into claudeme without a password prompt.
    local sudoers_file="/etc/sudoers.d/claudeme"
    if [ ! -f "$sudoers_file" ]; then
        echo "vscode ALL=($user) NOPASSWD: ALL" | sudo tee "$sudoers_file" >/dev/null
        sudo chmod 440 "$sudoers_file"
        sudo visudo -cf "$sudoers_file" >/dev/null
        echo "  ✓ Allowed vscode to switch to $user without a password"
    else
        echo "  ✓ Sudoers rule already present"
    fi

    # Share the workspace with claudeme via the common "vscode" group, and set
    # setgid on directories so new files/dirs created by either user keep that group.
    sudo chgrp -R vscode "$workspace" || true
    sudo chmod -R g+rwX "$workspace"
    sudo find "$workspace" -type d -exec chmod g+s {} +
    # The workspace root is the bind-mount point itself; Docker won't let us
    # chgrp it even as root, so open up "other" write there specifically so
    # claudeme can traverse/create top-level entries.
    if [ "$(stat -c %G "$workspace")" != "vscode" ]; then
        sudo chmod o+rwx "$workspace"
    fi
    echo "  ✓ Workspace shared with $user via the vscode group"

    # setgid only fixes the group of new files, not the write bit — force
    # umask 002 so both users can still edit each other's files.
    if ! grep -q "^umask 002" /etc/bash.bashrc; then
        echo "umask 002" | sudo tee -a /etc/bash.bashrc >/dev/null
        echo "  ✓ Set shared umask 002 for interactive shells"
    else
        echo "  ✓ Shared umask already configured"
    fi

    # claude-cli volume mounts at $home/.claude root-owned (like the vscode
    # volume) — fix ownership, then pre-complete onboarding in the sibling
    # .claude.json (not covered by the volume, so it never survives a rebuild)
    # so `claude` doesn't block on the first-run wizard. claudeme authenticates
    # via CLAUDE_CODE_OAUTH_TOKEN below, not an interactive login.
    sudo mkdir -p "$home/.claude"
    sudo chown -R "$user:$user" "$home/.claude"
    if [ ! -f "$home/.claude.json" ]; then
        echo '{"hasCompletedOnboarding": true}' | sudo tee "$home/.claude.json" >/dev/null
        sudo chown "$user:$user" "$home/.claude.json"
        echo "  ✓ Seeded $home/.claude.json (onboarding pre-completed)"
    else
        echo "  ✓ $home/.claude.json already present"
    fi

    # Same skel-skip fallout as above: claudeme's ~/.bashrc starts empty, missing
    # the themed prompt vscode's has — seed it from vscode's so the claudeme
    # terminal isn't visually bare. Guarded on the theme's marker function so
    # this only seeds once and never clobbers later edits.
    if ! sudo grep -q '__bash_prompt' "$home/.bashrc" 2>/dev/null; then
        local reference_bashrc="/home/vscode/.bashrc"
        [ -f "$reference_bashrc" ] || reference_bashrc="/etc/skel/.bashrc"
        sudo cp "$reference_bashrc" "$home/.bashrc"
        sudo chown "$user:$user" "$home/.bashrc"
        echo "  ✓ Seeded ~/.bashrc from vscode's themed shell config"
    fi

    # The seed above copies vscode's ~/.bashrc verbatim, which includes
    # setup_claude_vscode's `claude` ban (added first, on the same boot).
    # That ban is only meant for vscode; claudeme is the one place `claude`
    # must run, so strip the block back out every time this runs.
    local vscode_ban_start="# >>> claude-cli-ban >>>"
    local vscode_ban_end="# <<< claude-cli-ban <<<"
    if sudo grep -qF "$vscode_ban_start" "$home/.bashrc" 2>/dev/null; then
        sudo sed -i \
            -e "/^${vscode_ban_start//\//\\/}\$/,/^${vscode_ban_end//\//\\/}\$/d" \
            "$home/.bashrc"
        echo "  ✓ Removed vscode's claude-cli ban from claudeme's ~/.bashrc"
    fi

    # claudeme has no ~/.gitconfig (not seeded by skel or anything else), so a
    # commit would fail identity checks and a push would have no credential
    # helper. Seed it from vscode's, which Dev Containers already populated
    # with both. Guarded on existence so reruns never clobber later edits; if
    # vscode's own .gitconfig isn't there yet, this just retries next rebuild.
    if [ ! -f "$home/.gitconfig" ] && [ -f /home/vscode/.gitconfig ]; then
        sudo cp /home/vscode/.gitconfig "$home/.gitconfig"
        sudo chown "$user:$user" "$home/.gitconfig"
        echo "  ✓ Seeded ~/.gitconfig from vscode's git identity/credentials"
    fi

    # git refuses to operate on a repo owned by a different user ("detected
    # dubious ownership") — the workspace is owned by vscode (uid 1000), not
    # claudeme (uid 1001), since it's shared via the vscode group rather than
    # a separate clone. Checked first so reruns don't pile up duplicate entries.
    if ! sudo -u "$user" env HOME="$home" git config --global --get-all safe.directory 2>/dev/null \
        | grep -qxF "$workspace"; then
        sudo -u "$user" env HOME="$home" git config --global --add safe.directory "$workspace"
        echo "  ✓ Marked $workspace safe.directory for $user"
    else
        echo "  ✓ $workspace already marked safe.directory for $user"
    fi

    # containerEnv lives on the container process but isn't guaranteed to
    # reach a `sudo -u claudeme` shell. /etc/environment doesn't work here
    # (PAM stack never reads it), so inject via claudeme's own ~/.profile
    # instead — read on every login shell, and (unlike ~/.bashrc, which bails
    # out early for non-interactive shells) has no interactive-only guard.
    # Regenerated every run so it stays current if the token changes; markers
    # keep it idempotent.
    #
    # Arrives as CLAUDE_CODE_HOST_TOKEN, not CLAUDE_CODE_OAUTH_TOKEN — kept off
    # containerEnv's real name so it can't reach vscode's extension host and
    # force it into inference-only mode. Translated back here only.
    local marker_start="# >>> claude-cli env >>>"
    local marker_end="# <<< claude-cli env <<<"

    sudo sed -i \
        -e "/^${marker_start//\//\\/}\$/,/^${marker_end//\//\\/}\$/d" \
        "$home/.profile"

    {
        echo "$marker_start"
        if [ -n "${CLAUDE_CODE_HOST_TOKEN:-}" ]; then
            echo "export CLAUDE_CODE_OAUTH_TOKEN='${CLAUDE_CODE_HOST_TOKEN}'"
        fi
        if [ -n "${DISABLE_AUTOUPDATER:-}" ]; then
            echo "export DISABLE_AUTOUPDATER='${DISABLE_AUTOUPDATER}'"
        fi
        echo "cd '$workspace'"
        echo "$marker_end"
    } | sudo tee -a "$home/.profile" >/dev/null
    echo "  ✓ Refreshed claudeme's ~/.profile (env vars + start in project dir)"
}
