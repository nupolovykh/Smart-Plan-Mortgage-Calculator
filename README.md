# Smart Plan Mortgage Calculator

PHP + React + SQLite mortgage application validator with REST API.

## 🚀 Quick Start (DevContainer - Recommended)

This project includes a **fully automated DevContainer** for VS Code.

```bash
git clone https://github.com/nupolovykh/Smart-Plan-Mortgage-Calculator.git
cd Smart-Plan-Mortgage-Calculator
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
cd backend && composer install && cd ..

# 3. Install frontend dependencies
cd frontend && npm install && cd ..

# 4. Initialize database
cd backend
sqlite3 database.sqlite < database/init.sql
sqlite3 database.sqlite < database/seed.sql
cd ..
```

## 🏃 Running the Application

Start both servers in separate terminals:

### Terminal 1 — PHP Backend (API)
```bash
cd backend
php -S 0.0.0.0:8000 src/api.php
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
cd backend
composer test

# Or directly:
vendor/bin/phpunit
```

```bash
# Frontend lint
cd frontend && npm run lint
```

## 🗄️ Database

The SQLite database (`backend/database.sqlite`) is **local** and not tracked in git.

| File | Purpose |
|------|---------|
| `backend/database/init.sql` | Schema creation (run once) |
| `backend/database/seed.sql` | Sample data (areas, promos, payment methods) |

To reset: delete `backend/database.sqlite` and re-run both SQL files.

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
├── backend/                # PHP backend
│   ├── src/
│   │   ├── api.php         # REST API endpoints
│   │   └── MortgageValidator.php
│   ├── tests/              # PHPUnit tests
│   │   └── MortgageValidatorTest.php
│   ├── database/           # SQL schema and seed data
│   │   ├── init.sql
│   │   └── seed.sql
│   ├── composer.json
│   ├── phpunit.xml
│   └── .env.example
├── frontend/               # React + TypeScript + Vite
│   ├── src/
│   ├── .gitignore
│   ├── package.json
│   └── vite.config.ts
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