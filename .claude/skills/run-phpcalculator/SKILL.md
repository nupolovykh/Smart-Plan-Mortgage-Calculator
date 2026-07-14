---
name: run-phpcalculator
description: Build, run, and drive the Smart Plan Mortgage Calculator (PHP backend + React/Vite frontend). Use when asked to start the app, run its tests, build it, take a screenshot, or interact with the calculator UI end-to-end.
---

Full-stack web app: a single-file PHP router (`backend/src/api.php`) serving
a REST API over SQLite, and a Vite/React SPA (`frontend/`) that proxies
`/api/*` to it. For agent use, start both servers, then drive the UI
headlessly with the Playwright REPL at
`.claude/skills/run-phpcalculator/driver.mjs` (no `chromium-cli` binary
was available in this container, so this driver was built as its
replacement — same idea, piped commands over stdin).

All paths below are relative to the repo root.

## Prerequisites

Already satisfied in the project's devcontainer (PHP 8.3, Node 20,
Composer, sqlite3). If starting from scratch:

```bash
php --version      # 8.3+
node --version     # 20+
composer --version
sqlite3 --version
```

The driver needs headless Chromium's shared libraries. This container has
**no root/sudo**, so the normal `playwright install --with-deps` path is
unavailable — `setup-chrome-deps.sh` (see Setup) downloads the `.deb`s with
unprivileged `apt-get download` and extracts them with `dpkg -x`. If your
container *does* have root, it uses the normal path instead automatically.

## Setup

```bash
# Backend
cd backend
composer install --no-interaction --prefer-dist
cp -n .env.example .env
sqlite3 database.sqlite < database/init.sql   # idempotent (IF NOT EXISTS)
sqlite3 database.sqlite < database/seed.sql   # idempotent (INSERT OR IGNORE, fixed IDs) - safe to re-run
cd ..

# Frontend
cd frontend && npm install && cd ..

# Driver (Playwright + headless Chromium)
cd .claude/skills/run-phpcalculator
npm install                # installs playwright into this skill dir only
bash setup-chrome-deps.sh  # downloads chromium browser + shared libs (~330MB, ~30s)
cd ../../..
```

`setup-chrome-deps.sh` is safe to re-run; it skips the chromium browser
download if already cached (`~/.cache/ms-playwright`) and re-extracts libs
into `~/.cache/phpcalculator-chrome-deps` otherwise. That directory lives
outside the repo (nothing here is committed to git) and is keyed off
`$HOME`, so a **new container** needs to run it again once.

## Run (agent path)

Start both servers in the background, then drive the frontend:

```bash
cd backend && nohup php -S [::]:8000 src/api.php > /tmp/backend.log 2>&1 & disown
cd ../frontend && nohup npm run dev > /tmp/frontend.log 2>&1 & disown
cd ..
timeout 30 bash -c 'until curl -sf http://localhost:8000/api/areas >/dev/null; do sleep 1; done'
timeout 30 bash -c 'until curl -sf http://localhost:5173 >/dev/null; do sleep 1; done'
```

Then drive it — pipe a command script to the REPL's stdin (same idea as
`chromium-cli`, just a custom driver):

```bash
node .claude/skills/run-phpcalculator/driver.mjs <<'EOF'
launch
ss 01-landing
select select 131
click-text ВТБ (Базовая программа)
range input[type=range]:nth-of-type(1) 200000
ss 02-filled
click-text 🚀 Submit Application to DB
wait .success-message
ss 03-submitted
click-text 📊 Requests History
wait table
ss 04-history
quit
EOF
```

Screenshots land in `.claude/skills/run-phpcalculator/screenshots/`
(override with `SCREENSHOT_DIR`). Frontend URL defaults to
`http://localhost:5173` (override with `BASE_URL`).

For iterative/exploratory use, run the same file under `node ... driver.mjs`
without a heredoc and type commands at the `driver>` prompt — no tmux was
available in this container, so interactive use here means keeping the
process attached to your terminal rather than send-keys/capture-pane.

### Commands

| command | what it does |
|---|---|
| `launch [url]` | launch headless Chromium, navigate to `url` (default `BASE_URL`) |
| `nav <url-or-path>` | navigate the current page |
| `ss [name]` | screenshot → `screenshots/<name>.png` |
| `click <css-sel>` | Playwright `.click()` on a selector |
| `click-text <text>` | click the first button/link/div whose text matches (exact, then substring) |
| `select <css-sel> <value>` | choose a `<select>` option by value |
| `range <css-sel> <value>` | set a `type="range"` input via React's native value setter + `input` event (see Gotchas) |
| `fill <css-sel> <text>` | Playwright `.fill()` |
| `type <text>` / `press <key>` | keyboard input |
| `wait <css-sel>` | wait up to 10s for a selector |
| `eval <js-expr>` | evaluate in page context, print JSON |
| `text [css-sel]` | print `innerText` (default `body`) |
| `quit` | close the browser, exit |

Console errors print automatically as `[console:error] ...` whenever they
fire — check for these after any interaction instead of trusting a
rendered screenshot alone.

## Run (human path)

```bash
cd backend && php -S [::]:8000 src/api.php      # terminal 1
cd frontend && npm run dev                       # terminal 2
```

Open `http://localhost:5173` (not :8000 — Vite proxies `/api/*`).

## Test

```bash
cd backend && composer test    # PHPUnit — 11 tests, 15 assertions, all passing
cd frontend && npm run lint    # eslint — clean
cd frontend && npm run build   # tsc -b && vite build
```

## Gotchas

- **No root in this container.** `npx playwright install --with-deps`
  fails (`sudo: a password is required`). `setup-chrome-deps.sh` falls
  back to `apt-get download <94 packages>` (works unprivileged — it just
  fetches `.deb`s, doesn't install them) + `dpkg -x` into
  `~/.cache/phpcalculator-chrome-deps`, and a hand-written `fonts.conf`
  pointing at the extracted font dir (the stock one references
  `/usr/share/fonts`, which doesn't exist in the relocated prefix — fonts
  silently fail to load without this, and Skia then crashes with
  `SkFontMgr_FontConfigInterface.cpp:163] Not implemented.` on first
  screenshot).
- **React `<input type="range">` ignores plain `el.value = x`.** React
  tracks input state through its own synthetic-event plumbing, so setting
  `.value` directly and dispatching a bubbled `input` event still gets
  ignored unless you go through the native property setter first
  (`Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,
  'value').set`). Playwright's `fill()` doesn't work on range inputs at
  all. The `range` command in the driver does this; use it instead of
  `eval`.
- **Heredoc-piped commands race each other.** Readline's `'line'` event
  fires for every buffered line before an `async` handler's first
  `await` resolves, so without serialization two commands (e.g. `launch`
  and `ss`) run concurrently against the same `page`. The driver queues
  commands via a chained promise — if you extend `driver.mjs`, keep new
  commands going through that same queue rather than reacting to `'line'`
  directly.
- **Port 8000 or 5173 already in use.** The devcontainer sometimes has a
  backend/frontend already running from a previous session. `curl -sf
  http://localhost:8000/api/areas` / `curl -sf http://localhost:5173`
  before starting new ones — reuse what's there instead of erroring.
- **`api/payment_methods` not `api/paymentMethods`.** The backend router
  matches on `strpos($path, 'api/payment_methods')`, snake_case, unlike
  the other three GET endpoints which read the same in camelCase-ish
  form. Getting this wrong returns a 404 with `Endpoint not found`.
- **VS Code's devcontainer port forwarding needs the server listening on
  IPv4, not just IPv6 (or vice versa) — bind dual-stack.** `php -S
  0.0.0.0:8000` binds IPv4 only; Vite's default `server.host` (unset)
  resolved to `[::1]` (IPv6 loopback) only in this container. Either one
  in isolation causes VS Code's forwarder (and the integrated/host
  browser) to get `ERR_CONNECTION_REFUSED` on `localhost:<port>` whenever
  it happens to try the address family the server *isn't* listening on —
  even though `curl localhost:<port>` from inside the container still
  works, because curl (Happy Eyeballs) transparently falls back to the
  other family. Fix: run PHP as `php -S [::]:8000` (with
  `net.ipv6.bindv6only=0`, the container default, `[::]` dual-binds both
  families — confirm with `cat /proc/sys/net/ipv6/bindv6only`), and set
  `server.host: true` in `frontend/vite.config.ts` for Vite. Verify with
  `curl http://127.0.0.1:<port>` **and** `curl http://[::1]:<port>`
  both succeeding, not just plain `curl localhost:<port>`.

## Troubleshooting

- **`chrome-headless-shell: error while loading shared libraries:
  libglib-2.0.so.0`**: chromium deps not set up. Run `bash
  .claude/skills/run-phpcalculator/setup-chrome-deps.sh`.
- **Screenshot succeeds but page renders with system fallback fonts /
  crashes with `SkFontMgr_FontConfigInterface.cpp:163`**: `FONTCONFIG_FILE`
  isn't pointing at the extracted `fonts.conf`. The driver sets this
  automatically when it detects `~/.cache/phpcalculator-chrome-deps` —
  confirm that directory exists and re-run `setup-chrome-deps.sh` if not.
- **`Address already in use` when starting `php -S`**: a backend is
  already running (see Gotchas above) — `curl` it first instead of
  relaunching.
- **`Endpoint not found` from the API**: check the exact route substring
  in `backend/src/api.php` (routing is `strpos()`-based, not a real
  router) — see the `payment_methods` gotcha above.
