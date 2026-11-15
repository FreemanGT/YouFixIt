#!/usr/bin/env node
// node web/og.mjs — writes web/og.html (the share card, SPEC §M) and renders site/og.png at 1200 x 630
// with headless Chrome. The panel is the component's own markup in its done state, labelled as an example.
import puppeteer from "puppeteer-core";
import { writeFileSync } from "node:fs";
import { fileURLToPath, pathToFileURL } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const site = join(here, "..", "site");
const C = await import(pathToFileURL(join(site, "js/lib/component.js")).href);
const store = C.createExampleStore();
store.dispatch({ type: "phase", phase: "done" });
const panel = C.panelHTML(store.get(), { mode: "hero", label: false, id: "og" });
const face = C.pebbleSVG("done", { variant: "bar", id: "ogbar", ring: false });

const html = `<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<link rel="stylesheet" href="../site/css/tokens.css">
<link rel="stylesheet" href="../site/css/base.css">
<link rel="stylesheet" href="../site/css/component.css">
<style>
@font-face { font-family: "Anybody Variable"; src: url("../site/fonts/anybody.woff2") format("woff2"); font-weight: 500 800; font-stretch: 75% 112%; }
@font-face { font-family: "Mona Sans Variable"; src: url("../site/fonts/mona-sans.woff2") format("woff2"); font-weight: 400 650; font-stretch: 100% 112%; }
html, body { width: 1200px; height: 630px; overflow: hidden; background: var(--paper); }
.bar { position: absolute; inset: 0 0 auto; height: 44px; display: flex; align-items: center; justify-content: space-between; padding: 0 40px; border-bottom: 1px solid var(--line); background: var(--paper); }
.bar b { font: 650 17px/1 var(--f-text); }
.bar .yf-pb { --pb-size: 34px; }
.glow { position: absolute; inset: 0; background: radial-gradient(640px 420px at 1140px 0, rgba(37,158,128,.14), transparent 70%); }
h1 { position: absolute; left: 64px; top: 118px; width: 600px; font-size: 64px; line-height: 1.02; }
.panel { position: absolute; right: 48px; top: 96px; width: 380px; transform: scale(1.22); transform-origin: top right; }
.note { position: absolute; right: 48px; top: 416px; width: 464px; font: 450 15px/1.4 var(--f-text); color: var(--ink-2); }
</style></head>
<body>
<div class="glow"></div>
<div class="bar"><b>YouFixIt</b><span class="yf-pb yf-pb--bar">${face}</span></div>
<h1>A little face in your menu bar that notices when your Mac gets heavy, and tidies it with one button.</h1>
<div class="panel yf-panel-host">${panel}</div>
<p class="note">Example panel.</p>
</body></html>`;
writeFileSync(join(here, "og.html"), html);

const browser = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: true, args: ["--allow-file-access-from-files", "--force-color-profile=srgb"] });
const page = await browser.newPage();
await page.setViewport({ width: 1200, height: 630, deviceScaleFactor: 1 });
await page.emulateMediaFeatures([{ name: "prefers-color-scheme", value: "light" }]);
await page.goto(pathToFileURL(join(here, "og.html")).href, { waitUntil: "load" });
await page.evaluate(() => document.fonts.ready);
await page.screenshot({ path: join(site, "og.png") });
await browser.close();
console.log("wrote web/og.html and site/og.png");
