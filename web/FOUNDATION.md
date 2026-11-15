# FOUNDATION · YouFixIt site (architect)

Read with `SPEC.md` (wins on design) and `FACTS.md` (wins on claims). This file is the contract for the five section builders.

## Ownership (one writer per file)
| Owner | Files |
|---|---|
| architect | `web/index.html`, `web/build.mjs`, `web/qa.mjs`, `web/og.mjs` (+ generated `web/og.html`), `site/css/tokens.css`, `site/css/base.css`, `site/js/main.js`, `site/js/lib/{store,format,pebble,pebble-geom,motion,favicon,haze,signup,stars,config}.js`, `site/vendor/`, `site/fonts/`, `site/vercel.json`, `site/legal/index.html`, `site/404.html`, `site/favicon.svg`, `site/apple-touch-icon.png`, `site/og.png` |
| product component | `site/js/lib/component.js`, `site/css/component.css` (the panel, the Pebble, the example state machine, `rowHTML`). Builders import from it; nobody edits it but its owner. |
| hero | `web/sections/hero.html`, `site/css/hero.css`, `site/js/hero.js` |
| finds | `web/sections/finds.html`, `site/css/finds.css`, `site/js/finds.js` |
| never | `web/sections/never.html`, `site/css/never.css` |
| faq | `web/sections/faq.html`, `site/css/faq.css` |
| finale | `web/sections/finale.html`, `site/css/finale.css`, `site/js/finale.js` |

SPEC §N named `panel.css` / `panel.js`; the product component lives in `component.css` / `lib/component.js` instead and is linked by the template. Sections never restyle `.yf-*`, `.gate*`, `.menubar*`, `.btn*`; scope your CSS under `#<id>`.
Section files are stubs now: replace them whole. Keep `<section id="<id>" class="s s--paper|s--paper-2" aria-labelledby="…">`. HTML comments not starting with `@` are stripped by the build.

## Build, serve, QA
```
node web/build.mjs                       # stitch → site/index.html (prints checks: one h1, FAQ count, markers, em dash / "!")
timeout 170 node web/qa.mjs --viewport desktop --steps 8          # serves site/ itself on :4321 if nothing listens
timeout 170 node web/qa.mjs --viewport mobile --steps 8 --overflow
timeout 170 node web/qa.mjs --viewport mobile --reduced --dark --steps 4
timeout 170 node web/qa.mjs --viewport desktop --only-frames --tidy --gate --theme-check
node web/og.mjs                           # re-render site/og.png (1200 x 630)
```
Shots land in `<scratchpad>/qa/<run>/` (`--run name`); LOOK at them with Read. `--frames finds:.3,finale:.5` bursts 10 frames. Exit 1 on console errors, failed requests or overflow. `window.__yf = {gsap, ScrollTrigger, store, utils}` for probing.

## Template markers (usable inside section files too)
- `<!-- @gate hero -->` / `<!-- @gate finale -->` · the email gate, identical everywhere (`#gate-<id>`, `#gate-<id>-email`). main.js wires every `form.gate`. Never hand-write a gate.
- `<!-- @panel hero -->` · the product panel server-rendered in its heavy state (first paint complete). Put it inside `<div id="hero-panel">`. If hero.js doesn't mount it, main.js does (fallback), so the page always works.
- `<!-- @row glyph=cube name="Docker" why="No containers running, nothing using it" mib=3788.8 well=tint|grey check=off|true|false size=false id=x attrs="data-x=1" -->` · one app row (component `rowHTML`, classes `.yf-row`, `.yf-row__well`, `.yf-row__name`, `.yf-row__why`, `.yf-row__size`). Glyph names: see `GLYPHS` in component.js. Sizes are MiB and go through `size()`.
- `<!-- @pebble heavy count=5 variant=bar|face size=19 ring=off class="yf-pb--inline" -->` · a static face, hydrated by `hydratePebbles()` (main.js runs it on `main`). `class="yf-pb--inline"` sizes it to 1.25em in running text.
- `<!-- @haze -->` · the face's light (first child of the hero wrapper, which `.s` already makes `position: relative`; base.css lifts its following siblings above the light).
- `<!-- @star -->` (drawn star with `.star__fill`), `<!-- @return -->` (return-key glyph in a `.key`).
- `[data-stars]` anywhere: filled by stars.js with the live count only when ≥ 25; empty and `display:none` otherwise.

## Section modules
```js
// site/js/<id>.js  (hero, finds, finale only)
export default function init({ gsap, ScrollTrigger, lenis, reduced, utils, Component }) {
  // lenis is always null (native scroll). reduced = boot-time value; read utils.reduced for live.
  return () => {}; // optional cleanup
}
```
Mounted after `document.fonts.ready` (1.5 s fallback), in page order, only if `#<id>` exists. Errors are caught per section.
`Component` is `lib/component.js`: `mountPanel(root, {store: utils.store.example, mode:'hero'})`, `Pebble`, `rowHTML`, `panelHTML`, `EXAMPLE`, `COPY`, `size`, `derive`, `timing`, `fold`, `perkIn`.
**Hero:** mount with `store: utils.store.example`, then set `heroPanelEl._yfPanel = <mountPanel result>` (main.js calls its `.perk()` when the menu bar pebble is clicked while the panel is on screen) and dispatch `utils.store.dispatch({type:'hero', open})` when the scroll fold closes/opens it (the menu bar then opens the popover instead).

## utils (everything the SPEC names)
- `utils.store` · the ONE example state. `get()` → `{phase, rows, selected, gone, freed, knowOpen, ask, touched, heroOpen, popoverOpen, downloads}`; `subscribe(fn(state, prev, action))` → off; `dispatch(a)`. Example actions: `toggle {id}`, `tidy`, `undo`, `reset`/`again`, `know {open?}`, `ask`, `touch`. Page actions: `hero {open}`, `popover {open}`, `download`. Helpers: `totals(s)` (component `derive`: `{count, memory, space, total, caption, tip, mood, left…}`), `tooltip(s)` ("Example: …"), `mood(s)`, `tidied(s)` (done or calm: the finale period), `example` (the raw component store, for `mountPanel`).
  ```js
  utils.store.subscribe((s, p) => { if (utils.store.tidied(s) !== utils.store.tidied(p)) setPeriod(s); if (s.downloads !== p.downloads) period.hop(); });
  ```
- `utils.format` · `size(mib)` ("5.6 GB", "15 GB", "690 MB"), `sizeBytes`, `things(n)`, `frees(mem, disk)`.
- `utils.renderPebble(el, {pose, count, size, ring, variant})` → the component `Pebble`: `.to(pose)`, `await .show(mood)`, `.hop()`, `.perk()`, `.blink()`, `.glance(±1)`, `.setCount(n)`, `.breathe(bool)`. `utils.breathe(el)` (blink 4 to 7 s, glance every 3rd/4th, on screen only, 400 ms apart page-wide), `utils.glanceAt(el, x, y)`, `utils.pebbleOf(el)`, `utils.hydratePebbles(root)`.
  ```js
  const p = utils.renderPebble(document.querySelector('#finale .period'), { pose: 'heavy', size: 120 });
  if (utils.store.tidied()) p.show('done');
  ```
- Motion verbs (each has its reduced variant built in): `utils.perk(el, {from:.9})`, `utils.hop(el, {height:3})`, `utils.leave(els, originEl)`, `utils.arrive(els)`, `utils.fold(el, originEl, open, {scale:.94, duration})` (finds card: `{scale:.97, duration:220}`), `utils.roll(el, from, to, fmt)`. Durations `utils.D` (from tokens). GSAP eases registered: `"yfArrive"`, `"yfLeave"`, `"yfPerk"`, `"yfHop"`. CSS: `var(--spring-perk)` + `var(--spring-perk-dur)`, `var(--spring-hop)` + `var(--spring-hop-dur)` (linear() strings), `--ease-arrive`, `--ease-leave`, `--d-*`.
- `utils.reduced` (live), `utils.onReducedChange(fn)`; `html.reduced` class mirrors it.
- `utils.menubar` `{el, button, download, popover, pebble, face}`, `utils.openPopover()`, `utils.closePopover()`.
- `utils.isPhone()`, `utils.config` (`REPO_URL`, `DMG_URL`, `SIGNUP_URL` from the meta, `VERSION`, `UNDO_WINDOW`, `STAR_MIN`).
- One ticker: GSAP's (`gsap.ticker`, asleep while the tab is hidden); the component's tweens ride it via `setTicker`. Use `gsap.ticker.add`, never your own rAF loop. No scroll listeners: ScrollTrigger (hero fold only) or IntersectionObserver.

## Tokens (site/css/tokens.css)
Faces: `--f-display` Anybody (not Bricolage: Bricolage was Notched's display face, SPEC §D.1 swap; wdth 75 to 112, wght 500 to 800, no opsz), `--f-text` Mona Sans (wdth 100 to 112, wght 400 to 650), `--f-mono` Geist Mono (numbers only), `--f-app` / `--f-app-round` (panel replicas). Fonts total 111 KB woff2, Latin subset, metric fallbacks on Arial.
Type: `.t-hero`/`h1`, `.t-h2`/`h2`, `.t-giant`, `.t-sentence`, `.t-lead`, `.t-body`, `.t-small`, `.t-data`; sizes switch at ≤ 720 px. Sentence case, no italics, no uppercase.
Colour: `--paper`, `--paper-2`, `--ink`, `--ink-2`, `--line`, `--go`, `--go-hover`, `--go-text`, `--go-tonal`, `--on-go`, `--face-green`, `--face-amber`, `--face-ring`, `--haze-*`, `--bar`; panel `--p-*` (component.css owns the panel's). Measured in the browser (qa `--theme-check`), light / dark: ink on paper 15.55 / 15.85 · ink-2 on paper 6.14 / 7.17 · ink-2 on paper-2 5.61 / 6.68 · go-text on paper 5.77 / 9.59 · go-text on paper-2 5.27 / 8.92 · go-text on tonal 5.17 / 7.29 · white on go 5.05 / 4.61 · face-green on paper 3.00 / 5.58 · amber on paper 1.84 (light: ring #A8721A 3.71) / 9.11 · focus ring (go) on paper 4.53 / 4.05.
Space: `.wrap` (1200 column + gutters 24 / 16), `.s` (section padding 9rem / 5.5rem), `.s--paper`, `.s--paper-2`, `.grid-12` (collapses to one column ≤ 720), `.collapse` (grid-rows wrapper for leave/arrive), `.sr-only`. Radii `--r-card 14`, `--r-panel 12`, `--r-chip 10`, `--r-pill`, `--r-key 5`. `--bar-h` 36 / 48.
Controls: `.btn.btn--go`, `.btn.btn--tonal`, `.btn.btn--text`, `.link`, `.star` (+ `[data-stars]`), `.key`. Hover = tone + 1 px lift 150 ms; active .98. Focus: 2 px `--go` ring, 2 px offset, everywhere.

## Global elements (architect; don't duplicate)
Menu bar (wordmark, Star it on GitHub, Download pill → nearest gate or one-press download for a remembered email, the live pebble bound by `mountBarFace`), popover (`#popover`, folds out of the pebble when the hero panel is off screen; Escape / outside click / pebble closes; focus returns), haze (`html[data-mood]`, `--pebble-x`), favicon (pebble in the example's pose), footer (after `main`, on paper-2, so the finale should end on paper-2 with no bottom rule), `/legal`, `/404`, `og.png`, JSON-LD (SoftwareApplication + FAQPage generated from `#faq details`: put the question in `<summary><span class="faq__q">…</span></summary>`).

## Deploy notes
`site/` deploys as-is (`vercel.json`: cleanUrls, immutable fonts/vendor, 1 h css/js with `?v=hash`, HTML revalidate, nosniff, referrer policy, CSP allowing only api.github.com and the Apps Script hosts). `web/node_modules/` is gitignored. JS today 74 KB gz in all.
