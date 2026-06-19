#!/bin/bash
set -e

echo "=================================="
echo " Post-creation setup starting..."
echo "=================================="

# -- SQLite3 --
echo "[1/5] Ensuring sqlite3 is installed..."
if ! command -v sqlite3 &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y sqlite3
    echo "  ✓ sqlite3 installed"
else
    echo "  ✓ sqlite3 already available"
fi

# -- PHP dependencies --
echo "[2/5] Installing PHP dependencies (composer)..."
if [ -f composer.json ]; then
    composer install --no-interaction --prefer-dist
    echo "  ✓ composer install complete"
else
    echo "  ✗ composer.json not found, skipping"
fi

# -- Frontend dependencies --
echo "[3/5] Installing frontend dependencies (npm)..."
if [ -f frontend/package.json ]; then
    cd frontend
    npm install
    cd ..
    echo "  ✓ npm install complete"
else
    echo "  ✗ frontend/package.json not found, skipping"
fi

# -- Database initialization --
echo "[4/5] Initializing SQLite database..."
if [ -f database/init.sql ]; then
    sqlite3 database.sqlite < database/init.sql
    echo "  ✓ database schema created"
else
    echo "  ✗ database/init.sql not found, skipping"
fi

# -- Seed data --
echo "[5/5] Loading seed data..."
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