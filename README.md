# Smart Plan Mortgage Calculator

A mortgage calculator application with PHP backend and React frontend.

## Project Structure

```
.
├── composer.json          # PHP dependencies
├── composer.lock          # Locked PHP dependency versions
├── database/
│   ├── init.sql           # Database schema initialization
│   └── seed.sql           # Sample seed data
├── src/
│   ├── api.php            # PHP API entry point
│   └── MortgageValidator.php
├── tests/
│   └── MortgageValidatorTest.php
└── frontend/              # React + Vite + TypeScript frontend
    ├── package.json
    └── ...
```

## Getting Started After Cloning

### 1. Set up the database

```bash
sqlite3 database.sqlite < database/init.sql
sqlite3 database.sqlite < database/seed.sql
```

### 2. Install PHP dependencies

```bash
composer install
```

### 3. Install frontend dependencies

```bash
cd frontend && npm install
```

### 4. Start the PHP backend

```bash
php -S 0.0.0.0:8080 -t src/
```

### 5. Start the frontend dev server (in another terminal)

```bash
cd frontend && npm run dev