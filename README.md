# Smart Plan Mortgage Calculator

PHP + React + SQLite mortgage application validator with REST API.

## 🚀 Quick Start (DevContainer - Recommended)

This project includes a **fully automated DevContainer** for VS Code.

```bash
git clone <repo-url>
cd phpcalculator
code .
# Click: "Reopen in Container" (Cmd+Shift+P → Dev Containers: Reopen in Container)
```

The container automatically:
- ✅ Installs PHP 8.3 + Composer dependencies (`composer install`)
- ✅ Installs Node.js + frontend dependencies (`npm install`)
- ✅ Creates SQLite database with schema
- ✅ Loads seed data

## 🛠️ Manual Setup (Without DevContainer)

```bash
# 1. Prerequisites: PHP 8.3+, Node.js 20+, Composer, SQLite3

# 2. Install PHP dependencies
composer install

# 3. Install frontend dependencies
cd frontend && npm install && cd ..

# 4. Initialize database
sqlite3 database.sqlite < database/init.sql
sqlite3 database.sqlite < database/seed.sql
```

## 🏃 Running the Application

Start both servers in separate terminals:

### Terminal 1 — PHP Backend (API)
```bash
php -S 0.0.0.0:8080 -t src
```

### Terminal 2 — React Frontend (Vite dev server)
```bash
cd frontend
npm run dev
```

Open http://localhost:5173 in your browser.

## 🧪 Running Tests

```bash
# PHPUnit tests
composer test

# Or directly:
vendor/bin/phpunit
```

```bash
# Frontend lint
cd frontend && npm run lint
```

## 🗄️ Database

The SQLite database (`database.sqlite`) is **local** and not tracked in git.

| File | Purpose |
|------|---------|
| `database/init.sql` | Schema creation (run once) |
| `database/seed.sql` | Sample data (areas, promos, payment methods) |

To reset: delete `database.sqlite` and re-run both SQL files.

## 📁 Project Structure

```
.
├── .devcontainer/          # VS Code DevContainer configuration
│   ├── devcontainer.json   # Container definition (PHP 8.3, Node.js)
│   ├── post-create.sh      # Auto-setup script (runs on container create)
│   ├── devcontainer-lock.json
│   └── xdebug.ini
├── .github/workflows/      # CI/CD pipeline (GitHub Actions)
│   └── ci.yml             # PHP tests + Frontend lint/build + DB check
├── database/               # SQL schema and seed data
│   ├── init.sql
│   └── seed.sql
├── frontend/               # React + TypeScript + Vite
│   ├── src/
│   ├── .gitignore
│   ├── package.json
│   └── vite.config.ts
├── src/                    # PHP backend
│   ├── api.php             # REST API endpoints
│   └── MortgageValidator.php
├── tests/                  # PHPUnit tests
│   └── MortgageValidatorTest.php
├── composer.json
├── phpunit.xml
└── .gitignore
```

## 🔄 CI/CD Pipeline

On every push/PR to `main`/`master`/`develop`, GitHub Actions runs:

| Job | What it checks |
|-----|---------------|
| **PHP Tests** | `vendor/bin/phpunit` — validates mortgage validation logic |
| **Frontend** | `npm run lint` + `npm run build` — code quality + compilation |
| **Database** | Schema creation + seed data loading — ensures DB scripts work |

## 🐳 DevContainer Details

- **Base image**: `mcr.microsoft.com/devcontainers/php:8.3`
- **PHP**: 8.3 with Xdebug
- **Node.js**: 20 (via devcontainer feature)
- **Extensions**: PHP Debug, Claude Code, Claude Dev