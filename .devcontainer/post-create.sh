#!/bin/bash
set -e

echo "=================================="
echo " Post-creation setup starting..."
echo "=================================="

# -- Permissions changed --
echo "[1/7] Ensuring mounted folders have correct permissons..."
if [ ! -w "/home/vscode/.claude" ]; then
    sudo chown -R vscode:vscode /home/vscode/.claude
    echo "  ✓ Permissions fixed"
else
    echo "  ✓ Permissions are correct"
fi

# -- Persist ~/.claude.json across rebuilds --
echo "[2/7] Persisting ~/.claude.json across rebuilds..."
source "$(dirname "${BASH_SOURCE[0]}")/persist-claude-json.sh"
persist_claude_json

# -- PHP dependencies --
echo "[3/7] Installing PHP dependencies (composer)..."
if [ -f composer.json ]; then
    composer install --no-interaction --prefer-dist
    echo "  ✓ composer install complete"
else
    echo "  ✗ composer.json not found, skipping"
fi

# -- Frontend dependencies --
echo "[4/7] Installing frontend dependencies (npm)..."
if [ -f frontend/package.json ]; then
    cd frontend
    npm install
    cd ..
    echo "  ✓ npm install complete"
else
    echo "  ✗ frontend/package.json not found, skipping"
fi

# -- SQLite3 --
echo "[5/7] Ensuring sqlite3 is installed..."
if ! command -v sqlite3 &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y sqlite3
    echo "  ✓ sqlite3 installed"
else
    echo "  ✓ sqlite3 already available"
fi

# -- Database initialization --
echo "[6/7] Initializing SQLite database..."
if [ -f database/init.sql ]; then
    sqlite3 database.sqlite < database/init.sql
    echo "  ✓ database schema created"
else
    echo "  ✗ database/init.sql not found, skipping"
fi

echo "[7/7] Loading seed data..."
if [ -f database/seed.sql ]; then
    sqlite3 database.sqlite < database/seed.sql
    echo "  ✓ seed data loaded"
else
    echo "  ✗ database/seed.sql not found, skipping"
fi

echo ""
echo "=================================="
echo " Setup complete!                "
echo "=================================="
echo ""
echo "Commands you can run:"
echo "  composer test        - Run PHPUnit tests"
echo "  cd frontend && npm run dev - Start Vite dev server"
echo "  php -S 0.0.0.0:8000 src/api.php  - Start PHP built-in server"
echo ""