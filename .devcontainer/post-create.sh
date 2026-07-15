#!/bin/bash
set -e

echo "=================================="
echo " Post-creation setup starting..."
echo "=================================="

DIR="$(dirname "${BASH_SOURCE[0]}")"
WORKSPACE_DIR="$(pwd)"

# -- VS Code extension's Claude account --
echo "[1/8] Setting up VS Code extension's Claude account (vscode user)..."
source "$DIR/lib/setup-claude-vscode.sh"
setup_claude_vscode

# -- Isolated claudeme user for Claude CLI sessions --
echo "[2/8] Setting up isolated claudeme user for Claude CLI sessions..."
source "$DIR/lib/setup-claude-cli.sh"
setup_claude_cli "$WORKSPACE_DIR"

# -- gh CLI for claudeme (used by the open-pr skill) --
echo "[3/8] Installing gh CLI for claudeme..."
source "$DIR/lib/setup-gh-cli.sh"
setup_gh_cli

# -- PHP dependencies --
echo "[4/8] Installing PHP dependencies (composer)..."
if [ -f backend/composer.json ]; then
    (cd backend && composer install --no-interaction --prefer-dist)
    echo "  ✓ composer install complete"
else
    echo "  ✗ backend/composer.json not found, skipping"
fi

# -- Frontend dependencies --
echo "[5/8] Installing frontend dependencies (npm)..."
if [ -f frontend/package.json ]; then
    cd frontend
    npm install
    cd ..
    echo "  ✓ npm install complete"
else
    echo "  ✗ frontend/package.json not found, skipping"
fi

# -- SQLite3 --
echo "[6/8] Ensuring sqlite3 is installed..."
if ! command -v sqlite3 &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y sqlite3
    echo "  ✓ sqlite3 installed"
else
    echo "  ✓ sqlite3 already available"
fi

# -- Database initialization --
echo "[7/8] Initializing SQLite database..."
if [ -f backend/database/init.sql ]; then
    sqlite3 backend/database.sqlite < backend/database/init.sql
    echo "  ✓ database schema created"
else
    echo "  ✗ backend/database/init.sql not found, skipping"
fi

# -- Seeding of database --
echo "[8/8] Loading seed data..."
if [ -f backend/database/seed.sql ]; then
    sqlite3 backend/database.sqlite < backend/database/seed.sql
    echo "  ✓ seed data loaded"
else
    echo "  ✗ backend/database/seed.sql not found, skipping"
fi

echo ""
echo "=================================="
echo " Setup complete!                "
echo "=================================="
echo ""
echo "Commands you can run:"
echo "  cd backend && composer test        - Run PHPUnit tests"
echo "  cd frontend && npm run dev - Start Vite dev server"
echo "  cd backend && php -S 0.0.0.0:8000 src/api.php  - Start PHP built-in server"
echo ""
