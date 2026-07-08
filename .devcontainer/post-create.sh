#!/bin/bash
set -e

echo "=================================="
echo " Post-creation setup starting..."
echo "=================================="

# -- Permissions changed --
echo "[1/6] Ensuring mounted folders have correct permissons..."
if [ ! -w "/home/vscode/.claude" ]; then
    sudo chown -R vscode:vscode /home/vscode/.claude
    echo "  ✓ Permissions fixed"
else
    echo "  ✓ Permissions are correct"
fi

# -- PHP dependencies --
echo "[2/6] Installing PHP dependencies (composer)..."
if [ -f backend/composer.json ]; then
    (cd backend && composer install --no-interaction --prefer-dist)
    echo "  ✓ composer install complete"
else
    echo "  ✗ backend/composer.json not found, skipping"
fi

# -- Frontend dependencies --
echo "[3/6] Installing frontend dependencies (npm)..."
if [ -f frontend/package.json ]; then
    cd frontend
    npm install
    cd ..
    echo "  ✓ npm install complete"
else
    echo "  ✗ frontend/package.json not found, skipping"
fi

# -- SQLite3 --
echo "[4/6] Ensuring sqlite3 is installed..."
if ! command -v sqlite3 &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y sqlite3
    echo "  ✓ sqlite3 installed"
else
    echo "  ✓ sqlite3 already available"
fi

# -- Database initialization --
echo "[5/6] Initializing SQLite database..."
if [ -f backend/database/init.sql ]; then
    sqlite3 backend/database.sqlite < backend/database/init.sql
    echo "  ✓ database schema created"
else
    echo "  ✗ backend/database/init.sql not found, skipping"
fi

echo "[6/6] Loading seed data..."
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