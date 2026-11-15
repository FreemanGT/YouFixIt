# Foundation component: the living hero

Files (one owner, this component):
- `site/js/lib/component.js` (ES module, no dependencies, Node-safe at import)
- `site/css/component.css` (panel tokens `--p-*`, pebble, folds, panel, shared app row)
- `site/component-lab.html` (QA only, `noindex`; exclude from the deploy or leave unlinked)

Rebuilt from `StatusIcon.swift` (Pose numbers, mix, perk ease, blink, sweep), `Theme.swift` (sizes, motion, colours),
`PopoverView.swift` (layout, MeasuredScroll fade, footer), `FindingRow.swift` (row anatomy, KnowRow), `Copy.swift`
(every string, `Format.size`). Checked side by side in the lab against `snapshots/heavy-light`, `heavy-dark`,
`done-dark`, `working-mid-light` and `icon-poses-light`.

Two faithful details that differ from SPEC G.1 wording: eye centres are 8 and 14 at y 10 on the 22 canvas
(`cx ± eyeGap 3`, `cy - 1`), and the menu bar's done eyes are ^ ^ arcs over the top while the panel face smiles
with ∪ arcs, as in the renders. `working` squashes about the centre, as the app does.

## Quick start

```html
<link rel="stylesheet" href="/css/component.css">
<button class="menubar__face" aria-haspopup="dialog" aria-expanded="false"></button>
<div id="hero-panel"></div>
<script type="module">
  import { createExampleStore, mountPanel, mountBarFace } from '/js/lib/component.js';
  const store = createExampleStore();                 // heavy, 5 rows, 2 Good to know lines
  const hero = mountPanel(document.querySelector('#hero-panel'), { store, mode: 'hero' });
  const bar = mountBarFace(document.querySelector('.menubar__face'), { store });
  // after load + 1.2 s: the two faces perk together once
  setTimeout(() => { bar.pebble.perk(); hero.perk(); }, 1200);
</script>
```

Server-render the heavy state (build.mjs, Node): `import { createExampleStore, panelHTML } from '../site/js/lib/component.js'`,
then `panelHTML(createExampleStore().get(), { mode: 'hero', id: 'hero-panel-p' })` into the host div. `mountPanel` sees
the existing `.yf-panel` and hydrates it instead of re-rendering (same for the face SVG). For the bar pebble, put
`pebbleSVG('heavy')` inside a `<span class="yf-pb yf-pb--bar">` plus `<span class="yf-pb__count">5</span>`.

## Store (SPEC H) · `createExampleStore(opts)`
`{ get(), subscribe(fn(state, action)) -> unsubscribe, dispatch(action), derive() }`. Opts: `rows`, `know`
(default `EXAMPLE`), `undoWindow` (60000), `phase`.
Actions: `'tidy'` (heavy -> working -> done after `timing.working(n)`, about 0.95 s; 0.6 s reduced) · `'undo'`
(done -> heavy, previous checks restored) · `'reset'` (anything -> heavy, all checked) · `{type:'toggle', id}` ·
`{type:'know', open?}` · `'ask'` (note for 6 s) · `'touch'` · `{type:'phase', phase}` (jump, no animation).
After done, `calm` follows by itself after `undoWindow`. State: `phase, rows, know, selected[], gone[], freed (MiB),
knowOpen, ask, touched`. `state.touched` turns true on the first interaction (hide "Press Tidy up." on it).
`derive(state)` -> `count, memory, space, total, caption, tip ("Example: YouFixIt, 5 things to tidy, about 21 GB"),
mood ('heavy'|'working'|'done'|'calm')`. Use `mood` for `html[data-mood]`, the favicon and the finale period.

## Panel · `mountPanel(root, { store, mode, onClose, label, id })`
Renders or hydrates the panel and the example label under it ("Example panel. On your Mac it lists what your Mac
is actually carrying."; `label:false` drops it). Returns `{ el, face, focus(), perk(), destroy() }`.
- `role="dialog"`, `aria-label="YouFixIt, example panel"`, `tabindex="-1"`; a polite live region speaks `derive().tip`.
- Tab order: row checks (`button[aria-pressed]`, 44 px hit) -> Good to know (`aria-expanded`) -> Tidy up / Undo ->
  Ask Claude. Clicking a card also toggles it (the app's tap). Return runs Tidy up / Undo only when the panel element
  itself has focus (a click inside it focuses it), never from body or another control. Escape calls `onClose` in
  `mode:'popover'`.
- Tidy up: checks become spinners for 260 ms, rows leave nearest-the-pill first (160 ms leave ease, 80 ms steps, cap 5),
  badges count down in step, empty sections fold, the header perks to "Tidying up…" then "Freed up 21 GB" (rolls
  up over 600 ms), the pill becomes the tonal Undo and takes focus. Undo returns rows top-down (220 ms arrive).
- The list caps at `--yf-list-max` (340 px, the app's 560 - 220) and scrolls inside with the 28 px fade
  (`[data-overflow]`). Phone sheet: set `--yf-list-max: min(340px, calc(100svh - 360px))` on the host.
- Pause and gear are drawn, `aria-hidden`, inert. Width: `--yf-panel-w` (380 px; 100 % at <= 720).

## Pebble · `new Pebble(el, { variant, pose, count, ring, breathe })`
`variant: 'bar'` (22 pt canvas, eyes cut out, count beside it) or `'face'` (40 x 32 header face, white eyes).
Poses: `calm blink glance light heavy working done hop paused` (`POSES`, exact StatusIcon numbers; custom objects work).
- `to(pose, { ease: 'smooth'|'perk'|'arrive'|'none', duration })` -> Promise, frame-by-frame blend (tint flips at half).
- `show(mood, { thenCalm })` the app's entrance per mood; `'done'` = hop in, smile, hold 1.2 s, one hop, stay done.
- `hop()`, `perk()` (drop a unit, spring back), `blink()` (90 ms), `glance(dir)` (600 ms), `setCount(n|null)` (rolls),
  `breathe(true)` (blink every 4 to 7 s, glance every 3rd or 4th, only on screen, never two within 400 ms), `destroy()`.
- `working` sweeps its eyes 0.7 units every 1.2 s while shown.
- Size with `--pb-size` (24 px default). Colours: `--pb-calm` (defaults to `--ink`), `--pb-green` #259E80,
  `--pb-amber` #EDA833; the `#A8721A` ring shows on amber in light mode only.
- `pebbleSVG(pose, { variant, id })` returns markup (favicon, finale period, 404, finds lead).
  `mountBarFace(button, { store })` binds a bar pebble: pose, count rolling down per leaving row, `aria-label` and
  `title` = the "Example: " tooltip.

## Rows for finds and never · `rowHTML(row, opts)`
`row = { name, why, glyph, mib }`, opts `{ check: false|true|'off', size: true, well: 'tint'|'grey', tag, attrs }`.
Wrap in an element with class `yf-p` so panel tokens apply. Add `yf-row--hover` for the card hover fill.
Classes: `.yf-row .yf-row__well .yf-row__text .yf-row__name .yf-row__why .yf-row__size` (SPEC's `.row*` names).
Glyphs (`glyph(name)`, drawn strokes): phone cube server hammer disk app terminal database gear bolt folder archive
film search photo sparkles pause return tick chevron arrow.

## Motion helpers
`EASE` (arrive, leave, smooth, perk), `SPRING.perk/hop` (SwiftUI spring math; `.linear()` gives a CSS `linear()`),
`CSS_EASE`, `T` (Theme durations), `timing` (`leaveDelay(i)`, `working(n)`, `returnDelay(i)`), `fold(el, origin, open)`
(popover open 360 ms arrive from .94 at the origin, close 160 ms; reduced: 160 ms opacity), `perkIn(el)`, `roll()`,
`size()`, `frees()`, `COPY`. One ticker: `setTicker(gsap.ticker.add, gsap.ticker.remove)` hands every frame to GSAP's
ticker; otherwise one rAF loop paused while the tab is hidden.

## Reduced motion
Pose swaps are instant with a 120 ms crossfade, no hop, perk or glance; the blink stays. Rows cross-fade out together
over 220 ms; folds lose their lift; numbers jump. Every state is complete without animation and without JS
(server-rendered heavy).

## Verified in the lab
Format sums: 5.6 GB memory, 15 GB space, 21 GB freed. Return on body: nothing; on the panel: tidy (done in 935 ms,
623 ms reduced) and Undo. Uncheck recomputes caption, count and tooltip. Popover opens from the bar face, Escape
closes it and returns focus. No console errors, no long tasks during Tidy up.
Lab: `component-lab.html` (live, both schemes, one store), `?view=compare&state=heavy|done|working|calm&scheme=light|dark[&act=tidy][&know=1]`,
`?view=poses&scheme=light|dark`.
