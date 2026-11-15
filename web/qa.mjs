#!/usr/bin/env node
/*
  YouFixIt QA — headless Chrome screenshots + error report.

  node web/qa.mjs [options]
    --url <u>          page to load (default http://localhost:4321/)
    --viewport <v>     desktop (1440×900) | mobile (390×844) | both (default) | WxH (e.g. 1024x768)
    --reduced          emulate prefers-reduced-motion: reduce
    --steps <N>        scroll the page in N equal steps (default: 400px steps, as SPEC §8)
    --wait <ms>        settle time per step (default 350)
    --out <dir>        output dir (default <scratchpad>/qa/<run-id>)
    --run <name>       run id used for the default out dir (default: timestamp)
    --frames <spec>    capture 10 frames at 60ms at each position; comma list of
                       <px> | <pct>% (of max scroll) | <sectionId>:<progress> (pinned section progress 0..1)
                       e.g. --frames hero:0,finds:.3,finale:.5
    --only-frames      skip the step pass (frames only)
    --tidy             at the top: press the hero panel's Tidy up, shoot working (+250 ms) and done (+1.6 s),
                       press Undo, shoot again; checks the menu bar name and favicon follow the example
    --gate             exercise the hero gate: empty, incomplete, valid (beacon + DMG navigation, intercepted)
    --dark             emulate prefers-color-scheme: dark
    --theme-check      print computed AA contrast for the token pairs (both schemes)
    --intro            (unused: this site has no intro)
    --overflow         check scrollWidth ≤ innerWidth at 320,375,390,768,1024,1440,1920
    --full             also save a full-page screenshot per viewport
  Prints console errors, page errors, failed requests, long tasks (>50ms after load) and exits 1 on errors.
  Look at the screenshots with the Read tool: "it ran" is not "it's right".
*/
import puppeteer from "puppeteer-core";
import { mkdirSync, readFileSync, existsSync, statSync } from "node:fs";
import { join, extname, dirname } from "node:path";
import { createServer } from "node:http";
import { fileURLToPath } from "node:url";

const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const SCRATCH = process.env.YF_QA_SCRATCH || "/private/tmp/claude-501/-Users-freemansmain--claude-spares-spare-hvlfin/f9d33624-734d-464b-883e-71b36efe9818/scratchpad";

const args = process.argv.slice(2);
const flag = (k) => args.includes(`--${k}`);
const opt = (k, d) => { const i = args.indexOf(`--${k}`); return i >= 0 && args[i + 1] && !args[i + 1].startsWith("--") ? args[i + 1] : d; };

const url = opt("url", "http://localhost:4321/");
const vpArg = opt("viewport", "both");
const reduced = flag("reduced");
const steps = opt("steps") ? parseInt(opt("steps"), 10) : 0;
const wait = parseInt(opt("wait", "350"), 10);
const run = opt("run", new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19));
const out = opt("out", join(SCRATCH, "qa", run));
const frames = (opt("frames", "") || "").split(",").filter(Boolean);
const VPS = { desktop: { width: 1440, height: 900 }, mobile: { width: 390, height: 844, isMobile: true, hasTouch: true, deviceScaleFactor: 2 } };
const viewports = vpArg === "both" ? ["desktop", "mobile"] : [vpArg];
mkdirSync(out, { recursive: true });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const report = { errors: [], warnings: [], longTasks: [], overflow: [], shots: 0 };

// Serve ../site in-process on :4321 when nothing listens there (closed at exit; no standing server).
const SITE = join(dirname(fileURLToPath(import.meta.url)), "..", "site");
const TYPES = { ".html": "text/html; charset=utf-8", ".css": "text/css", ".js": "text/javascript", ".mjs": "text/javascript", ".json": "application/json", ".svg": "image/svg+xml", ".png": "image/png", ".woff2": "font/woff2", ".ico": "image/x-icon", ".txt": "text/plain" };
let server = null;
if (/^http:\/\/localhost:4321\//.test(url)) {
  const up = await fetch(url, { signal: AbortSignal.timeout(800) }).then(() => true, () => false);
  if (!up) {
    server = createServer((req, res) => {
      let p = decodeURIComponent(new URL(req.url, "http://x").pathname);
      let f = join(SITE, p);
      if (existsSync(f) && statSync(f).isDirectory()) f = join(f, "index.html");
      else if (!existsSync(f) && existsSync(f + ".html")) f += ".html";
      if (!f.startsWith(SITE) || !existsSync(f)) { res.writeHead(404, { "content-type": "text/html" }); res.end(existsSync(join(SITE, "404.html")) ? readFileSync(join(SITE, "404.html")) : "404"); return; }
      res.writeHead(200, { "content-type": TYPES[extname(f)] || "application/octet-stream", "cache-control": "no-store" });
      res.end(readFileSync(f));
    }).listen(4321);
  }
}

const browser = await puppeteer.launch({ executablePath: CHROME, headless: true, args: ["--hide-scrollbars", "--force-color-profile=srgb"] });

async function openPage(vpName) {
  const page = await browser.newPage();
  const vp = VPS[vpName] || (() => { const [w, h] = vpName.split("x").map(Number); return { width: w, height: h }; })();
  await page.setViewport({ deviceScaleFactor: 1, ...vp });
  if (vp.isMobile) await page.setUserAgent("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1");
  await page.emulateMediaFeatures([{ name: "prefers-reduced-motion", value: reduced ? "reduce" : "no-preference" }, { name: "prefers-color-scheme", value: flag("dark") ? "dark" : "light" }]);
  const tag = `[${vpName}${reduced ? "/reduced" : ""}${flag("dark") ? "/dark" : ""}]`;
  page.on("console", (m) => {
    if (m.type() === "error") report.errors.push(`${tag} console: ${m.text()}`);
    else if (m.type() === "warn") report.warnings.push(`${tag} warn: ${m.text()}`);
  });
  page.on("pageerror", (e) => report.errors.push(`${tag} pageerror: ${e.message}`));
  page.on("requestfailed", (r) => { if (!r.url().endsWith(".dmg") && !r.url().includes("api.github.com") && !r.url().includes("script.google.com")) report.errors.push(`${tag} requestfailed: ${r.url()} ${r.failure()?.errorText}`); });
  page.on("response", (r) => { if (r.status() >= 400 && !r.url().endsWith(".dmg")) report.errors.push(`${tag} HTTP ${r.status()}: ${r.url()}`); });
  await page.evaluateOnNewDocument((skipIntro) => {
    if (skipIntro) try { sessionStorage.setItem("yf-intro", "1"); } catch {}
    window.__longTasks = [];
    addEventListener("load", () => {
      setTimeout(() => new PerformanceObserver((l) => l.getEntries().forEach((e) => window.__longTasks.push(Math.round(e.duration)))).observe({ type: "longtask" }), 1500);
    });
  }, !flag("intro"));
  if (flag("intro")) {
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 30000 });
    for (let f = 0; f < 14; f++) {
      await page.screenshot({ path: join(out, `${vpName}-intro-${String(f).padStart(2, "0")}.png`) });
      report.shots++;
      await sleep(70);
    }
  } else await page.goto(url, { waitUntil: "networkidle0", timeout: 30000 });
  await sleep(900);
  return { page, tag };
}

// Native scroll (main.js exposes window.__yf for QA).
const scrollTo = (page, y) => page.evaluate((y) => {
  window.scrollTo(0, y);
  window.__yf?.ScrollTrigger?.update();
}, y);

async function resolvePos(page, spec) {
  return page.evaluate((spec) => {
    const max = document.documentElement.scrollHeight - innerHeight;
    if (/^\d+$/.test(spec)) return +spec;
    if (spec.endsWith("%")) return (parseFloat(spec) / 100) * max;
    const [id, p] = spec.split(":");
    const el = document.getElementById(id);
    const ST = window.__yf?.ScrollTrigger;
    const st = ST && ST.getAll().find((s) => s.pin && el && (s.trigger === el || el.contains(s.trigger)));
    if (st) return st.start + parseFloat(p) * (st.end - st.start);
    return el ? el.getBoundingClientRect().top + scrollY + parseFloat(p || 0) * el.offsetHeight : 0;
  }, spec);
}

for (const vpName of viewports) {
  const { page, tag } = await openPage(vpName);
  const prefix = `${vpName}${reduced ? "-reduced" : ""}${flag("dark") ? "-dark" : ""}`;
  const max = await page.evaluate(() => document.documentElement.scrollHeight - innerHeight);
  console.log(`${tag} ${url} · scroll height ${max + (VPS[vpName]?.height || 0)}px`);

  if (!flag("only-frames")) {
    const ys = [];
    if (steps > 0) for (let i = 0; i <= steps; i++) ys.push(Math.round((max * i) / steps));
    else for (let y = 0; y < max; y += 400) ys.push(y);
    if (ys[ys.length - 1] !== max) ys.push(max);
    for (const [i, y] of ys.entries()) {
      await scrollTo(page, y);
      await sleep(wait);
      await page.screenshot({ path: join(out, `${prefix}-${String(i).padStart(3, "0")}-y${y}.png`) });
      report.shots++;
    }
  }

  for (const spec of frames) {
    const y = await resolvePos(page, spec);
    await scrollTo(page, Math.max(0, y - 200));
    await sleep(wait);
    await scrollTo(page, y);
    for (let f = 0; f < 10; f++) {
      await page.screenshot({ path: join(out, `${prefix}-frames-${spec.replace(/[:%.]/g, "_")}-${f}.png`) });
      report.shots++;
      await sleep(60);
    }
  }

  if (flag("tidy")) {
    await scrollTo(page, 0); await sleep(wait);
    const name = () => page.evaluate(() => document.querySelector(".menubar__pebble")?.getAttribute("aria-label"));
    const fav = () => page.evaluate(() => decodeURIComponent(document.querySelector('link[rel="icon"][data-live]')?.href || "").includes("#259E80"));
    console.log(`${tag} before: "${await name()}"`);
    const ok = await page.evaluate(() => { const b = document.querySelector('#hero [data-act="tidy"]'); if (!b) return false; b.click(); return true; });
    if (!ok) report.errors.push(`${tag} tidy: no [data-act="tidy"] in #hero`);
    await sleep(250); await page.screenshot({ path: join(out, `${prefix}-tidy-working.png`) }); report.shots++;
    await sleep(1600); await page.screenshot({ path: join(out, `${prefix}-tidy-done.png`) }); report.shots++;
    const done = await name();
    console.log(`${tag} done: "${done}" · mood ${await page.evaluate(() => document.documentElement.dataset.mood)} · green favicon ${await fav()}`);
    if (!/^Example: /.test(done || "")) report.errors.push(`${tag} menu bar name lacks the "Example: " prefix`);
    await page.evaluate(() => document.querySelector('#hero [data-act="undo"]')?.click());
    await sleep(1200); await page.screenshot({ path: join(out, `${prefix}-tidy-undo.png`) }); report.shots++;
    console.log(`${tag} undo: "${await name()}"`);
  }

  if (flag("gate")) {
    await scrollTo(page, 0); await sleep(wait);
    const hits = [];
    await page.setRequestInterception(true);
    page.on("request", (r) => {
      const u = r.url();
      if (u.includes("script.google.com") || u.endsWith(".dmg")) { hits.push(`${r.method()} ${u.split("?")[0].slice(0, 70)}${r.postData() ? " · " + r.postData().slice(0, 90) : ""}`); r.respond({ status: 204, body: "" }); }
      else r.continue();
    });
    const err = () => page.evaluate(() => { const e = document.querySelector("#gate-hero .gate__error"); return e && !e.hidden ? e.textContent.trim() : "(none)"; });
    const submit = async (v) => { await page.$eval("#gate-hero-email", (i, v) => { i.value = v; }, v); await page.$eval("#gate-hero", (f) => f.requestSubmit()); await sleep(300); };
    await submit(""); console.log(`${tag} gate empty: ${await err()}`);
    await submit("you@example"); console.log(`${tag} gate incomplete: ${await err()}`);
    await submit("qa-test@example.com"); console.log(`${tag} gate valid: error ${await err()} · note "${await page.$eval("#gate-hero .gate__note", (n) => n.textContent)}"`);
    await submit("qa-test@example.com"); // returning visitor: nothing sent twice
    hits.forEach((h) => console.log(`${tag}   → ${h}`));
    await page.setRequestInterception(false);
  }

  if (flag("theme-check")) {
    const pairs = await page.evaluate(() => {
      const probe = document.createElement("i"); document.body.append(probe);
      const rgb = (v) => { probe.style.color = ""; probe.style.color = `var(${v})`; const m = getComputedStyle(probe).color.match(/[\d.]+/g).map(Number); return m; };
      const lum = ([r, g, b]) => [r, g, b].map((c) => { c /= 255; return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4; }).reduce((a, c, i) => a + c * [0.2126, 0.7152, 0.0722][i], 0);
      const blend = (fg, bg) => fg.length > 3 && fg[3] < 1 ? fg.slice(0, 3).map((c, i) => c * fg[3] + bg[i] * (1 - fg[3])) : fg.slice(0, 3);
      const cr = (a, b) => { const bb = rgb(b), aa = blend(rgb(a), bb); const [x, y] = [lum(aa), lum(bb)].sort((p, q) => q - p); return +((x + 0.05) / (y + 0.05)).toFixed(2); };
      const P = [["--ink", "--paper"], ["--ink-2", "--paper"], ["--ink", "--paper-2"], ["--ink-2", "--paper-2"], ["--go-text", "--paper"], ["--go-text", "--paper-2"], ["--go-text", "--go-tonal"], ["--on-go", "--go"], ["--on-go", "--go-hover"], ["--face-green", "--paper"], ["--face-amber", "--paper"], ["--face-ring", "--paper"], ["--go", "--paper"]];
      const r = P.map(([a, b]) => `${a} on ${b}: ${cr(a, b)}`); probe.remove(); return r;
    });
    console.log(`${tag} contrast\n  ` + pairs.join("\n  "));
  }

  if (flag("full")) {
    await scrollTo(page, 0); await sleep(wait);
    await page.screenshot({ path: join(out, `${prefix}-full.png`), fullPage: true });
  }

  const lt = await page.evaluate(() => window.__longTasks);
  if (lt.length) report.longTasks.push(`${tag} ${lt.length} long tasks: ${lt.join(", ")}ms`);
  await page.close();
}

if (flag("overflow")) {
  for (const w of [320, 375, 390, 768, 1024, 1440, 1920]) {
    const page = await browser.newPage();
    await page.setViewport({ width: w, height: 900 });
    await page.evaluateOnNewDocument(() => { try { sessionStorage.setItem("yf-intro", "1"); } catch {} });
    await page.goto(url, { waitUntil: "networkidle0" });
    await sleep(600);
    const r = await page.evaluate(() => ({ sw: document.documentElement.scrollWidth, iw: innerWidth }));
    if (r.sw > r.iw) report.overflow.push(`${w}px: scrollWidth ${r.sw} > ${r.iw}`);
    await page.close();
  }
}

await browser.close();
server?.close();
console.log(`\nshots: ${report.shots} → ${out}`);
for (const k of ["errors", "longTasks", "overflow", "warnings"]) {
  if (!report[k].length) { console.log(`${k}: none`); continue; }
  console.log(`${k} (${report[k].length}):`);
  [...new Set(report[k])].slice(0, 40).forEach((l) => console.log("  " + l));
}
process.exit(report.errors.length || report.overflow.length ? 1 : 0);
