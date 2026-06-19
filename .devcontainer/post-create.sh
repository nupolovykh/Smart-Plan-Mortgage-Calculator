#!/bin/bash
set -e

echo "=================================="
echo " Post-creation setup starting..."
echo "=================================="

# -- PHP dependencies --
echo "[1/4] Installing PHP dependencies (composer)..."
if [ -f composer.json ]; then
    composer install --no-interaction --prefer-dist
    echo "  ✓ composer install complete"
else
    echo "  ✗ composer.json not found, skipping"
fi

# -- Frontend dependencies --
echo "[2/4] Installing frontend dependencies (npm)..."
if [ -f frontend/package.json ]; then
    cd frontend
    npm install
    cd ..
    echo "  ✓ npm install complete"
else
    echo "  ✗ frontend/package.json not found, skipping"
fi

# -- Database initialization --
echo "[3/4] Initializing SQLite database..."
if [ -f database/init.sql ]; then
    sqlite3 database.sqlite < database/init.sql
    echo "  ✓ database schema created"
else
    echo "  ✗ database/init.sql not found, skipping"
fi

# -- Seed data --
echo "[4/4] Loading seed data..."
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
echo "  php -S 0.0.0.0:8080 -t src  - Start PHP built-in server"
echo ""