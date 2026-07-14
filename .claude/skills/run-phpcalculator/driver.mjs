// REPL driver for the Smart Plan Mortgage Calculator frontend.
// Drives headless Chromium (Playwright) against the Vite dev server.
// Designed for agents: pipe a command script to stdin (see SKILL.md),
// or run interactively and type commands at the `driver>` prompt.
//
// Usage: node .claude/skills/run-phpcalculator/driver.mjs
// Requires: frontend dev server on :5173 and backend on :8000 already running.
import { chromium } from 'playwright';
import * as readline from 'node:readline';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BASE_URL = process.env.BASE_URL || 'http://localhost:5173';
const SHOT_DIR = process.env.SCREENSHOT_DIR || path.join(__dirname, 'screenshots');
fs.mkdirSync(SHOT_DIR, { recursive: true });

// No-root containers can't `apt-get install` chromium's shared libs.
// setup-chrome-deps.sh extracts them unprivileged into this directory
// (dpkg -x, no root needed) — auto-detect and point the loader at it.
const DEPS_DIR = process.env.CHROME_DEPS_DIR || path.join(process.env.HOME || '', '.cache/phpcalculator-chrome-deps');
let launchEnv = { ...process.env };
if (fs.existsSync(DEPS_DIR)) {
  const libDir = path.join(DEPS_DIR, 'usr/lib/x86_64-linux-gnu');
  launchEnv.LD_LIBRARY_PATH = [libDir, path.join(libDir, 'dri'), process.env.LD_LIBRARY_PATH].filter(Boolean).join(':');
  launchEnv.FONTCONFIG_FILE = path.join(DEPS_DIR, 'fonts.conf');
  console.log('using extracted chrome deps at', DEPS_DIR);
}

let browser = null;
let page = null;

const COMMANDS = {
  async launch(url) {
    if (browser) return console.log('already launched');
    browser = await chromium.launch({ args: ['--no-sandbox'], env: launchEnv });
    page = await browser.newPage();
    page.on('console', msg => { if (msg.type() === 'error') console.log('[console:error]', msg.text()); });
    await page.goto(url || BASE_URL);
    console.log('launched. title:', await page.title());
  },

  async nav(url) {
    if (!page) return console.log('ERROR: launch first');
    await page.goto(url.startsWith('http') ? url : BASE_URL + url);
    console.log('nav ->', page.url());
  },

  async ss(name) {
    if (!page) return console.log('ERROR: launch first');
    const f = path.join(SHOT_DIR, (name || `ss-${Date.now()}`) + '.png');
    await page.screenshot({ path: f });
    console.log('screenshot:', f);
  },

  async click(sel) {
    if (!page) return console.log('ERROR: launch first');
    try { await page.click(sel, { timeout: 10_000 }); console.log('click', sel, '-> OK'); }
    catch (e) { console.log('click', sel, '-> ERROR:', e.message.split('\n')[0]); }
  },

  async 'click-text'(rawText) {
    if (!page) return console.log('ERROR: launch first');
    const r = await page.evaluate(t => {
      const els = [...document.querySelectorAll('button, a, [role="button"], .plan-card, div')];
      const el = els.find(e => e.children.length === 0 && e.textContent?.trim() === t)
              ?? els.find(e => e.textContent?.trim() === t)
              ?? els.find(e => e.textContent?.includes(t));
      if (!el) return 'NOT_FOUND';
      el.click(); return 'OK: ' + el.tagName + '.' + el.className;
    }, rawText);
    console.log('click-text', JSON.stringify(rawText), '->', r);
  },

  async select(rawArgs) {
    if (!page) return console.log('ERROR: launch first');
    const [sel, value] = rawArgs.split(/\s+/);
    try { await page.selectOption(sel, value); console.log('select', sel, '=', value, '-> OK'); }
    catch (e) { console.log('select -> ERROR:', e.message.split('\n')[0]); }
  },

  // Range <input type="range">: fill() doesn't work on range inputs and
  // React needs the native value setter + a real 'input' event to see the
  // change (plain el.value = x does NOT trigger onChange).
  async range(rawArgs) {
    if (!page) return console.log('ERROR: launch first');
    const [sel, value] = rawArgs.split(/\s+/);
    const r = await page.evaluate(([s, v]) => {
      const el = document.querySelector(s);
      if (!el) return 'NOT_FOUND';
      const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
      setter.call(el, v);
      el.dispatchEvent(new Event('input', { bubbles: true }));
      return 'OK: value=' + el.value;
    }, [sel, String(value)]);
    console.log('range', sel, '->', r);
  },

  async fill(rawArgs) {
    if (!page) return console.log('ERROR: launch first');
    const [sel, ...textParts] = rawArgs.split(/\s+/);
    try { await page.fill(sel, textParts.join(' ')); console.log('fill', sel, '-> OK'); }
    catch (e) { console.log('fill -> ERROR:', e.message.split('\n')[0]); }
  },

  async type(text)  { if (page) await page.keyboard.type(text, { delay: 30 }); },
  async press(key)  { if (page) await page.keyboard.press(key); },

  async wait(sel) {
    if (!page) return console.log('ERROR: launch first');
    try { await page.waitForSelector(sel, { timeout: 10_000 }); console.log('found:', sel); }
    catch { console.log('TIMEOUT:', sel); }
  },

  async eval(expr) {
    if (!page) return console.log('ERROR: launch first');
    try { console.log(JSON.stringify(await page.evaluate(expr))); }
    catch (e) { console.log('ERROR:', e.message); }
  },

  async text(sel) {
    if (!page) return console.log('ERROR: launch first');
    console.log(await page.evaluate(
      s => (s ? document.querySelector(s) : document.body)?.innerText ?? '(null)',
      sel || null));
  },

  async quit() { if (browser) await browser.close().catch(() => {}); browser = null; page = null; },
  help() { console.log('commands:', Object.keys(COMMANDS).join(', ')); },
};

const stdin = fs.createReadStream(null, { fd: fs.openSync('/dev/stdin', 'r') });
const rl = readline.createInterface({ input: stdin, output: process.stdout, prompt: 'driver> ' });

// Lines arrive faster than async commands finish (esp. piped/heredoc
// input) — readline's 'line' event does not wait for the handler, so
// without a queue, concurrent commands race on the same `page`. With
// piped input, stdin also hits EOF (and readline auto-closes) well
// before the queue drains, so rl.prompt() after that point throws
// ERR_USE_AFTER_CLOSE — guard every prompt() call.
let closed = false;
rl.on('close', () => { closed = true; });
const prompt = () => { if (!closed) rl.prompt(); };

let queue = Promise.resolve();
rl.on('line', line => {
  queue = queue.then(async () => {
    const trimmed = line.trim();
    if (!trimmed) return prompt();
    const spaceIdx = trimmed.indexOf(' ');
    const cmd = spaceIdx === -1 ? trimmed : trimmed.slice(0, spaceIdx);
    const rest = spaceIdx === -1 ? '' : trimmed.slice(spaceIdx + 1);
    const fn = COMMANDS[cmd];
    if (!fn) { console.log('unknown:', cmd, '— try: help'); return prompt(); }
    try { await fn(rest); } catch (e) { console.log('ERROR:', e.message); }
    if (cmd === 'quit') { process.exit(0); }
    prompt();
  });
});
rl.on('close', async () => { await queue; await COMMANDS.quit(); process.exit(0); });

console.log('phpcalculator driver — "help" for commands, "launch" to start');
rl.prompt();
