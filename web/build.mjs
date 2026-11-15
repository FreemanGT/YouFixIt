#!/usr/bin/env node
// node web/build.mjs — stitches web/index.html + web/sections/<id>.html → site/index.html. No deps.
// Markers (usable in the template AND in section files):
//   <!-- @section:<id> -->        the section file (or an empty labelled placeholder if missing)
//   <!-- @css /css/x.css -->      a stylesheet link with ?v=<content hash> (skipped if the file is missing)
//   <!-- @section-css -->         one hashed <link> per existing site/css/<section>.css
//   <!-- @modulepreload -->       <link rel=modulepreload> for main.js's static module graph
//   <!-- @main -->                <script type=module src=/js/main.js?v=hash>
//   <!-- @faq-jsonld -->          FAQPage JSON-LD from #faq <details> (text identical to the page)
//   <!-- @pebble <pose> [count=N] [variant=bar|face] [size=PX] [ring=off] [class="a b"] -->  static face (component Pebble markup, hydrated by pebble.js)
//   <!-- @panel <hero|popover> -->  the example panel, server-rendered in its heavy state (component panelHTML; mountPanel hydrates)
//   <!-- @row glyph=cube name="Docker" why="No containers running, nothing using it" mib=3788.8 [well=tint|grey] [check=off|true|false] [size=false] [id=x] [attrs="..."] -->  one app row (component rowHTML)
//   <!-- @gate <id> -->           the email gate (same markup everywhere; id → #gate-<id>)
//   <!-- @haze -->                the face's light layers (place inside the hero wrapper)
//   <!-- @star -->  <!-- @return -->  drawn glyphs (star with .star__fill; return-key glyph in a .key)
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { createHash } from "node:crypto";
import { fileURLToPath, pathToFileURL } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const site = join(here, "..", "site");
export const SECTIONS = ["hero", "finds", "never", "faq", "finale"];
const C = await import(pathToFileURL(join(site, "js/lib/component.js")).href);
const DMG = "https://github.com/FreemanGT/YouFixIt/releases/latest/download/YouFixIt.dmg";

const hash = (rel) => {
  const f = join(site, rel.replace(/^\//, ""));
  return existsSync(f) ? createHash("sha1").update(readFileSync(f)).digest("hex").slice(0, 8) : null;
};

// 0. Fonts are cached immutable, so their URLs carry a content hash: tokens.css url()s are rewritten in place
//    (idempotent), and the template's preload hrefs get the same ?v so preload and @font-face match.
const fontV = (path) => `${path}?v=${hash(path)}`;
{
  const tf = join(site, "css", "tokens.css");
  const src = readFileSync(tf, "utf8");
  const out = src.replace(/url\("(\/fonts\/[^"?]+\.woff2)(?:\?v=[0-9a-f]+)?"\)/g, (_, p) => `url("${fontV(p)}")`);
  if (out !== src) writeFileSync(tf, out);
}
let html = readFileSync(join(here, "index.html"), "utf8")
  .replace(/href="(\/fonts\/[^"?]+\.woff2)"/g, (_, p) => `href="${fontV(p)}"`);
const missing = [];

// 1. Sections first, so their own markers expand below.
html = html.replace(/<!-- @section:([a-z-]+) -->/g, (_, id) => {
  const f = join(here, "sections", `${id}.html`);
  // Authors' notes (<!-- anything not starting with @ -->) are stripped; markers stay.
  const src = existsSync(f) ? readFileSync(f, "utf8").replace(/<!--(?! @)[\s\S]*?-->\s*/g, "").trim() : "";
  if (!src) { missing.push(id); return `<section id="${id}" class="s s--${id}" aria-label="${id}"></section>`; }
  return src;
});

// 2. Glyphs and components.
const STAR = `<svg class="icon star__glyph" viewBox="0 0 20 20" aria-hidden="true" focusable="false"><path class="star__fill" d="M10 2.4l2.35 4.77 5.26.76-3.8 3.71.9 5.24L10 14.4l-4.71 2.48.9-5.24-3.8-3.71 5.26-.76z" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/></svg>`;
const RETURN = `<span class="key" aria-hidden="true"><svg viewBox="0 0 16 16" focusable="false"><path d="M13 3.5v4.25a2 2 0 0 1-2 2H3.5M6.25 6.75 3.5 9.75l2.75 3" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg></span>`;
const HAZE = `<div class="haze" aria-hidden="true"><div class="haze__layer haze__layer--amber"></div><div class="haze__layer haze__layer--green"></div></div>`;
const NOTE = "Your email goes to a Google Sheet the maker reads, and nowhere else. The app itself never goes online.";
let pebbleN = 0;
// A static pebble in the component's own markup (.yf-pb host + svg.yf-pebble), so pebble.js hydrates it in place.
function pebble(pose, a = {}) {
  const variant = a.variant || "bar";
  const count = a.count != null ? +a.count : null;
  const style = a.size ? ` style="--pb-size:${+a.size}px"` : "";
  const cnt = variant === "bar" ? `<span class="yf-pb__count" aria-hidden="true"${count ? "" : " hidden"}>${count ?? ""}</span>` : "";
  return `<span class="yf-pb yf-pb--${variant}${a.class ? " " + a.class : ""}" data-pebble="${pose}" data-variant="${variant}"${count != null ? ` data-count="${count}"` : ""}${a.ring === "off" ? ' data-ring="off"' : ""}${style} aria-hidden="true">${C.pebbleSVG(pose, { variant, id: `pb${++pebbleN}`, ring: a.ring !== "off" })}${cnt}</span>`;
}
const attrs = (s) => Object.fromEntries([...s.matchAll(/([a-z]+)=("([^"]*)"|\S+)/g)].map((m) => [m[1], m[3] ?? m[2]]));
html = html
  .replace(/<!-- @star -->/g, STAR)
  .replace(/<!-- @return -->/g, RETURN)
  .replace(/<!-- @haze -->/g, HAZE)
  .replace(/<!-- @pebble ([a-z]+)\s*([^>]*?)\s*-->/g, (_, pose, rest) => pebble(pose, attrs(rest)))
  .replace(/<!-- @panel ([a-z]+) -->/g, (_, mode) => C.panelHTML(C.createExampleStore().get(), { mode, id: `yf-panel-${mode}` }))
  .replace(/<!-- @row\s+([^>]*?)\s*-->/g, (_, rest) => {
    const a = attrs(rest);
    const check = a.check === "true" ? true : a.check === "off" ? "off" : false;
    return C.rowHTML({ id: a.id || "", glyph: a.glyph || "cube", name: a.name || "", why: a.why || "", mib: a.mib ? +a.mib : 0 },
      { check, size: a.size !== "false", well: a.well || "tint", attrs: a.attrs || "" });
  })
  .replace(/<!-- @gate ([a-z0-9-]+) -->/g, (_, id) => `<form class="gate" id="gate-${id}" method="dialog" novalidate>
  <label class="gate__label" for="gate-${id}-email">Your email</label>
  <div class="gate__capsule">
    <input class="gate__input" id="gate-${id}-email" type="email" name="email" autocomplete="email" inputmode="email" required placeholder="you@example.com" aria-describedby="gate-${id}-note">
    <button class="btn btn--go gate__btn" type="submit"><span class="gate__btn-text">Download for Mac</span>${RETURN}</button>
  </div>
  <div class="gate__hp" aria-hidden="true"><label>Company <input type="text" name="company" tabindex="-1" autocomplete="off"></label></div>
  <p class="gate__error" id="gate-${id}-error" role="alert" hidden>${pebble("heavy", { size: 19 })}<span class="gate__error-text"></span></p>
  <p class="gate__note" id="gate-${id}-note" role="status">${NOTE}</p>
  <noscript><p class="gate__note"><a href="${DMG}">Download YouFixIt for Mac</a></p></noscript>
</form>`);

// 3. Styles and scripts, hashed for cache-busting (vercel.json: max-age=0 + must-revalidate on /css, /js, so
//    main.js's unversioned imports are always revalidated by ETag and never mix versions).
html = html.replace(/<!-- @css (\S+) -->/g, (_, href) => {
  const h = hash(href);
  return h ? `<link rel="stylesheet" href="${href}?v=${h}">` : `<!-- missing ${href} -->`;
});
html = html.replace("<!-- @section-css -->", SECTIONS
  .filter((id) => existsSync(join(site, "css", `${id}.css`)))
  .map((id) => `<link rel="stylesheet" href="/css/${id}.css?v=${hash(`/css/${id}.css`)}">`).join("\n"));
html = html.replace("<!-- @main -->", `<script type="module" src="/js/main.js?v=${hash("/js/main.js")}"></script>`);

// modulepreload for main.js's static graph (unhashed: these are the URLs the imports resolve to).
const js = join(site, "js");
const graph = new Set();
const walk = (rel) => {
  if (graph.has(rel) || !existsSync(join(js, rel))) return;
  graph.add(rel);
  const src = readFileSync(join(js, rel), "utf8");
  for (const [, spec] of src.matchAll(/\bfrom\s*["'](\.{1,2}\/[^"']+\.js)["']/g)) walk(join(dirname(rel), spec));
};
walk("main.js");
for (const id of SECTIONS) walk(`${id}.js`); // section modules: main.js imports them in parallel at boot
html = html.replace("<!-- @modulepreload -->", [...graph].filter((f) => f !== "main.js")
  .map((f) => `<link rel="modulepreload" href="/js/${f}">`).join("\n"));

// 4. FAQPage JSON-LD from the #faq section's <details>.
const text = (s) => s
  .replace(/<svg[\s\S]*?<\/svg>/g, "").replace(/<(script|style)[\s\S]*?<\/\1>/g, "").replace(/<[^>]+>/g, " ")
  .replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;|&rsquo;/g, "’")
  .replace(/\s+/g, " ").trim();
const faqSection = (html.match(/<section[^>]*id="faq"[\s\S]*?<\/section>/) || [""])[0];
const qa = [...faqSection.matchAll(/<details[^>]*>([\s\S]*?)<\/details>/g)].map(([, inner]) => {
  const summary = (inner.match(/<summary[^>]*>([\s\S]*?)<\/summary>/) || ["", ""])[1];
  const q = summary.match(/class="[^"]*\bfaq__q\b[^"]*"[^>]*>([\s\S]*?)<\/(?:span|h3|p|div)>/);
  return { question: text(q ? q[1] : summary), answer: text(inner.replace(/<summary[\s\S]*?<\/summary>/, "")) };
}).filter((x) => x.question && x.answer);
html = html.replace("<!-- @faq-jsonld -->", qa.length
  ? `<script type="application/ld+json">${JSON.stringify({
      "@context": "https://schema.org", "@type": "FAQPage",
      mainEntity: qa.map((x) => ({ "@type": "Question", name: x.question, acceptedAnswer: { "@type": "Answer", text: x.answer } })),
    }).replace(/</g, "\\u003c")}</script>`
  : "");

writeFileSync(join(site, "index.html"), html);

// 5. Checks.
const h1 = (html.match(/<h1[\s>]/g) || []).length;
const leftover = [...html.matchAll(/<!-- @([a-z-]+)[^>]*-->/g)].map((m) => m[1]);
const banned = [/\u2014/g, /!(?=\s|<|$)(?![^<]*>)/g].reduce((n, re) => n + (html.replace(/<script[\s\S]*?<\/script>|<style[\s\S]*?<\/style>|<!--[\s\S]*?-->/g, "").match(re) || []).length, 0);
console.log(`built site/index.html · ${(html.length / 1024).toFixed(1)} KB · ${qa.length} FAQ entries · ${h1} <h1> · ${graph.size - 1} modulepreloads · ${pebbleN} pebbles`);
if (missing.length) console.error(`\x1b[33mnote: empty sections → placeholders: ${missing.join(", ")}\x1b[0m`);
if (h1 !== 1) console.error(`\x1b[31mWARNING: expected exactly one <h1>, found ${h1}\x1b[0m`);
if (qa.length && qa.length !== 5) console.error(`\x1b[33mnote: FAQ has ${qa.length} entries (SPEC says 5)\x1b[0m`);
if (leftover.length) console.error(`\x1b[31mWARNING: unexpanded markers: ${leftover.join(", ")}\x1b[0m`);
if (banned) console.error(`\x1b[31mWARNING: ${banned} em dash / exclamation mark(s) in page text (copy rules)\x1b[0m`);
