# Smart Plan Mortgage Calculator — Improvement Tasks

This file contains a prioritized sequence of improvement tasks for the project. Each task is self-contained and ordered for efficient AI-model processing (most impactful first, dependencies respected).

---

## Task 1: Add Input Validation & Sanitization to API

**Priority:** HIGH  
**Category:** Security  
**Files affected:** `backend/src/api.php`

### Problem
The API endpoint `api/integrations/sendForm` does not validate types or sanitize inputs before processing. Missing field checks exist but no type validation (e.g., `mortgage_term` could be a string, `price` could be negative). SQL queries use prepared statements (good), but numeric fields are not validated for range/sanity.

### Implementation
1. Add numeric range validation for all numeric fields:
   - `price` > 0
   - `mortgage_term` between 1 and 50
   - `initial_payment` >= 0
   - `maternal_capital` >= 0
   - `monthly_payment` > 0
   - `payment_method_id` > 0
   - `realty_id` > 0
2. Validate `promo_id` is either null or positive integer
3. Return 400 with descriptive error for each validation failure
4. Strip whitespace from string fields if any are added in future

### Acceptance Criteria
- Sending negative price returns 400 error
- Sending string for mortgage_term returns 400 error
- Sending zero or negative IDs returns 400 error
- Valid data still passes through successfully

---

## Task 2: Add TypeScript Types File & Extract Shared Logic

**Priority:** HIGH  
**Category:** Code Quality / Maintainability  
**Files affected:** `frontend/src/App.tsx` → create `frontend/src/types.ts`, `frontend/src/utils.ts`

### Problem
All TypeScript interfaces (`Area`, `Promo`, `PaymentMethod`, `RequestEntity`) and calculation logic (`calculatePrice`, `calculateMonthlyPaymentValue`) are defined inside `App.tsx`. This makes the component bloated (432 lines), prevents reuse, and makes testing harder.

### Implementation
1. Create `frontend/src/types.ts` with all interfaces exported
2. Create `frontend/src/utils.ts` with:
   - `calculatePrice(area, promos)` — pure function
   - `calculateMonthlyPayment(price, initialPayment, maternalCapital, term, paymentMethod)` — pure function
3. Import types and utils in `App.tsx`
4. Remove inline interfaces and functions from `App.tsx`

### Acceptance Criteria
- App compiles and runs without errors
- All calculation logic is in `utils.ts`
- All interfaces are in `types.ts`
- App.tsx is reduced in size

---

## Task 3: Add Frontend Unit Tests (Vitest)

**Priority:** HIGH  
**Category:** Testing  
**Files affected:** Create `frontend/src/__tests__/utils.test.ts`, modify `frontend/package.json`

### Problem
The frontend has zero tests. The calculation logic (`calculatePrice`, `calculateMonthlyPaymentValue`) is critical business logic that should be tested independently. The PHP backend has tests, but the frontend does not.

### Implementation
1. Install vitest: `npm install -D vitest @testing-library/react @testing-library/jest-dom jsdom`
2. Add test script to `package.json`: `"test": "vitest run"`
3. Create `frontend/src/__tests__/utils.test.ts` with tests for:
   - `calculatePrice` with percentage promo
   - `calculatePrice` with rub promo
   - `calculatePrice` with no promo
   - `calculatePrice` with promo that doesn't exist
   - `calculateMonthlyPayment` with standard rate
   - `calculateMonthlyPayment` with zero rate
   - `calculateMonthlyPayment` with loan amount <= 0
4. Configure vitest in `vite.config.ts`

### Acceptance Criteria
- `npm test` passes with at least 7 test cases
- Tests cover edge cases (zero rate, no promo, negative loan)
- Tests are meaningful (not just trivial assertions)

---

## Task 4: Add API Error Handling Middleware & Structured Responses

**Priority:** HIGH  
**Category:** Architecture / Reliability  
**Files affected:** `backend/src/api.php`

### Problem
The API has no centralized error handling. Database connection failures, JSON parse errors, and missing endpoints all use inline `http_response_code()` + `exit()` pattern. Error responses are inconsistent (some have `status` field, some don't). No logging exists.

### Implementation
1. Create a `sendJsonResponse($data, $statusCode)` helper function
2. Create a `sendError($message, $statusCode)` helper function
3. Wrap the entire request handling in a try-catch block
4. Log errors to a file or `error_log()` for debugging
5. Ensure all responses follow consistent format: `{"status": "success|error", "message": "...", "data": ...}`
6. Handle 404 routes with consistent response

### Acceptance Criteria
- All API responses follow the same JSON structure
- Unhandled exceptions return 500 with generic message (details logged server-side)
- No `exit()` calls scattered throughout the code (use single exit point)

---

## Task 5: Add Database Migrations System

**Priority:** MEDIUM  
**Category:** Developer Experience / Maintainability  
**Files affected:** Create `backend/database/migrations/` directory, modify `backend/database/init.sql`

### Problem
The database schema is managed by a single `init.sql` file that drops and recreates everything. There's no way to incrementally migrate the database schema as the application evolves. This makes deployments risky and collaboration difficult.

### Implementation
1. Create `backend/database/migrations/` directory
2. Create `backend/database/migrations/001_initial_schema.sql` with current schema
3. Create a `backend/database/migrate.php` script that:
   - Creates a `migrations` tracking table if not exists
   - Runs any migration files not yet applied (in order)
   - Records each migration after successful execution
4. Update `README.md` with migration instructions
5. Update `.devcontainer/post-create.sh` to use migration script instead of raw SQL

### Acceptance Criteria
- Running `php backend/database/migrate.php` applies all pending migrations
- Running it again does nothing (idempotent)
- New migration files are automatically picked up

---

## Task 6: Add Input Validation to Frontend Form

**Priority:** MEDIUM  
**Category:** User Experience / Reliability  
**Files affected:** `frontend/src/App.tsx`

### Problem
The frontend form has no client-side validation beyond the range slider constraints. Users can submit with edge cases (e.g., maternal capital exceeding price, initial payment exceeding max). Error messages appear only after server round-trip.

### Implementation
1. Add validation before `handleSubmit` sends the request:
   - `initial_payment + maternal_capital` must be <= `calculatedPrice` (can't borrow negative)
   - `mortgage_term` must be >= 1
   - `selectedArea` and `selectedPaymentMethod` must be selected
2. Show inline validation errors next to form fields (not just top-level banner)
3. Disable submit button when validation fails
4. Add visual indicators (red border) on invalid fields

### Acceptance Criteria
- Form cannot be submitted with invalid data
- Validation errors are shown inline near the relevant field
- Submit button is disabled when form is invalid
- Valid form submits successfully

---

## Task 7: Add Loading States & Skeleton UI

**Priority:** MEDIUM  
**Category:** User Experience  
**Files affected:** `frontend/src/App.tsx`, `frontend/src/App.css`

### Problem
The app shows a spinner during initial load, but there are no loading states for individual operations (submitting form, refreshing requests list). The requests list tab shows stale data until the user clicks it.

### Implementation
1. Add loading state for `fetchRequestsList` (separate from initial load)
2. Show skeleton/placeholder rows in the requests table while loading
3. Add loading state for form submission (already partially done with `isSubmitting`)
4. Disable all form inputs during submission (not just the button)
5. Add a subtle loading indicator on the requests tab button when data is being fetched

### Acceptance Criteria
- Form inputs are disabled during submission
- Requests table shows loading skeleton when refreshing
- No flickering or layout shift during state transitions

---

## Task 8: Add Request Validation & Rate Limiting

**Priority:** MEDIUM  
**Category:** Security / Reliability  
**Files affected:** `backend/src/api.php`

### Problem
The API has no rate limiting or request throttling. A malicious client could flood the server with requests. There's also no CSRF protection or request ID tracking.

### Implementation
1. Add simple rate limiting using SQLite (track requests by IP):
   - Create a `request_log` table: `(id, ip_address, endpoint, created_at)`
   - Log each incoming request
   - Reject requests if more than N from same IP in the last minute
2. Add a `X-Request-ID` header to responses for debugging
3. Add a simple API key check (optional, configurable via `.env`)

### Acceptance Criteria
- More than 60 requests/minute from same IP returns 429
- Each response includes `X-Request-ID` header
- Rate limit is configurable via `.env`

---

## Task 9: Add PHPStan Static Analysis

**Priority:** MEDIUM  
**Category:** Code Quality / Developer Experience  
**Files affected:** `backend/composer.json`, create `backend/phpstan.neon`

### Problem
The PHP codebase has no static analysis. Type errors, missing return types, and potential null dereferences are only caught at runtime. The `MortgageValidator` class has methods that accept `?array` but don't document null behavior clearly.

### Implementation
1. Install phpstan: `composer require --dev phpstan/phpstan`
2. Create `backend/phpstan.neon` with level 6 configuration
3. Add `"phpstan": "phpstan analyse src tests --level 6"` to composer scripts
4. Fix all reported errors:
   - Add proper PHPDoc return types
   - Handle nullable parameters explicitly
   - Add type hints where missing
5. Run phpstan in CI pipeline

### Acceptance Criteria
- `composer phpstan` passes at level 6
- No type errors reported
- CI pipeline includes phpstan step

---

## Task 10: Add Frontend ESLint Rules & Prettier

**Priority:** MEDIUM  
**Category:** Code Quality / Developer Experience  
**Files affected:** `frontend/eslint.config.js`, create `frontend/.prettierrc`

### Problem
The frontend has ESLint configured but no Prettier for consistent formatting. The codebase has inconsistent formatting (mixed quotes, spacing, etc.). No import ordering rules exist.

### Implementation
1. Install prettier: `npm install -D prettier eslint-config-prettier`
2. Create `frontend/.prettierrc` with project-standard formatting rules
3. Update `eslint.config.js` to integrate with prettier
4. Add format script to `package.json`: `"format": "prettier --write src/"`
5. Run formatter on all source files
6. Add format check to CI pipeline

### Acceptance Criteria
- `npm run format` formats all files consistently
- ESLint and Prettier don't conflict
- CI checks formatting

---

## Task 11: Add Pagination to Requests List

**Priority:** LOW  
**Category:** Performance / Scalability  
**Files affected:** `backend/src/api.php`, `frontend/src/App.tsx`

### Problem
The `api/requests` endpoint returns ALL requests without pagination. As the database grows, this will become slow and consume excessive memory. The frontend renders all rows at once.

### Implementation
1. Add `page` and `per_page` query parameters to `api/requests`
2. Add `X-Total-Count` header with total record count
3. Return `{"data": [...], "total": N, "page": P, "per_page": PP}` format
4. Add pagination controls to the frontend requests table (Previous/Next buttons, page numbers)
5. Default `per_page` to 20

### Acceptance Criteria
- `GET /api/requests?page=2&per_page=10` returns correct subset
- Response includes total count
- Frontend shows pagination controls
- No performance degradation with 10,000+ records

---

## Task 12: Add Environment-Specific Configuration Validation

**Priority:** LOW  
**Category:** Reliability / Developer Experience  
**Files affected:** `backend/src/api.php`, `backend/.env.example`

### Problem
The `.env` file is optional and there's no validation that required configuration values exist. If `DB_PATH` is misconfigured, the error message is generic. There's no check that the database file is writable.

### Implementation
1. Add startup validation in `api.php`:
   - Check that `DB_PATH` directory exists and is writable
   - Check that SQLite extension is loaded
   - Check that required PHP extensions are available
2. Return clear, actionable error messages for each check
3. Add a `/api/health` endpoint that returns:
   - Database connection status
   - PHP version
   - Configuration status
4. Update `backend/.env.example` with all possible configuration options and descriptions

### Acceptance Criteria
- Missing database directory returns clear error
- `/api/health` returns 200 with status information
- All configuration options are documented in `backend/.env.example`

---

## Task 13: Add Request Logging & Audit Trail

**Priority:** LOW  
**Category:** Observability / Compliance  
**Files affected:** `backend/src/api.php`, `backend/database/init.sql`

### Problem
There is no audit trail of who submitted what and when beyond the `created_at` timestamp. If multiple users use the system, there's no way to track which user made which request. No request/response logging exists for debugging.

### Implementation
1. Add `user_agent` and `ip_address` columns to `requests` table (or create separate audit table)
2. Log all API requests to a structured log file (JSON lines format)
3. Include: timestamp, method, path, status code, response time, IP
4. Add a `GET /api/logs` endpoint (admin-only, protected by API key)
5. Add log rotation mechanism (keep last 30 days)

### Acceptance Criteria
- Each request record includes IP and user agent
- Log file contains structured entries for all requests
- Log endpoint returns recent logs (when authenticated)

---

## Task 14: Add Dark Mode & Theme Support

**Priority:** LOW  
**Category:** User Experience  
**Files affected:** `frontend/src/App.css`, `frontend/src/App.tsx`, `frontend/src/index.css`

### Problem
The application only supports a light theme. Users working late or with visual preferences for dark mode have no option to switch.

### Implementation
1. Add CSS custom properties (variables) for colors in `index.css`
2. Create `[data-theme="dark"]` selector with dark color palette
3. Add a theme toggle button in the header
4. Persist theme preference in `localStorage`
5. Respect `prefers-color-scheme` system setting as default

### Acceptance Criteria
- Toggle button switches between light and dark themes
- Preference persists across page reloads
- All UI elements are visible in both themes
- System preference is respected on first visit

---

## Task 15: Add API Documentation (OpenAPI/Swagger)

**Priority:** LOW  
**Category:** Documentation / Developer Experience  
**Files affected:** Create `docs/api.yaml`, update `docs/README.md`

### Problem
The API has no formal documentation. New developers must read `api.php` to understand available endpoints, request/response formats, and error codes. This slows down onboarding and integration.

### Implementation
1. Create `docs/api.yaml` with OpenAPI 3.0 specification covering:
   - `GET /api/areas` — list all areas
   - `GET /api/promos` — list all promos
   - `GET /api/payment_methods` — list all payment methods
   - `GET /api/requests` — list all requests (with pagination)
   - `POST /api/integrations/sendForm` — submit mortgage application
   - `GET /api/health` — health check
2. Include request/response schemas, error codes, and examples
3. Update `docs/README.md` with API documentation reference
4. Optionally add Swagger UI integration

### Acceptance Criteria
- OpenAPI spec covers all existing endpoints
- Spec is valid (passes swagger editor validation)
- Examples are accurate and match actual API behavior

---

## Task 16: Add Database Indexes for Performance

**Priority:** LOW  
**Category:** Performance  
**Files affected:** `backend/database/init.sql` or create migration

### Problem
The `requests` table has no indexes on foreign keys (`payment_method_id`, `realty_id`, `promo_id`) or `created_at`. As the table grows, queries (especially `ORDER BY id DESC`) will become slow.

### Implementation
1. Add indexes:
   - `CREATE INDEX idx_requests_created_at ON requests(created_at DESC);`
   - `CREATE INDEX idx_requests_realty_id ON requests(realty_id);`
   - `CREATE INDEX idx_requests_payment_method_id ON requests(payment_method_id);`
2. Add index on `areas.promo_id` for JOIN performance
3. Add index on `promos.id` (primary key already indexed, but verify)

### Acceptance Criteria
- `EXPLAIN QUERY PLAN` shows index usage for common queries
- No performance regression
- Indexes are created in migration (not just init.sql)

---

## Task 17: Add Error Boundary to React App

**Priority:** LOW  
**Category:** Reliability / User Experience  
**Files affected:** Create `frontend/src/ErrorBoundary.tsx`, modify `frontend/src/main.tsx`

### Problem
If any JavaScript error occurs in the React component tree, the entire app crashes with a white screen. There's no fallback UI or error recovery mechanism.

### Implementation
1. Create `ErrorBoundary.tsx` class component (or use react-error-boundary package)
2. Wrap the `<App />` component in `main.tsx` with the error boundary
3. Show a user-friendly error message with a "Retry" button
4. Log error details to console for debugging

### Acceptance Criteria
- Uncaught errors show fallback UI instead of white screen
- "Retry" button attempts to recover
- Error details are logged

---

## Task 18: Add CI/CD Pipeline Improvements

**Priority:** LOW  
**Category:** Developer Experience / Automation  
**Files affected: Create `.github/workflows/ci.yml` (or modify existing)

### Problem
The CI pipeline runs tests and lint but is missing:
- No caching for Composer or npm dependencies
- No static analysis (PHPStan)
- No frontend tests
- No database migration test
- No build artifact caching

### Implementation
1. Add dependency caching for Composer and npm
2. Add PHPStan analysis step
3. Add frontend test step (vitest)
4. Add database migration test step
5. Add build caching for frontend
6. Add a "Build" job that creates production artifacts

### Acceptance Criteria
- CI runs in under 3 minutes (with caching)
- All analysis tools pass
- Database migration is tested
- Frontend tests pass

---

## Task 19: Add Request Filtering & Search

**Priority:** LOW  
**Category:** Feature  
**Files affected:** `backend/src/api.php`, `frontend/src/App.tsx`

### Problem
The requests list shows all records with no way to filter or search. Users cannot find specific requests by date range, payment method, or price range.

### Implementation
1. Add query parameters to `GET /api/requests`:
   - `?payment_method_id=N` — filter by payment method
   - `?realty_id=N` — filter by realty
   - `?date_from=YYYY-MM-DD&date_to=YYYY-MM-DD` — date range filter
   - `?min_price=N&max_price=N` — price range filter
2. Add filter UI to the frontend requests tab:
   - Dropdown for payment method filter
   - Dropdown for realty filter
   - Date range picker
3. Clear filters button

### Acceptance Criteria
- API returns filtered results correctly
- Frontend filters update the displayed list
- Multiple filters can be combined
- Clearing filters returns to full list

---

## Task 20: Refactor API Router to Use Proper Routing

**Priority:** LOW  
**Category:** Architecture / Maintainability  
**Files affected:** `backend/src/api.php`

### Problem
The API uses `strpos()` checks for routing, which is fragile and can lead to false matches (e.g., `/api/areas` matches `/api/areas/extra`). There's no support for route parameters, middleware, or method-based routing.

### Implementation
1. Create a simple `Router` class in `backend/src/Router.php`:
   - `get($path, $handler)` — register GET route
   - `post($path, $handler)` — register POST route
   - `dispatch($method, $uri)` — match and execute handler
2. Support route parameters: `/api/areas/{id}`
3. Support middleware: `router->addMiddleware($fn)`
4. Refactor `api.php` to use the Router class
5. Keep backward compatibility with existing routes

### Acceptance Criteria
- All existing endpoints work with the new router
- Route parameters work correctly
- 404 is returned for unmatched routes
- Code is cleaner and more maintainable

---

## Summary of Priority Distribution

| Priority | Count | Tasks |
|----------|-------|-------|
| HIGH     | 5     | 1, 2, 3, 4, 5 |
| MEDIUM   | 5     | 6, 7, 8, 9, 10 |
| LOW      | 10    | 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 |

**Total: 20 improvement tasks**