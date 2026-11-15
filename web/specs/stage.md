# Spec · STAGE · YouFixIt launch site

Lens: PRODUCT STAGE. Light, camera and scroll carry the living product through its real states. Cinema craft, no film props: no clapperboards, no letterbox bars, no "scene 1" labels, no lens flares. The camera is a transform; the light is the face's own colour.

## 0. The one idea

**The face is the light in the room: the Mac on the page glows amber because it is heavy, and when you press Tidy up yourself the light turns green and the face smiles.**

Juror's repeat: "You press Tidy up on the website and the amber light in the room goes green."

Why it holds against the brief: the hero explains the product (a menu bar face plus its panel, captioned, headline says what it is); the only colour on the page is the product's own (face green, face amber, app accent); the one big motion is caused by the visitor's press, not by an intro; complete at rest in every state.

## 1. Design tokens

All tokens live in `site/css/tokens.css` (architect). Panel replica tokens are prefixed `--app-` and are copied from `Sources/YouFixIt/Theme.swift`; page tokens are prefixed `--pg-`.

### 1.1 Faces (self-hosted subset woff2, `site/fonts/`)

| Role | fontsource package | Axes used | Where | Why |
|---|---|---|---|---|
| Display | `@fontsource-variable/fredoka` | `wght` 300 to 700 (use 560 to 640), `wdth` 75 to 125 (use 108 to 118) | exactly three places: hero H1, "Free forever." heading, the finale line | A rounded, slightly wide face drawn like the pebble: soft corners, round counters, no stock grotesk. It is the web cousin of SF Pro Rounded the app uses, so the page and the panel feel like one family without copying the system face. This is the project's one aesthetic risk (Q16): rounded display can tip into toy; held back by tight tracking, 600 weight, and only three uses. |
| Text | `@fontsource-variable/instrument-sans` | `wght` 400 to 700, `wdth` 75 to 100 (use 100; 92 for nav pills) | all running text, H2s, buttons, FAQ | Quiet, slightly condensed humanist grotesk with a warm `a` and `g`; not on the banned list; reads well at 16 to 40 px. |
| Data | `@fontsource-variable/geist-mono` | `wght` 400 to 600 | numbers only: sizes in the stage (GB, MB), the star count, the menu bar clock, ports in chips | Liked data face (Q31); tabular digits. Never labels. |
| Panel replica | system stack, no file | n/a | inside the rebuilt panel only | `ui-rounded, "SF Pro Rounded", system-ui, -apple-system, "Instrument Sans", sans-serif` for title, hero line and pill; `system-ui, -apple-system, "Instrument Sans", sans-serif` for body. On a Mac it is the real app's face (BRIEF §6 override). |

Subsets: Latin Basic + `· … ’ “ ” – @`; Geist Mono subset to `0-9 . , : GBMK space`. Targets: Fredoka var subset at or under 48 KB, Instrument Sans var at or under 44 KB, Geist Mono at or under 12 KB. Total at or under 110 KB. `font-display: swap`. Preload Fredoka and Instrument Sans only.

Metric fallbacks (`@font-face` with `size-adjust`, `ascent-override`, `descent-override`, computed by the architect with `fontaine`-style math from the real files and recorded in tokens.css):
- `"Fredoka Fallback"`: `local("Arial Rounded MT Bold"), local("Arial")`.
- `"Instrument Sans Fallback"`: `local("Arial")`.
- `"Geist Mono Fallback"`: `local("Menlo"), local("Courier New")`.

Type scale (desktop 1440 / phone 390):
- `--t-hero`: Fredoka 600, wdth 112, 64 px / 1.02, tracking -0.025em · phone 40 px / 1.04.
- `--t-big`: Fredoka 620, wdth 116, clamp(88px, 13vw, 200px) / 0.95, tracking -0.03em (finale and "Free forever.") · phone 64 px.
- `--t-h2`: Instrument Sans 600, 40 px / 1.1, tracking -0.02em · phone 30 px.
- `--t-lede`: Instrument Sans 500, 34 px / 1.36, tracking -0.012em (the chip sentence) · phone 22 px / 1.5.
- `--t-body`: Instrument Sans 400, 18 px / 1.5 · phone 17 px.
- `--t-small`: Instrument Sans 450, 15 px / 1.45.
- `--t-data`: Geist Mono 500, inherits size, `font-variant-numeric: tabular-nums`.
Sentence case everywhere, no uppercase anywhere. The wordmark is "YouFixIt" in Instrument Sans 650.

### 1.2 Colour (light and dark both designed; follows the OS, no toggle)

Page material is a cool stone paper, the colour of a grey pebble. Colour arrives only from the product.

| Token | Light | Dark | Use |
|---|---|---|---|
| `--pg-bg` | #F4F3EF | #131413 | page |
| `--pg-raised` | #FBFAF7 | #1C1D1C | nav bar, field, FAQ open row |
| `--pg-sunk` | #E9E7E1 | #232523 | the "plain facts" band, chip fill |
| `--pg-ink` | #1B1C1A | #F2F1EC | text |
| `--pg-ink-2` | #5C5E58 | #A3A59F | secondary text |
| `--pg-line` | #E2E0DA | #2C2E2C | 1 px hairlines |
| `--pg-accent` | #136B57 | #19846B | Download pill fill, focus ring, links (go only) |
| `--pg-accent-text` | #136B57 | #66CCAB | accent used as text |
| `--face-green` | #259E80 | #259E80 | the face, light pose; green stage light |
| `--face-amber` | #EDA833 | #EDA833 | the face, heavy pose; amber stage light |
| `--face-grey` | #8A8C86 | #8E908A | the face, calm pose (outside the menu bar) |

Contrast, computed (WCAG 2.x):
- ink on bg 15.41 (light) · 16.33 (dark). ink on raised 16.39 · 14.95. ink on sunk 13.83 · n/a.
- ink-2 on bg 5.92 · 7.42. ink-2 on raised 6.29 · 6.80. ink-2 on sunk 5.31 · 6.20.
- white on accent pill 6.43 (#136B57) · 4.61 (#19846B, dark). Accent text #136B57 on bg 5.79, on raised 6.16, on sunk 5.20 · #66CCAB on bg 9.49, on raised 8.69.
- The face colours are graphics, never text. Non-text contrast against the page: green 3.01 (light) · 5.52 (dark); grey 3.06 · 5.72; amber 1.85 (light, fails) · 9.01 (dark). Fix for amber in light mode: the amber face carries a 1 px inside ring `#A8721A` (4.0 on #F4F3EF; architect re-verifies) and its state is never told by colour alone (bigger eyes, 1 px lift, the count, the panel's header sentence). Count numerals beside the face use `--pg-ink`.
- Banned palettes avoided: no cream plus terracotta, no near-black plus acid green (green appears only as the face and the go button, at app saturation), no purple gradients, no Anthropic amber as a brand colour (amber is the app's own heavy state and only ever the face or its light).

Panel replica (from Theme.swift; `--app-*`):

| Token | Light | Dark |
|---|---|---|
| `--app-window` | #ECECEC | #2D2D2D |
| `--app-card` | rgba(0,0,0,.055) ≈ #DFDFDF | rgba(255,255,255,.085) ≈ #3B3B3B |
| `--app-card-hover` | rgba(0,0,0,.09) | rgba(255,255,255,.13) |
| `--app-pill` (size pill, count badge) | rgba(0,0,0,.08) | rgba(255,255,255,.08) |
| `--app-label` | #1F1F1F | #EBEBEB |
| `--app-label-2` | #616161 | #ABABAB |
| `--app-tint` (Tidy up fill) | #136B57 (darkened from #177D66 for 6.43 with white; noted deviation) | #19846B |
| `--app-tint-text` | #136B57 | #66CCAB |
| `--app-tonal` (Undo) | #CEDCD9 (tint at 14 %) | #2A3936 |
| `--app-amber-face` | #D99A2B | #F0B445 |
| `--app-key-on-accent` | rgba(255,255,255,.22) | same |

Panel contrast: label on card 11.01-plus (#1F1F1F on #DFDFDF 12.37) · label-2 on card 4.65 (light), 4.88 (dark) · label-2 on window 5.24 · 6.00 · tint-text on window 5.44 · 7.08 · Undo text on tonal 4.55 (light, 15 px semibold) · 6.21 (dark) · white on Tidy up 6.43 · 4.61.

### 1.3 Radii, spacing, depth

- Radii: `--r-card` 14 px (app cards, chips) · `--r-panel` 12 px (popover window, matches the snapshots) · `--r-pill` 999 px · `--r-slab` 28 px (the stage glass) · `--r-field` 999 px.
- Space: 4 px grid. `--s-1` 4 · `--s-2` 8 · `--s-3` 12 · `--s-4` 16 · `--s-5` 24 · `--s-6` 32 · `--s-7` 48 · `--s-8` 72 · `--s-9` 112 (section padding desktop) · phone section padding 72.
- Column: 1200 px max, 120 px side margins at 1440; phone 16 px gutters. Text measure inside sections: 640 px max.
- Depth: flat 1 px hairlines by default. Two exceptions, both product: the panel casts the macOS popover shadow (`0 0 0 .5px rgba(0,0,0,.18), 0 12px 40px rgba(0,0,0,.18)`; dark `0 0 0 .5px rgba(255,255,255,.12), 0 16px 48px rgba(0,0,0,.5)`), and the stage light (below).

### 1.4 Easing and duration (from Theme.swift, so the page moves like the app)

| Token | Value | Use |
|---|---|---|
| `--e-arrive` | cubic-bezier(0.16, 1, 0.3, 1) | state changes, light, chips, captions (Theme.arrive / settle) |
| `--e-leave` | cubic-bezier(0.42, 0, 1, 1) (ease-in) | rows leaving (Theme.leave) |
| `--e-perk` | spring, 0.45 s, bounce 0.25 (one overshoot) | done face, Undo return, pill press release (Theme.perk) |
| `--e-hop` | spring, 0.5 s, bounce 0.3 | the hop pose (Theme.hop) |
| `--d-feedback` | 120 ms | hover, press, caption swap |
| `--d-state` | 220 ms | panel header, pill swap, chip hover |
| `--d-overlay` | 360 ms | popover open and close |
| `--d-exit` | 160 ms | one row leaving |
| `--d-count` | 600 ms | rolling numbers (Frees about, Freed up, star count) |
| `--d-stagger` | 80 ms, cap 5 | rows, refusal lines |
| `--d-blink` | 90 ms | eyelid |
| `--d-smile` | 1200 ms | smile hold before calm |
| `--d-light` | 900 ms | stage light cross-fade |

Springs on the web: `lib/spring.js` exports `perk` and `hop` as precomputed `linear()` CSS easing strings (generated once at build from a damped spring, 40 samples) plus GSAP `CustomEase` equivalents. Nothing bounces twice.

## 2. Motion grammar (four verbs; anything else is cut)

1. **breathe** · the face is alive at rest: blink every 4.5 to 7 s (random), a glance every third blink, nothing else. Ambient, tiny, only on faces in view.
2. **leave** · rows exit when Tidy up is pressed: each row fades and drops 6 px in `--d-exit`, `--e-leave`; delay by distance from the Tidy up pill (nearest first), 80 ms apart, cap 5; the list height closes on `--e-arrive` 220 ms after.
3. **settle** · every state change arrives with `--e-arrive` (header text, pills, light, captions) and the one product moment gets `--e-perk` (done face, Undo pill). Includes the stage light cross-fade (`--d-light`).
4. **push** · the camera. One scroll-scrubbed move on the stage: a dolly in from the whole slab to the face in the menu bar and back out. Transform only (`scale`, `translate`), origin at the face.

Not in the grammar, so not on the page: section fade-ups, parallax on text, marquees, split-text reveals, magnetic buttons, cursor followers, page transitions, intro, loader.

Control feedback (Q55) is not a verb, it is UI: hover tint 120 ms, press scale 0.98 (Theme pressed pill), focus ring instant.

## 3. Shared utilities (architect owns; section builders import)

`site/js/lib/`:
- `face.js` · `createFace(el, {pose, size, count, ring})` returns `{setPose(p), setCount(n), blink(), destroy()}`. Renders the pebble as inline SVG on a 22 x 22 viewBox: rounded rect 18 x 15 at (2, 3.5), r 7.5; eyes circles r 1.3, 3 pt apart, centred; poses exactly as StatusIcon.swift: calm (grey), blink (eyes become 0.6 pt tall lines for `--d-blink`), glance (eyes shift 1 pt toward the panel), light (green), heavy (amber, eyes r 1.6, body lifted 1 pt), working (eyes 0.6 pt lower, body scaleY .94 from bottom), done (eyes become smile arcs), hop (smile, lifted 2 pt on `--e-hop`), paused (grey, eyes closed lines, opacity .55). The architect reads `Sources/YouFixIt/StatusIcon.swift` for exact geometry and checks against `snapshots/icon-poses-*.png`. Count renders beside the face in Geist Mono 600 at 0.62 of face height, rolls on change (`roll.js`). Owns its own `breathe` loop via `ticker.js`, paused when offscreen (IntersectionObserver) or `document.hidden`.
- `ticker.js` · one `requestAnimationFrame` loop (GSAP ticker) for everything ambient; subscribers register `{tick, visible}`.
- `roll.js` · `rollNumber(el, from, to, {format, duration: 600})` for sizes and the star count; tabular digits, no layout shift (fixed `ch` width per string length).
- `stage-light.js` · `setLight(stageEl, mood)` with mood `none | amber | green`; cross-fades two pre-rendered radial layers' opacity (never re-paints gradients).
- `motion.js` · `prefersReduced()` live media query, `onReducedChange(cb)`; exports durations from tokens.
- `gate.js` · the email gate (section 5 spec), shared by hero, nav and finale.
- `stars.js` · fetch `https://api.github.com/repos/FreemanGT/YouFixIt` once per page load (cache in sessionStorage 10 min, try/catch), resolves `stargazers_count` or null; consumers show the number only when it is 25 or more.
- `spring.js` · as 1.4.

`site/vendor/`: `gsap.min.js` 3.13 and `ScrollTrigger.min.js` only (about 45 KB gz). No Lenis, no WebGL, no SplitText.

Single source constants: `site/js/lib/config.js` exports `DMG_URL`, `REPO_URL`, `SIGNUP_URL` (read from `<meta name="yf-signup">`), `VERSION = "0.5"` (not printed in the hero).

## 4. Global elements

### Nav (sticky, 56 px, `--pg-raised` at 82 % with `backdrop-filter: blur(16px) saturate(1.4)`, 1 px `--pg-line` bottom hairline that appears only after 8 px of scroll)
- Left: the live face (22 px, `face.js`, mirrors the hero demo's mood: heavy until the visitor tidies, then a single hop and calm) + wordmark "YouFixIt" (Instrument Sans 650, 17 px). Links to top.
- Right: two pills, 36 px tall. Tonal: "Star it on GitHub" with a drawn star glyph; when `stars.js` returns 25 or more, a Geist Mono count follows after a middle dot ("Star it on GitHub · 128" pattern). Opens REPO_URL in a new tab. Filled accent: "Download" (in the nav only, short form; everywhere else "Download YouFixIt"). Pressing it opens the gate in place under the nav (see 5.7) for first-time visitors; returning visitors download at once.
- No menu links. Seven screens scroll; anchors are not needed. Phone: face + wordmark left; "Download" pill right; the star pill moves to the hero and finale.

### Footer (one line, 56 px, `--pg-ink-2`, 14 px)
"© 2026 Yiftach Freeman · MIT License · Legal · GitHub". "Legal" links to `/legal.html` (FACTS legal lines, the email note). No sitemap, no newsletter.

### Intro
None. The page opens complete. (Dial 6 and the Local Store verdict.)

### Legal page
`site/legal.html`: plain text page with the three FACTS legal paragraphs, same nav and footer, no motion.

## 5. Screens (seven; each one screenful at 1440 x 900)

### 5.1 Hero · "What is it, right now?"

Layout, desktop (centred hero, Q27):
- Nav 56. Padding-top 48.
- H1, centred, `--t-hero`, max 980 px, two lines:
  **"A little face in your menu bar that tidies up your Mac."**
- Sub, centred, `--t-body` at 19 px, `--pg-ink-2`, max 620 px:
  **"It notices what you forgot was running, like Docker, simulators and old dev servers, and lets it go with one safe button. Free forever."** (26 words)
- 24 px gap. CTA row, centred, 48 px pills: filled "Download YouFixIt" (accent) · tonal "Star it on GitHub" (count when 25 or more).
- 12 px gap. Caption, 14 px, `--pg-ink-2`: "Free forever · macOS 14.4 or newer · Apple silicon and Intel".
- 32 px gap. **The stage** (starts at about y 420; cropped by the fold on purpose, Things borrow).

The stage (`#stage`, owned by the hero builder, also hosts the tour 5.2):
- A slab of display glass, 1200 x 640, radius 28, no bezel (Alcove borrow), 1 px inner hairline `rgba(0,0,0,.06)` / `rgba(255,255,255,.07)`.
- Wallpaper: no image. A quiet field: `--pg-sunk` base with a soft vertical light (linear 180deg, 6 % lighter at the top). Two stacked radial layers sit on it, both pre-rendered once: **amber light** (`radial-gradient(60% 55% at 50% 38%, color-mix(#EDA833 28%, transparent), transparent 70%)`) and **green light** (same shape, #259E80 22 %). Only their opacities change (`stage-light.js`). This is the signature: the face lights the room.
- Menu bar strip at true scale: 24 px tall, `rgba(255,255,255,.55)` light / `rgba(30,30,30,.55)` dark, blur 20. It is a crop of the right half of a menu bar, so nothing on its left (no Apple logo, ever). Right cluster, left to right with 14 px gaps: two neutral drawn glyphs (a rounded square "stage" glyph and a wifi glyph, SVG 16 px, 70 % ink), **the YouFixIt face** (22 px canvas, heavy pose, count "5"), a battery glyph, and the visitor's real local time in Geist Mono 13 px via `Intl.DateTimeFormat(undefined, {weekday: 'short', hour: 'numeric', minute: '2-digit'})`, updated each minute. The face sits at 50 % of the slab width, so the panel below it is centred under the headline.
- The panel hangs from the face: 380 px wide, top 8 px below the strip, centred on the face, radius 12, popover shadow, `--app-window`. Height: `min(560px, 100svh - panelTop - 24px)` clamped at 420 minimum, measured at load and resize; the list scrolls inside with the app's 28 px fade at its bottom edge (`mask-image`), `overscroll-behavior: contain`.
- Caption under the slab, left-aligned to the slab, 14 px `--pg-ink-2`: **"Example panel. On your Mac it lists what your Mac is actually carrying."** Above the panel, a quiet pointer note in 13 px, placed in the wallpaper 24 px left of the panel's Tidy up pill, with a drawn 1 px arrow: **"Go on, press it."** (removed after first press; never returns in that visit).

The panel, rebuilt from PopoverView.swift and FindingRow.swift (component `site/js/hero.js` + `site/css/hero.css`; DOM is real HTML, not an image):

Header (padding 16, gap 12): face 40 x 32 (heavy, amber) · title 17 px semibold rounded `--app-label` "Your Mac is working hard. Here's what you can let go." · sub 13 px `--app-label-2` "Letting these go helps right away."

List (each card radius 14, `--app-card`, padding 10, gap 6, min height 56; check 18 px filled `--app-tint` with white tick; icon well 28 px circle `--app-pill` with a drawn 14 px symbol in `--app-tint`; name 13 px semibold; why line 12 px `--app-label-2`; size pill right, Geist Mono 12 px on `--app-pill`):

Section label "Running now" + count badge "3":
1. Docker · "No containers running, nothing using it" · 3.7 GB · symbol: cube
2. iPhone 16 Pro · "iOS 26.1, idle since Wednesday" · 1.2 GB · symbol: phone
3. 3 leftover servers · "Ports 3000 to 5173, from finished coding sessions" · 640 MB · symbol: server

Section label "Taking up space" + badge "2":
4. Xcode build cache · "Xcode rebuilds this when needed" · 12.4 GB · symbol: hammer
5. setup-2.3.dmg · "An installer you already used" · 1.1 GB · symbol: disk

Collapsed row "Good to know" + badge "4", chevron right. Not operable in the demo (aria-disabled, tooltip-free); it is shown because the real panel shows it.

Pill: filled 44 px, full width, `--app-tint`, white "Tidy up" 15 px semibold rounded, return-key glyph at the right end (18 px rounded square `--app-key-on-accent`, drawn ⏎ arrow in SVG). Under it, 12 px `--app-label-2`, centred: "Frees about **5.5 GB** of memory and **13.5 GB** of space" (numbers in Geist Mono).

Footer (12 px `--app-label-2`): "Checked just now" left · right: sparkle + "Ask Claude" (`--app-tint-text`) · pause glyph · gear glyph. Ask Claude, pause and settings are drawn but inert in the demo (`aria-hidden`, `pointer-events: none`); Ask Claude is explained in 5.4.

Living component API (`hero.js` exports `mountPanel(root, {state, rows, onState})`):
- States: `heavy` (default) · `working` · `done` · `calm` (after the Undo window ends: header "Your Mac feels fine.", no sub line, face calm grey) · `restoring` (Undo in progress).
- Row checkboxes are real: unticking a row removes it from the totals; "Frees about" rolls (`roll.js`, 600 ms); the face count in the menu bar and the section badges update; with none ticked, the pill is disabled (`--app-pill` fill, `--app-label-2` text) and the line reads "Tick something to tidy it." No other row controls (Keep, Hide, sparkle) in the demo: one interactive idea per section.
- **Tidy up** (click, tap, or Return while focus is in the panel; the return glyph is true): 
  1. 0 ms · pill press scale 0.98 for 120 ms; header cross-fades to "Tidying up…" (`--d-state`), face goes `working`; menu bar face `working`.
  2. 120 ms · ticked rows **leave**, nearest to the pill first, 80 ms apart (5 rows: 120 to 440 ms), each 160 ms ease-in fade plus 6 px drop; empty sections collapse with their labels; list height closes on `--e-arrive` 220 ms.
  3. 700 ms · header becomes "Freed up **19 GB**" (number rolls up from 0 in 600 ms) and sub "Your Mac has more room to breathe."; face `done` with `--e-perk`; menu bar face `hop` once then `done`; count beside it rolls to nothing and fades. Pill swaps to tonal "Undo" with the tonal return glyph (`--d-state`); line: "You can undo for the next minute." The pointer note is removed.
  4. Light: amber layer opacity 1 to 0 and green 0 to 1 over 900 ms starting at 700 ms. Green holds for `--d-smile` 1.2 s then eases to 0.35 (a calm glow remains while in `done`).
  5. Focus moves to the Undo pill. A visually hidden live region says "Freed up 19 GB. Undo is available for one minute."
- **Undo** (click, tap, Return): rows return in original order, 80 ms apart, each on `--e-perk` from 6 px below; header back to heavy; face amber; light back to amber over 900 ms; Tidy up returns; focus to Tidy up. Undo works for 60 s exactly as the app (no progress bar: the app has none, so the replica has none). After 60 s the state becomes `calm`: Undo replaced by a quiet text button "Show the example again" (`--app-tint-text`, 13 px) that restores `heavy`.
- Example sizes are labelled as an example by the caption; totals: memory 3.7 + 1.2 + 0.64 = 5.5 GB; space 12.4 + 1.1 = 13.5 GB; freed 19 GB (the app adds both, as in the done snapshot).
- The demo never auto-plays. Nothing moves until pressed except **breathe** on the face.

Phone (390), the same idea redesigned:
- Nav 52. H1 40 px, centred, three lines, max 340. Sub 16 px, 3 to 4 lines. "Download YouFixIt" full-width 52 px pill; "Star it on GitHub" as a text link with the drawn star under it. Caption on one line, 13 px: "Free forever · macOS 14.4 or newer".
- Stage: the slab becomes 358 px wide, radius 22, full height of the panel plus strip; the strip shows only face, battery and clock. The panel is fluid: width 100 % minus 12 px, rows wrap the why line to two lines; max-height `min(520px, 100svh - 120px)`.
- First screen at 390 x 844 shows headline, sub, Download; the stage begins below the fold edge with the face and header peeking (complete as a poster).

Reduced motion (complete at rest; shorter and calmer, never a still edition):
- Rows cross-fade out together in 160 ms (no drop, no stagger); numbers jump without rolling; the light cross-fades in 300 ms and does not hold-then-dim; face changes pose without hop; blink stays (it is 90 ms and tiny); glance off.

### 5.2 The face, up close · "How does it tell me something's wrong?"

The camera move. Same `#stage` element, no second slab. Desktop only as a scrubbed scene; the phone gets its own version.

Structure (no GSAP pin, so no pin-spacer and no CLS): the hero section ends with `.stage-track`, a wrapper `height: calc(640px + 240vh)`; inside it `.stage-sticky` is `position: sticky; top: 64px`. The slab scrolls up with the page, sticks under the nav, and while stuck a ScrollTrigger (`scrub: 0.6`, start `top 64px`, end `bottom bottom`) drives one timeline `push` over progress 0 to 1. The visitor's last demo state is kept; the tour only borrows the menu bar face.

Timeline (progress → what happens; every point is a finished poster):
- 0.00 to 0.18 · the popover closes: panel opacity 1 to 0 and scale 1 to 0.97 from its top centre (like the app's overlay, reversed). Caption under the slab fades out.
- 0.10 to 0.40 · **push**: the slab's inner `.stage-world` scales 1 to 7 with `transform-origin` at the face's centre, then translates so the face lands at 66 % of the slab width, 46 % height. At 7x the 22 px face reads at about 150 px; the SVG keeps it crisp, glyphs and clock stay sharp as they slide off frame. The slab's outer frame and radius do not change (the window stays still; the world inside moves).
- 0.30 to 1.00 · four beats of copy on the left third of the slab (left 72 px, vertically centred, max 420 px wide). Each beat holds for 0.15 of progress; cross-fade 0.05 between beats (`opacity` and 8 px `y`, `--e-arrive` mapped to scrub). The face changes pose at each beat boundary (pose swaps are instant like the app, not scrubbed; a `--d-state` cross-fade of the eyes), and the light follows: none, green 0.5, amber 1, green 1 then 0.35.
- 0.92 to 1.00 · pull out: scale back to 1.8 so the menu bar reads again as the track ends and the next section scrolls in under it.

Beat copy (H2 is `--t-h2` at 36 px; line under it `--t-body` `--pg-ink-2`):
1. Face `calm` grey, blinks once on entry. **"It sits in your menu bar and keeps an eye on your Mac."** · "Grey like the icons next to it. Now and then it blinks."
2. Face `light` green, count "3". **"Green means a few things are idling."** · "The number is how many it found. Nothing changes until you press the button."
3. Face `heavy` amber, eyes wide, lifted 1 pt, count "5". **"Amber means your Mac is working hard right now."** · "Open it, read the list in plain words, press Tidy up."
4. Face `done`, one `hop` at beat entry. **"Then it smiles."** · "Apps come back with Undo for a minute. Anything from the disk goes to the Trash first."

(The heavy beat's count is the same "5" as the hero, so the visitor recognises the face from the panel they just used.)

Accessibility: beats are real text in DOM order in an `<ol>` (list markers hidden). Inactive beats are faded with `opacity` only, never `aria-hidden`, `display: none` or `visibility: hidden`, so a screen reader reads all four in order. Keyboard users scrolling with Space see the same posters.

Phone (390): no scale scrub. `.stage-sticky` becomes a 200 px tall sticky band at `top: 52px` holding the face at 120 px wide on the stage wallpaper with its light; the four beats are normal flowing blocks (each about 70svh, text left, 16 px gutters) scrolling under it; an IntersectionObserver (`rootMargin: -45% 0px -45% 0px`) sets the face pose and light per beat. Native scroll, no scrub.

Reduced motion: no push. The section renders as four static rows, each with its own small face (64 px, the beat's pose, `createFace`) beside the beat text, and the light layer shown behind the row whose beat is amber or green at 0.5 opacity. Nothing sticks.

### 5.3 What it finds · "What will it actually close or clear?"

Layout, desktop: left-aligned in the 1200 column, padding 112 top and bottom, on `--pg-bg` (the stage light's last green glow fades into this section's top edge as a 240 px gradient, Q28 blended seams).
- H2 `--t-h2`: **"The stuff you forgot was running."**
- 32 px gap. The chip sentence, `--t-lede`, max 1000 px, chips inline (Hoy borrow). Each chip: inline-flex, height 1.25em, radius 14, `--pg-sunk` fill, 4 px 12 px 4 px 6 px padding, a 22 px icon well (the app's `--app-pill` circle with the same drawn symbol as the panel, in `--pg-accent-text`), label in Instrument Sans 500 at 0.82em. Chips are `<button type="button">` (focusable), no other action.

Exact sentence (chips in brackets):
**"It finds what you forgot was running: [Docker with no containers], [iPhone simulators nobody is using], [dev servers from finished coding sessions], [idle Gradle daemons] and [apps untouched for an hour]. And what's quietly taking space: [Xcode build caches], [Claude Code's scratch folders] and [installers you already used]."**

- 28 px gap. The why line (one shared line, `aria-live="polite"`, 17 px, `--pg-ink-2`, a 22 px `face.js` face in `light` pose at its start): shows the hovered or focused chip's real why line, as the app writes it. Default (nothing hovered): Docker's.

| Chip | Why line shown (from Copy.swift, example values) |
|---|---|
| Docker with no containers | "No containers running, nothing using it" |
| iPhone simulators nobody is using | "iOS 26.1, idle since Wednesday" |
| dev servers from finished coding sessions | "Port 3000 in my-app, from a finished coding session" |
| idle Gradle daemons | "Gradle starts a fresh one on the next build" |
| apps untouched for an hour | "Untouched since Wednesday" |
| Xcode build caches | "Xcode rebuilds this when needed" |
| Claude Code's scratch folders | "12 folders from sessions that ended days ago" |
| installers you already used | "An installer you already used" |

- 48 px gap. One closing line, `--t-body`, max 640: **"Everything else waits under Good to know, in plain words, most with a button of their own for when you decide. Nothing there is ever ticked for you."**

Animation (settle only): chip hover/focus lifts 1 px and fills `--pg-line`-darker (120 ms); the why line cross-fades (opacity 0 to 1, 4 px y) in `--d-state`, `--e-arrive`; its face glances toward the line on change. Nothing animates on scroll.

Phone: H2 30 px. Sentence 22 px / 1.5, chips wrap naturally; the why line becomes sticky at the bottom of the section viewport (`position: sticky; bottom: 16px`) as a small raised bar (radius 14, `--pg-raised`, 1 px line) so a tapped chip's line is always visible. Tap = focus = shows the line.

Reduced motion: the why line swaps without the 4 px move; no lift.

### 5.4 Safe by design · "Can I trust it with my Mac?"

Questions answered: will it close something I need, will it delete things, and how do I check before I press.

Layout, desktop: two columns inside 1200 (5/7 split, 48 px gap), on `--pg-bg`.

Left column (sticky at top 120 inside the section, native sticky):
- H2: **"It would rather leave it."**
- `--t-body`, `--pg-ink-2`, three short paragraphs, 16 px apart:
  - "Nothing changes until you press the button. Apps are quit the normal way, so they can ask to save. It never force-quits anything."
  - "Anything it clears from the disk goes to the Trash first. Apps it closed come back with Undo for a minute."
  - "It never closes what's in front of you, what's playing audio, terminals, editors, browsers or password managers. It never touches anything that belongs to macOS."

Right column: **the refusals**, a stack of real panel rows in the app's own style (`--app-window` tray, radius 12, popover shadow, 380 px wide, the panel's system font). No header (the app has no screen that lists refusals together, so the tray does not pretend to be one): six cards on the window background, each card with a grey icon well, a name and the app's real refusal line as the why line:
1. Your editor · "You're using it right now, so it stays."
2. A music player · "It's playing audio, so it stays."
3. Terminal · "It holds terminal sessions, so it stays."
4. A local database · "Something is connected to it, so it stays."
5. Spotlight · "Part of macOS, so it stays."
6. Drawing app · "Drawing app asked to save first, so it stayed open." (Copy.askedToSave)

Under the tray, 13 px `--pg-ink-2`: "Example rows. These are the lines it writes when it leaves something alone."

Then, below both columns, full 1200 width, one row with a hairline above it, **Ask Claude**:
- Left: a 44 px tonal circle with the app's sparkle glyph drawn in `--pg-accent-text`.
- H3 Instrument Sans 600, 24 px: **"Not sure about one? Ask Claude."**
- `--t-body` `--pg-ink-2`, max 640: **"Every row has a sparkle. It opens a new Claude chat with the question already written: what the thing is, what YouFixIt's button would do, and the folders or command lines behind it. Your home folder shows as ~, and anything that looks like a password or token is blanked out. Claude gets the question. Your Mac only changes when you press YouFixIt's own button."**

Animation (settle): when the tray first reaches 30 % into the viewport, the six rows **settle** in once, 80 ms apart (cap 5, the sixth with the fifth), from opacity 0.4 and 6 px below to rest, on `--e-arrive` 360 ms. They start at opacity 0.4 (never 0): complete at rest even before the trigger. Nothing else.

Phone: one column; the left text first (not sticky), then the tray at full width (fluid, 358 px), then Ask Claude stacked (sparkle above the heading).

Reduced motion: rows render at rest, no settle.

### 5.5 Free forever · "What does it cost me, and what's the catch?"

Layout, desktop: full-bleed `--pg-sunk` band (the page's one material shift; seams blend over 120 px gradients top and bottom, Q28). Inside the 1200 column, left-aligned.
- `--t-big` in Fredoka, one line: **"Free forever."**
- 16 px gap. H2-size line in Instrument Sans 500, 32 px, `--pg-ink`: **"A gift to the community. Open source, MIT License."**
- 40 px gap. Plain facts as a two-column definition list (no cards, no icons; 1 px `--pg-line` between rows, row height 56, term 15 px `--pg-ink-2` width 220, value 18 px `--pg-ink`):
  - Price · "Free. No trial, no paid tier, no account."
  - The app · "Never goes online. No analytics. Ask Claude hands its question to the Claude app or claude.ai in your browser."
  - Your Mac · "macOS 14.4 or newer. Apple silicon and Intel."
  - Signed · "Developer ID signed and notarized by Apple."
  - Permissions · "Not sandboxed, because it has to see other processes to help with them. Not on the Mac App Store."
  - This site · "No cookies, no analytics. The email you type goes to one Google Sheet the maker reads."
- 40 px gap. One row: tonal pill "Star it on GitHub" (48 px, drawn star; live count after a middle dot when 25 or more, Geist Mono, rolls up on first view, `roll.js`) · text link "Read the source" to REPO_URL. A one-line note after the pill, 15 px `--pg-ink-2`: "A star helps other people find it."

Animation: the star glyph in the pill does one **settle** flourish on first pointerenter (rotates 0 to 72deg on `--e-perk`, then the class is removed; Alcove borrow). That is the only motion here.

Phone: "Free forever." at 64 px on two lines if needed ("Free / forever."); list rows stack term over value; pill full width.

Reduced motion: no star flourish; the count appears without rolling.

### 5.6 Questions · "What else should I know?"

Layout: left-aligned in the 1200 column, H2 **"Questions, answered plainly."** on the left third (sticky top 120), the rows on the right two thirds (max 720). Plain `<details>` rows, 1 px hairlines, summary 19 px Instrument Sans 550, answer `--t-body` `--pg-ink-2`, chevron drawn, rotates 90deg in 220 ms. No cards. FAQPage JSON-LD built from the same text at build time (`build.mjs` reads the section HTML).

Rows (exact):
1. **"Does it delete my files?"** · "No. Anything it clears from the disk goes to the Trash first. Deleting for good, like emptying the Trash, only happens from a button you press, and that button asks first, right in the row."
2. **"What if it closes something I needed?"** · "Press Undo. Apps it closed open again for a minute after a tidy. Apps are quit the normal way, so they can ask to save first."
3. **"Why is it free?"** · "It's a gift to the community. It's open source under the MIT License, and it stays free."
4. **"Does it send anything anywhere?"** · "The app never goes online. No account, no analytics. Ask Claude only opens a Claude chat with the question already written."
5. **"Which Macs does it run on?"** · "macOS 14.4 or newer, on Apple silicon and Intel."
6. **"Why isn't it on the Mac App Store?"** · "It has to see other processes to help with them, so it can't be sandboxed. It is signed with a Developer ID and notarized by Apple."
7. **"How do I install it?"** · "Open the disk image and drag YouFixIt to Applications. Its face shows up in your menu bar."
8. **"How do I remove it?"** · "Choose Quit YouFixIt in its settings, then move YouFixIt from Applications to the Trash."

Verified 2026-11-15: "Quit YouFixIt" is Copy.quit in settings; Ask Claude opens the chat with the question already written (README). Row 7's "Its face shows up in your menu bar" is true of any launch; keep.

Animation: `<details>` open uses `interpolate-size: allow-keywords` + `height` transition 220 ms `--e-arrive` where supported; instant elsewhere. Nothing else.

Phone: H2 above the rows, not sticky; rows full width.

### 5.7 Finale · "Where do I get it?"

The big idea returns: the face and its light, at the size of the page.

Layout, desktop: one screen, centred (the hero and the finale are the two centred screens), on `--pg-bg` with the stage light reused behind the content at full section width (the same two radial layers, scaled to 900 px).
- The face, `createFace`, 160 px wide, `heavy` amber with count "5", the amber light on. When the gate's download starts, or when the visitor presses the face itself (it is a `<button aria-label="Tidy up the face">`), it does the hero's arc in miniature: `working` 300 ms, then `done` with `hop`, light amber to green over 900 ms, count rolls to nothing. Pressing it again resets to heavy after 1.2 s. One press, one smile.
- 32 px gap. `--t-big` Fredoka, centred, one line: **"Let it go."** (the panel's own words, "Here's what you can let go.", returned as the last word).
- 24 px gap. Sub 19 px `--pg-ink-2`: "Free forever. A gift to the community."
- 32 px gap. **The gate**, inline (no modal): a 56 px pill-shaped field group, 460 px wide: email input (16 px, placeholder "you@example.com", `autocomplete="email"`, `inputmode="email"`, visible label above it "Your email, then the download starts") + filled accent button "Download YouFixIt" with the return-key glyph. Under it, 13 px `--pg-ink-2`: "It goes to one Google Sheet the maker reads, to say hello and share news, rarely. Ask and you're off it." Then the tonal "Star it on GitHub" pill, centred, 16 px below.
- Footer follows.

The gate (`lib/gate.js`, used by hero, nav and finale):
- Every gate opens in place; nothing scrolls the visitor away. Hero: the "Download YouFixIt" pill expands (width transition 220 ms) into the field group with the same button at its end and focus in the field; the star pill steps down a line. Nav: a 64 px raised sheet slides down under the nav (`--d-overlay`, `--e-arrive`) with the same field group; Escape closes it.
- Valid email (`/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/`), Return or press: `navigator.sendBeacon(SIGNUP_URL, new URLSearchParams({type: 'mac', email, name: '', platform: 'YouFixIt · ' + platformString, ref: document.referrer, company: honeypotValue}))`, falling back to `fetch(SIGNUP_URL, {method: 'POST', mode: 'no-cors', keepalive: true, body})`; then, in the same tick, `location.href = DMG_URL`. The download never waits on the network. Store the email in `localStorage` (`yf-email`, try/catch); a returning visitor's Download press downloads at once and sends nothing again.
- After start: the button label becomes "Downloading" with a still drawn arrow (no spinner), and a line replaces the note: "If it didn't start, download it here." (link to DMG_URL). Then: "Open the disk image and drag YouFixIt to Applications." The finale face smiles (see above). The nav face hops once.
- Invalid: inline, `aria-describedby`, 14 px in `--pg-ink` with a small amber face beside it (the app's own heavy face, not a red warning): "That email looks incomplete. Add the part after the @." (or "Add your email first." when empty). Never red, never a shake.
- Honeypot `company` input: off-screen, `tabindex="-1"`, `autocomplete="off"`, `aria-hidden="true"`.
- `platformString`: "Mac" when `navigator.userAgentData?.platform` or UA says Mac, else "Other". Visitors on a phone still get the email step; after it, the line reads "It's a Mac app. Open this page on your Mac to install it." and the DMG is not started on iOS/Android (link still offered).

Phone: face 112 px; the finale line at 56 px on three lines; the gate stacks: field full width (52 px), button full width under it.

Reduced motion: the face swaps poses without hop; light cross-fades in 300 ms; the nav sheet appears without sliding.

## 6. Performance plan

- Budget: JS at or under 70 KB gz total (GSAP core + ScrollTrigger about 45 KB, own modules about 20 KB), well under the 350 KB ceiling. CSS at or under 24 KB gz. Fonts at or under 110 KB. No images on the page except the OG image (meta only); every glyph and icon is inline SVG. Target LCP (the H1) under 1.5 s on 4G, CLS 0, INP under 100 ms.
- Loading: `index.html` inlines critical CSS for nav and hero (tokens, base, hero) at or under 14 KB; other section CSS loads with `media="print" onload` swap. `main.js` is a module that imports `hero.js` first; GSAP and ScrollTrigger load with `<link rel="modulepreload">` and are only initialised for the tour when `(min-width: 900px)` and not reduced motion. Everything else lazy-imports per section on first IntersectionObserver hit (`rootMargin: 600px`).
- One ticker: `face.js` breathe loops and `roll.js` share `gsap.ticker`; each face unsubscribes when offscreen or `document.hidden`. No idle CPU when nothing is in view (QA: 0 long tasks over 3 s idle).
- Animate only `transform`, `opacity` and (for the nav sheet) `clip-path`. The stage lights are two fixed gradient layers whose opacity changes; the push scales one composited layer (`will-change: transform` only while the tour is in range, removed after).
- No CLS: the panel's height is reserved from first paint (CSS `height` from the clamp formula, recomputed on resize only); sticky instead of pin spacers; fonts with metric-matched fallbacks; the clock and star count have fixed-width slots.
- Third parties: only `api.github.com` (stars, client-side, after load, `requestIdleCallback`) and `script.google.com` (on gate submit). No analytics, no cookies, no consent banner.
- `vercel.json`: `cleanUrls: true`; `Cache-Control: public, max-age=31536000, immutable` for `/fonts/*`, `/vendor/*`, and fingerprinted `/css/*` `/js/*` (build.mjs appends `?v=<hash>`); `max-age=0, must-revalidate` for HTML; `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy: interest-cohort=()`. No `/download` redirect: the email is required before the file (Q94).

## 7. SEO and sharing

- `<title>`: "YouFixIt · A little face in your menu bar that tidies up your Mac". Description (155 chars max): "A free, open-source Mac menu bar app. It notices what you forgot was running, like Docker, simulators and old dev servers, and tidies it with one safe button."
- Canonical `https://getyoufixit.vercel.app/`. OG 1200 x 630 from `web/og.html`: the stone paper, the amber-lit slab crop with the menu bar face (heavy, count 5) at 6x on the right, and on the left in Fredoka 72 px "A little face that tidies up your Mac." plus 24 px "Free forever · macOS". Rendered with headless Chrome to `site/og.png`. Twitter card `summary_large_image`.
- JSON-LD: `SoftwareApplication` (name, operatingSystem "macOS 14.4 or later", applicationCategory "UtilitiesApplication", offers price 0 USD, license MIT URL, downloadUrl DMG_URL, codeRepository via `sameAs` REPO_URL) and `FAQPage` from 5.6.
- Favicon: the face (calm green) as SVG + 32 px PNG; dark-mode aware SVG.

## 8. Section ownership (for parallel builders)

| id | Section | Files | Notes |
|---|---|---|---|
| `hero` | 5.1 + 5.2 (one stage element) | `sections/hero.html`, `css/hero.css`, `js/hero.js`, `js/tour.js` | one builder; the tour reads the stage DOM |
| `finds` | 5.3 | `sections/finds.html`, `css/finds.css`, `js/finds.js` | |
| `safe` | 5.4 | `sections/safe.html`, `css/safe.css`, `js/safe.js` | |
| `free` | 5.5 | `sections/free.html`, `css/free.css`, `js/free.js` | uses `stars.js` |
| `faq` | 5.6 | `sections/faq.html`, `css/faq.css` | JSON-LD generated by build.mjs |
| `finale` | 5.7 | `sections/finale.html`, `css/finale.css`, `js/finale.js` | uses `gate.js`, `face.js`, `stage-light.js` |
| architect | tokens, base, nav, footer, legal, lib/*, vendor, template, build, vercel.json, OG | | |

## 9. QA the critics should run

- 1440 x 900 first screen: headline, sub, both pills and the whole panel including Tidy up visible. 390 x 844: headline, sub, Download visible.
- Press Tidy up with mouse, with Return (focus in panel), and by tap; Undo the same three ways; uncheck all rows and see the disabled pill line.
- Tour: scroll steps 0, 0.25, 0.5, 0.75, 1 of the track are each a finished poster; no CLS on stick and unstick.
- Reduced motion: every section readable with nothing hidden; no push; rows settle at rest.
- 320 px: no horizontal overflow (panel fluid, chips wrap, gate stacks).
- Contrast pairs in 1.2 re-verified in the browser in both themes, including amber face ring in light.
- Copy check: no em dashes, no exclamation marks, no rhetorical questions in body copy (FAQ questions are questions a visitor asks), no banned words, "YouFixIt" spelled right everywhere, every row labelled as an example.
