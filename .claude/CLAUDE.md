# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Smart Plan Mortgage Calculator — a PHP + React + SQLite app that validates mortgage applications server-side and stores them. There is no framework on either side: the backend is a single-file router over raw PDO/SQLite, and the frontend is a single-component Vite/React app. The backend lives entirely under `backend/` (PHP source, tests, composer files, phpunit config, database SQL/data, `.env`); the frontend lives under `frontend/`.

## Commands

### Backend (PHP)
All backend commands run from the `backend/` directory.
```bash
cd backend
composer install                # install dependencies
composer test                   # run PHPUnit tests (same as vendor/bin/phpunit)
vendor/bin/phpunit --filter testCalculateMonthlyPayment   # run a single test
php -S 0.0.0.0:8000 src/api.php # start the API on :8000
```

### Frontend
```bash
cd frontend
npm install
npm run dev       # Vite dev server on :5173, proxies /api/* to localhost:8000
npm run lint      # eslint
npm run build     # tsc -b && vite build
```
There are no frontend tests currently configured (no vitest/jest in package.json).

### Database
SQLite, local-only file (`backend/database.sqlite`, gitignored).
```bash
cd backend
sqlite3 database.sqlite < database/init.sql   # schema (idempotent, IF NOT EXISTS)
sqlite3 database.sqlite < database/seed.sql   # sample areas/promos/payment_methods
```
To reset: delete `backend/database.sqlite` and re-run both files. There is no migration system — `init.sql` is the entire schema.

### Running everything
Backend and frontend are two separate processes; run both in parallel terminals when testing end-to-end (see commands above). The Vite dev server proxies API calls, so the frontend must be hit at `:5173`, not `:8000`.

## Architecture

### Split validation logic — keep both sides in sync
The mortgage price/monthly-payment math is implemented **twice**: once in `backend/src/MortgageValidator.php` (authoritative, server-side) and once inline in `frontend/src/App.tsx` (`calculatePrice`, `calculateMonthlyPaymentValue`, for live UI preview). The frontend calculates a preview; the backend independently recalculates and rejects the request if the client's numbers don't match within tolerance (`MortgageValidator::PRICE_TOLERANCE`, `MONTHLY_PAYMENT_TOLERANCE`). This is a deliberate anti-tampering check — a client cannot submit a discounted price or payment it didn't actually qualify for. **If you change the pricing/annuity formula in one place, change it in the other**, and update `backend/tests/MortgageValidatorTest.php` accordingly.

### Backend request flow (`backend/src/api.php`)
Everything lives in one file: env loading (simple `.env` parser, no library), CORS headers, PDO/SQLite connection, and a router built from `strpos()` checks on the request path (not a real router — order and substring matches matter, e.g. `api/requests` will also match longer paths containing that substring).

For `POST /api/integrations/sendForm`:
1. Required-field presence check
2. Per-field numeric range/type validation (`$numericFields` config array in `api.php`)
3. Look up `area`, `promo` (nullable — falls back to the area's own `promo_id` if the request didn't specify one), and `payment_method` by ID from the DB
4. Delegate to `MortgageValidator::validate()`, which throws on mismatch
5. On success, insert into `requests` (note: `initial_payment` stored in the DB is `initial_payment + maternal_capital` combined — the split is not preserved)

There's no centralized error handling — every failure path does its own `http_response_code()` + `json_encode()` + `exit()`.

### Frontend (`frontend/src/App.tsx`)
Single ~430-line component holding all state, all three domain interfaces (`Area`, `Promo`, `PaymentMethod`, `RequestEntity`), and both calculator tabs (Calculator / Requests History) via `activeTab` state — no router, no separate components. Initial data (areas, promos, payment methods, requests) is fetched once in a single `useEffect` on mount.

### Database schema (`backend/database/init.sql`)
Four tables: `promos` (percentage or fixed-`rub` discount), `areas` (plots, each optionally tied to a promo), `payment_methods` (bank + rate), `requests` (submitted applications, FKs to the other three). No indexes beyond primary keys.

## Known gaps / backlog
`tasks/01-improvement-tasks.md` contains a prioritized list of 20 not-yet-implemented improvements (input validation hardening, splitting `App.tsx`, frontend tests, error-handling middleware, migrations, rate limiting, PHPStan, pagination, etc.). Check it before proposing large structural changes — the desired direction may already be scoped out there.