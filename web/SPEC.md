# SPEC · YouFixIt launch site (master)

The ECD's single spec. It overrides `web/specs/itself.md`, `stage.md` and `type.md` wherever they differ; where this file is silent, `specs/itself.md` (the base) applies. FACTS (`web/FACTS.md`) beats everything; BRIEF (`web/BRIEF.md`) beats any skill.
Canonical: https://getyoufixit.vercel.app/ · Repo: https://github.com/FreemanGT/YouFixIt · Ship: no checkpoint.

## A. Scores (1 to 10)

| Lead | Originality | Story clarity | Conversion | 60fps | Fit to brief | Relevance | Total |
|---|---|---|---|---|---|---|---|
| **itself** (the site has the app in its own menu bar) | 9 | 9 | 8 | 9 | 9 | 8 | **52** |
| type (the headline sheds weight) | 8 | 8 | 7 | 7 | 7 | 8 | 45 |
| stage (the face is the light; camera push) | 7 | 8 | 8 | 6 | 6 | 7 | 42 |

### Rationale
- **itself wins.** Its idea is the product's real behaviour, not a metaphor of it: a pebble in a menu bar that you click, a popover that hangs from it, a state you change with Tidy up, and the whole page (its light, its tab icon, its menu bar count) changing mood with you. A stranger reads "menu bar app" in one glance because the nav literally is one. No scroll show, no pinned tour, nothing moves unless the app would move it. It is the calmest of the three and the most original. Juror line: **"The website has YouFixIt in its own menu bar. Press Tidy up and the page you're on calms down, even its tab icon."**
- **type** has the second-best idea (weight as load) and the best small details (the pebble as the full stop, the docked example row, honest phone behaviour). The shed itself is cut: a second signature system would fight the first, Recursive's casual axis tips toward comic, and animating 13 words of variable font is the riskiest paint on the page. Its "Freed up 24.6 GB" also breaks the app's own `Format.size` (10 GB and up has no decimal).
- **stage** is the most conventional (centred headline over a framed screen) and its centrepiece, a 240vh scrubbed 7x camera push, is exactly the "scroll show before any use" the client hated on Local Store. Its fake menu bar items (wifi, battery, a clock) are costume. Its plain-facts list, its scrolling panel list on phones and its amber-ring contrast fix are good and are grafted.

### Base and grafts
Base: **itself**, five screens: `hero` · `finds` · `never` · `faq` · `finale`. (`face` was cut in review: three columns of pebbles is the three-icon how-it-works with faces, and three more breathing faces is motion everywhere. Its one sentence lives in `finds`.)
Grafts (each named where it lands):
1. **The pebble is the full stop** of the finale's "Free forever." (type). It replaces itself's separate 180 px finale pebble: one object, and it still remembers what you did on the page (itself).
2. **A docked example row** in `finds` (type) replaces itself's floating chip bubbles: hover, focus or tap a chip and one app row beside the sentence swaps to that thing, written as the app writes it. Bubbles over running text clip on phones and cover what you're reading.
3. **The phone panel scrolls like the app** (stage): fixed max height, list scrolls inside with the app's 28 px bottom fade, Tidy up always in view. Replaces itself's invented "Taking up space · 2" collapse row, which the app does not have.
4. **Amber legibility fix** (stage): in light mode the amber pebble on paper gets a 1 px inner ring `#A8721A`; state is never told by colour alone (eyes, lift, count, header sentence).
5. **Return inside the panel only**: Return runs Tidy up or Undo only while focus is inside the panel, never from `body` (a stray click in the text column must not tidy) and never while typing. The pill's return-key glyph says it; the hint says only "Press Tidy up."
6. **Honest phones and returning visitors** (stage, type): on iPhone or Android the gate still takes the email but does not start the DMG; it says "YouFixIt is a Mac app. Open this page on your Mac to install it." with a direct link. A `sent` flag in localStorage so a returning visitor downloads in one press and nothing is sent twice.

## B. Cut, and why (nobody adds these back)
- **Camera push tour, any scroll-pinned scene** (stage): scroll show before use, 240vh of track, the Local Store verdict. The hero panel already shows every state by touch.
- **The headline shedding weight, Recursive** (type): a second signature system; comic risk; paint cost.
- **Fake menu bar items**: wifi, battery, clock, Apple menu, other apps' icons. Costume, and Apple marks are banned.
- **Fredoka** (stage): rounded display reads as a toy next to a toy-like face.
- **Mint full-bleed finale** (type): the haze is the page's one colour moment; a second is noise.
- **A `/download` redirect that skips the email** (type): the client asked for the email before the download.
- **A separate "Free forever" facts band** (stage): it would be another screen. Its facts live in the FAQ and the finale's requirements line. Fewer, better screens.
- **Chip bubbles** (itself), **Hide** and **Keep** on rows (Keep in the app keeps for good; faking it invents behaviour), the row sparkle (one Ask Claude note, footer only), pause and gear tooltips, the Tidy up "pre-shed" hover, the "Go on, press it." arrow note, the nav pebble glancing at the `finds` card, a pressable finale period: one interactive idea per place.
- **The `face` section** (itself): three columns of pebbles is the banned three-icon how-it-works, a mostly empty 80vh, and three more breathing faces. One sentence with three still inline pebbles in `finds` says the same.
- **A full-page amber haze**: a 120vmax amber wash over warm paper drifts into the banned claude.ai ivory and greets everyone with the struggling mood. The light is now small and only around the pebble (§I.2).
- **Intro, loader, scroll reveals, parallax, split text, marquee, custom cursor, smooth-scroll library, dark-mode toggle, device frame or laptop render, feature grid, three-icon how-it-works, stat counters, testimonials, logos, ratings, newsletter, eyebrows, section numbers, scroll meters, version in the hero, red or warning copy, analytics, cookie banner.**
- **Copy cut**: "Safari has about 40 tabs open" in the demo's Good to know (it implies the visitor's browser); replaced with the app's Photos line.

## C. The one idea, concretely
- The nav is drawn as a Mac menu bar strip: the page is the desktop. Nothing fake is in it: wordmark, Star it on GitHub, Download, and the live YouFixIt pebble with its count at the right end.
- On the first screen the 380 px example panel hangs from that pebble as the real popover does, and it works: Tidy up, Undo, row checks, Good to know, and one Ask Claude note in its footer. Every view of the example says it is an example.
- The face's light falls around it: a small amber glow at the pebble while the example Mac works hard, green after Tidy up, none when calm. The favicon is the pebble in the same pose. Tidy up changes the panel, the menu bar count, the page's light and the browser tab together.
- Scroll past the hero and the panel folds back into the pebble like a popover closing. Click the pebble anywhere on the page and it opens again.
- At the end, the full stop of "Free forever." is the pebble, and it remembers whether you tidied. It is not a control; it only looks.

Everything else is quiet. The only motion on the page is the app's own.

## D. Design tokens (`site/css/tokens.css`, architect)

Light and dark both designed, following `prefers-color-scheme`; no toggle.

### D.1 Faces (self-hosted variable subsets, `site/fonts/`, total at or under 120 KB woff2)
| Role | Package | Axes | Use |
|---|---|---|---|
| Display | `@fontsource-variable/bricolage-grotesque` | opsz 12 to 96, wdth 75 to 100, wght 200 to 800 | H1, H2s, the finale's giant line, the `finds` sentence. Soft terminals read like the pebble's rounded edge: a grotesk with a grin. |
| Body and UI | `@fontsource-variable/mona-sans` | wdth 100 to 112, wght 400 to 650 | running text, buttons (wdth 106, wght 600), labels, FAQ |
| Data | `@fontsource-variable/geist-mono` | wght 400 to 500 | numbers only: the menu bar count, the star count, sizes outside the panel. Lazy, `font-display: swap`. |
| Panel replica | system stack: `ui-rounded, "SF Pro Rounded", system-ui, -apple-system, "Mona Sans Variable", sans-serif` for title, hero line, pill; `system-ui, -apple-system, "Mona Sans Variable", sans-serif` for body | as the app | inside the rebuilt panel and every app-row replica only (BRIEF §6) |

Architect: confirm Bricolage was not the display face of Claude Meter or Notched (profile Q29); if it was, swap the display role to Anybody (wdth 75 to 125) with the same scale. Subsets: Latin basic, Latin-1, curly quotes, ellipsis, middle dot. Metric fallbacks `"Bricolage Fallback"` and `"Mona Fallback"` on `local("Arial")` with computed `size-adjust`, `ascent-override`, `descent-override`. Preload Bricolage and Mona only.

Scale (desktop / 390): `--t-hero` 4.5rem / 1.75rem (four lines at 390, so the panel fits on the first screen), Bricolage opsz 96 wght 640 wdth 92, leading 1.02, tracking -0.025em · `--t-h2` 3rem / 2rem, opsz 72 wght 600 wdth 96, leading 1.05, tracking -0.02em · `--t-giant` clamp(5.5rem, 19vw, 17rem), opsz 96 wght 760 wdth 75, leading 0.9, tracking -0.03em (finale only) · `--t-sentence` 1.75rem / 1.375rem, Bricolage opsz 32 wght 480, leading 1.5 (`finds`) · `--t-lead` 1.25rem / 1.125rem, Mona 430, leading 1.45 · `--t-body` 1.0625rem / 1rem, Mona 420, leading 1.55 · `--t-small` 0.875rem, Mona 450, leading 1.4 · `--t-btn` 1rem, Mona 600 wdth 106 · `--t-data` 0.9375rem, Geist Mono 450, `tabular-nums`. Sentence case everywhere; no uppercase, no italics, no eyebrows.

### D.2 Colour (one material, bone paper; the product's green and amber are the only colour)
| Token | Light | Dark | Contrast (recorded; architect re-verifies in the browser) |
|---|---|---|---|
| `--paper` | #F2F3F1 | #111312 | base (cooled from #F4F3EE in review, away from claude.ai ivory; architect re-measures every pair below) |
| `--paper-2` | #E8E9E6 | #181B19 | FAQ and finale tone (one blended seam) |
| `--ink` | #191B1A | #ECEDE8 | 15.58 / 15.85 on paper · 14.23 / 14.60 on paper-2 |
| `--ink-2` | #565C59 | #9CA29E | 6.16 / 7.17 on paper · 5.62 / 6.61 on paper-2 |
| `--line` | #DEDDD6 | #262A28 | hairlines, non-text |
| `--go` | #177D66 | #19846B | white on it 5.05 / 4.61 (15 px+ semibold) |
| `--go-text` | #136B57 | #66CCAB | 5.78 / 9.59 on paper · 5.17 / 6.27 on tonal |
| `--go-tonal` | #DFE9E4 | #1F2E28 | tonal pills (Star, Undo) |
| `--face-green` | #259E80 | #259E80 | graphic 3.01 / 5.58 on paper |
| `--face-amber` | #EDA833 | #EDA833 | graphic 1.85 light (fails) → 1 px inner ring `#A8721A` in light mode only · 9.11 dark |
| `--face-calm` | `--ink` | `--ink` | the menu bar's monochrome |
| `--haze-amber` | rgba(237,168,51,.08) | rgba(237,168,51,.08) | the pebble's light; composite at its centre #F2EDE2 light, fading to paper within 50vmax. Architect renders it and checks it against the Q43 ban before shipping. |
| `--haze-green` | rgba(37,158,128,.08) | rgba(37,158,128,.10) | the pebble's light |
| `--bar` | rgba(242,243,241,.72) | rgba(17,19,18,.66) | menu bar + `backdrop-filter: saturate(1.6) blur(20px)` |

Panel replica `--p-*` (from Theme.swift; the panel never borrows site colours): light window #ECECEC, card rgba(0,0,0,.055), card hover rgba(0,0,0,.09), pill rgba(0,0,0,.08), text #1D1D1F (14.25), secondary #5E5E62 (verify ≥ 4.5 on card), tint #177D66, tonal rgba(23,125,102,.14), tonal text #136B57 (5.17), amber face #D99A2B, key on accent rgba(255,255,255,.22). Dark: window #2A2A2C, card rgba(255,255,255,.085), hover .13, text #F5F5F7, secondary #ADADB2 (lifted; #A1A1A6 measured 4.41), tint #19846B, tint text #66CCAB, amber face #F0B445. Sample `snapshots/heavy-*.png` and `done-*.png` to match.
Popover shadow (the only shadow on the site): `0 0 0 .5px rgba(0,0,0,.18), 0 18px 50px -12px rgba(0,0,0,.28)` light; `0 0 0 .5px rgba(255,255,255,.12), 0 18px 50px -12px rgba(0,0,0,.6)` dark.
Accent rule (Q47): `--go` only on Download, Tidy up, focus rings, the Star link. Amber only on the face and its light. Nothing decorative is green. Banned palettes checked: no cream plus terracotta, no near-black plus acid green, no Anthropic amber as brand (amber is the app's heavy state and only ever the face).

### D.3 Radii, space, sizes
`--r-card` 14 · `--r-panel` 12 · `--r-chip` 10 · `--r-pill` 999 · `--r-key` 5. 4 px grid. Column 1200 max; gutters 24 desktop, 16 at ≤ 720. Section padding block 9rem desktop, 5.5rem at 390. Menu bar 36 px desktop, 48 px at ≤ 720. Menu bar pebble 24 × 20 css px on a 30 px hit target (44 px on touch).

### D.4 Easing and durations (ported from Theme.swift; nothing else allowed)
`--ease-arrive` cubic-bezier(.16,1,.3,1) · `--ease-leave` cubic-bezier(.42,0,1,1) · `--d-feedback` 120ms · `--d-state` 220ms · `--d-overlay` 360ms · `--d-exit` 160ms · `--d-count` 600ms · `--d-stagger` 80ms (cap 5) · `--d-blink` 90ms · `--d-smile` 1200ms · `--d-haze` 600ms. Springs `perk` (0.45 s, bounce 0.25, one overshoot about 6 %) and `hop` (0.5 s, bounce 0.3) as precomputed CSS `linear()` strings plus GSAP `CustomEase` equivalents in `js/lib/motion.js`. Pressed pill scale .98 in 120ms. Hover on every control: tone shift plus 1 px lift in 150ms (Q55). Nothing bounces twice.

## E. Motion grammar (four verbs; anything else is cut)
1. **breathe** · the pebble idles like the real icon: blink (eyes to slits, 90ms) every 4 to 7 s at random; a glance (eyes 1 unit aside, 600ms) every third or fourth blink. Only pebbles on screen; never two blinking within 400ms of each other.
2. **perk** · the `perk` spring on a state change: pebble pose swap, count badges, panel header swap, Undo pill arriving, gate button state. `hop` is the same verb at the hop spring (done face, finale period).
3. **leave** · rows exit on Tidy up: fade and 8 px up while the height collapses (`grid-template-rows: 1fr → 0fr` wrapper), 160ms `--ease-leave`; delay by distance from the Tidy up pill, nearest first, 80ms steps, cap 5. Undo plays it back top-down with `--ease-arrive` 220ms.
4. **fold** · the popover opens out of the pebble and folds back into it: origin at the pebble's centre, scale .94 ↔ 1 plus opacity; open 360ms arrive, close 160ms leave. Used for the hero scroll-away, every pebble click, Escape, the `finds` example row swap (at .97, 220ms) and FAQ rows (height only).
The haze is the face's light, not a verb: it crossfades with the pose over `--d-haze`.

## F. Shared utilities (architect: `site/js/main.js`, `site/js/lib/*`, `site/css/base.css`)
- `store.js` · the one example state machine (§H). `get()`, `subscribe(fn)`, `dispatch(action)`. No storage.
- `format.js` · `size(bytes)` ported exactly from `Copy.swift` `Format.size`: under 1000 MiB → "N MB"; else GB with one decimal only when under 10 GB and not within .05 of whole ("21 GB", "5.6 GB", "15 GB"). Every number in the demo is computed through it.
- `pebble.js` · `renderPebble(el, {pose, count, size, ring})` builds the inline SVG (§G.1) and swaps poses with `perk`; `breathe(el)` registers with the one ticker behind an IntersectionObserver; `glanceAt(el, x, y)`.
- `motion.js` · `perk(el)`, `hop(el)`, `leave(els, originEl)`, `fold(el, originEl, open)`, each with a reduced variant (§L); eases and durations read from CSS custom properties; a live `reduced` boolean.
- `favicon.js` · `<link rel="icon">` follows the store as an SVG data URL of the pebble (calm #8A8F8C, green, amber, done smile). Static `favicon.svg` (calm) and `apple-touch-icon.png` 180 (green pebble on paper).
- `haze.js` · sets `html[data-mood]` (`heavy | working | done | calm`) from the store; CSS crossfades two layers by opacity.
- `signup.js` · `mountGate(formEl)` (§I.4), used in the hero and the finale.
- `stars.js` · one fetch of `https://api.github.com/repos/FreemanGT/YouFixIt` after load (`requestIdleCallback`, sessionStorage 10 min, try/catch); fills every `[data-stars]` with `stargazers_count` in Geist Mono only when ≥ 25, rolled in once over `--d-count`; otherwise and on failure nothing is shown and no gap is left.
- `config.js` · `DMG_URL`, `REPO_URL`, `SIGNUP_URL` (read from `<meta name="yf-signup">`), `VERSION = "0.5"` (never printed in the hero).
- Vendor: `site/vendor/gsap/` 3.13 core, `ScrollTrigger`, `CustomEase`. One ticker (`gsap.ticker`), paused on `document.hidden`. No other library.

## G. The living panel (hero builder: `site/css/panel.css`, `site/js/panel.js`)
Rebuilt in HTML and CSS from `PopoverView.swift`, `FindingRow.swift`, `Theme.swift`, `Copy.swift`; checked against `snapshots/heavy-*.png`, `working-mid-*.png`, `done-*.png`, `empty-*.png`, `know-open-*.png`, `hover-ask-*.png`, `icon-poses-*.png`. The heavy state is server-rendered in `index.html`, so it paints complete before JS.

### G.1 The pebble
Inline SVG, viewBox `0 0 22 22`: rounded rect x 2, y 3.5, w 18, h 15, rx 7.5 in the pose colour; eyes cut out with a `<mask>` (circles r 1.3, centres x 9.5 and 12.5, y 11). Poses from `StatusIcon.swift` (architect reads it for exact geometry): `calm` ink · `blink` eyes as 2.6 × .8 slits · `glance` eyes +1 x · `light` green · `heavy` amber, eyes r 1.6, body lifted 1 (light mode adds the `#A8721A` inner ring) · `working` eyes down 1, body scaleY .94 from the bottom · `done` smile arcs (stroke 1.2) · `hop` done plus lifted 2 · `paused` #8A8F8C at .7, eyes closed. Count: Geist Mono 13 px wght 500 `--ink` 4 px right of the face; rolls over `--d-count`. The panel header uses the same SVG at 40 × 32 with the in-app fills (`--p-amber`, `--p-tint`), drawn big as in the snapshots.

### G.2 Content (example rows; neutral names; why lines verbatim from Copy.swift)
Header (heavy): face 40 × 32 amber · title 17 px semibold rounded "Your Mac is working hard. Here's what you can let go." · sub 13 px secondary "Letting these go helps right away."
Running now · badge 3
1. phone glyph · "iPhone 17" · "iOS 26.1, idle since Wednesday" · 1.2 GB
2. cube glyph · "Docker" · "No containers running, nothing using it" · 3.7 GB
3. server glyph · "3 leftover servers" · "Ports 3000 to 5173, from finished coding sessions" · 690 MB
Taking up space · badge 2
4. hammer glyph · "Xcode build cache" · "Xcode rebuilds this when needed" · 14 GB
5. disk glyph · "An old installer" · "An installer you already used" · 1.1 GB
Good to know · badge 2, collapsed with a chevron; opens (fold, height only) to two plain lines from Copy: "Spotlight is building its search index. It finishes on its own." and "Photos is looking through your library. It finishes on its own, mostly while charging." Never selected, never counted.
Tidy up pill: 44 px, `--p-tint`, white 15 px semibold rounded, return-key glyph 18 px in a white 22 % key at its right end. Under it: "Frees about 5.6 GB of memory and 15 GB of space".
Footer: "Checked just now" · sparkle + "Ask Claude" (tint text) · pause glyph · gear glyph.
Sums through `format.size` (MiB): memory 1228.8 + 3788.8 + 690 = 5707.6 → "5.6 GB"; space 14336 + 1126.4 = 15462.4 → "15 GB"; freed 21170 → "21 GB". Tooltip "Example: YouFixIt, 5 things to tidy, about 21 GB". Unchecking a row recomputes all three and the count.

Row anatomy: check 18 px filled tint circle with a white tick (a `<button aria-pressed>` with a 44 px hit area) · icon well 28 px tint-14 % circle with a 14 px drawn stroke glyph (never SF Symbols files) · name 13 px semibold · why 12 px secondary (two lines max) · size pill 12 px system font, tabular nums, on `--p-pill`. Cards radius 14, padding 10, 6 px apart, no border.
Hover or focus on a row shows only the app's card hover fill (no Keep, no row sparkle). The footer Ask Claude is the panel's one note: pressed, a one-line note shows inside the panel for 6 s: "On your Mac this opens a new Claude chat with the question already written. Claude only gets the question." Nothing opens claude.ai from the site. Pause and gear are drawn as in the app but inert: not focusable, no tooltip, `aria-hidden="true"`.

The label (FACTS, required), under the panel, `--t-small` `--ink-2`: **"Example panel. On your Mac it lists what your Mac is actually carrying."**

### G.3 API
`mountPanel(rootEl, {store, mode: 'hero' | 'popover', anchor})` renders from `store.get()` and subscribes; the hero panel and the menu bar popover are two views of one state. `role="dialog"`, `aria-label="YouFixIt, example panel"`. Tab order: rows (checks) → Good to know → Tidy up / Undo → footer Ask Claude. Return runs Tidy up or Undo only while focus is inside the panel and not on another control; never from `body`, never while typing in a field. Escape closes the popover view. A polite live region speaks the app's tooltip strings, each prefixed "Example: ": "Example: YouFixIt, 5 things to tidy, about 21 GB" · "Example: YouFixIt, tidying up" · "Example: freed up 21 GB. You can undo for the next minute." · "Example: YouFixIt, your Mac feels fine".
**Every view of the store is labelled** (FACTS; the profile bans simulated activity): the hero panel and the popover view both render the example label under the panel; the menu bar pebble's accessible name and `title` are the prefixed tooltip string; the finale period's hidden text carries the same prefix. Nothing on the page may read as a scan of the visitor's own Mac.

## H. Example state machine (`store.js`)
`heavy` (initial) → `working` → `done` → after 60 s (Theme.undoWindow) `calm`. Undo from `done` → `heavy`. "Show the example again" from `calm` → `heavy`.
- **heavy**: menu bar pebble amber, count 5; header as G.2; haze amber; favicon amber.
- **working**: pebble `working`; header "Tidying up…" (the app's own ellipsis character); rows `leave`; count rolls down one per row; haze amber fades to green across the leave.
- **done**: header face smile, "Freed up 21 GB" (number rolls up over `--d-count`), sub "Your Mac has more room to breathe."; Good to know row stays; tonal "Undo" pill with the tinted return glyph; caption "You can undo for the next minute."; no Ask Claude in the footer (as `done-*.png`). Menu bar pebble `done` for `--d-smile`, one `hop`, stays `done`, no count. Haze green. Focus moves to Undo.
- **calm** (60 s after done): pebble calm, header face calm, "Nothing to tidy." + "Your Mac is doing great." and a quiet text button "Show the example again" (tint text, 13 px). No haze. Favicon calm.
Mood map for `html[data-mood]`: heavy → amber · working → amber→green · done → green · calm → none.

## I. Global elements (architect / integrator)

### I.1 The menu bar (the nav)
- `<header class="menubar">`, sticky top 0, full bleed, 36 px (48 px ≤ 720), `--bar` material, 1 px `--line` bottom hairline. It is the page's real nav; nothing fake in it.
- Left, on the 1200 column: wordmark "YouFixIt", Mona Sans 15 px wght 650, links to `#top`.
- Right, in order, 16 px apart: "Star it on GitHub" (text button: drawn star + words + `[data-stars]`) · "Download" (`--go` pill, 28 px tall; scrolls to the nearest email gate, hero if in view else finale, with `scrollIntoView({block:'center'})` and focuses its field; a returning visitor with a remembered email downloads at once) · the live pebble + count (`<button aria-haspopup="dialog" aria-expanded>`, accessible name and `title` = the current tooltip string with its "Example: " prefix, §G.3).
- At ≤ 720: wordmark left; right: the star glyph alone (accessible name "Star it on GitHub"), the Download pill, the pebble. Every target ≥ 44 × 44.
- Pebble click: while the hero panel is on screen it moves focus into the hero panel and the panel does one `perk` (no second copy on screen). Otherwise it `fold`s open the popover view under the pebble: right edge 16 px from the viewport edge, 8 px under the bar; at ≤ 720 a full-width sheet under the bar, max-height `calc(100svh - 64px)`, scrolling inside. Click outside, Escape or the pebble again folds it closed and returns focus to the pebble.

### I.2 The haze and the favicon
- The haze is the page's one colour moment (Q42): the pebble's own light, not a page tint. Two absolutely positioned layers inside the hero wrapper (not fixed), each one radial gradient: `radial-gradient(50vmax 36vmax at var(--pebble-x) 0, var(--haze-*) 0%, transparent 70%)`, `--pebble-x` measured from the nav pebble on load and resize. It lights the top-right of the hero around the pebble and the panel's head; the H1 sits on plain paper. Opacity crossfade only, `pointer-events: none`, `contain: strict`.
- In the finale a small local glow (not full bleed) sits behind the pebble period only (§finale).
- After the hero, the favicon and the menu bar pebble carry the mood alone.

### I.3 Footer and legal
- One line, `--t-small` `--ink-2`, centred at the finale's foot: "© 2026 Yiftach Freeman · Legal · Source on GitHub".
- `/legal/index.html`: the menu bar (no popover), the three FACTS legal lines verbatim, and the email note (what is collected: the email, the referrer, a platform string; where: a Google Sheet the maker reads; why: to say hello and share news about YouFixIt, rarely; a reply asking to be removed is honoured). No motion.
- `/404.html`: the pebble `paused`, "Nothing here. The page you wanted was tidied away, or never existed." and a link "Back to YouFixIt".

### I.4 The email gate (one component, hero and finale; `signup.js`, styles in `base.css`)
- `<form class="gate" novalidate>`: visible label "Your email" (`--t-small`, `--ink-2`), one `<input type="email" autocomplete="email" inputmode="email" required>` at 16 px, placeholder "you@example.com"; the honeypot `company` off-screen (`tabindex="-1"`, `autocomplete="off"`, `aria-hidden="true"`); submit pill "Download for Mac" with the return glyph at its right end (true: Return submits).
- At rest: field and pill in one 56 px capsule, max 480 px (field left, pill inside the right end). At 390 they stack: field 52 px, pill 52 px, both full width.
- One line under it, always visible, `--t-small` `--ink-2`: "Free. Your email goes to a sheet only the maker reads. The app itself never goes online."
- Validate on submit only (`/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/`). Empty: "Add your email first, then the download starts." Incomplete: "That email looks incomplete. Add the part after the @." Shown under the field with `role="alert"`, `aria-describedby`, `aria-invalid`, in `--ink` beside a 16 px amber heavy pebble (the app's own face, never red, never a shake), arriving with `perk`.
- Valid, all in the same task (the download never waits on the network): if this email has no `sent` flag, `navigator.sendBeacon(SIGNUP_URL, new URLSearchParams({type:'mac', email, name:'', platform:'YouFixIt · ' + platformString(), ref: document.referrer, company}))`, falling back to `fetch(SIGNUP_URL, {method:'POST', mode:'no-cors', keepalive:true, body})`; store `yf-email` and the `sent` flag in localStorage (try/catch); then `location.href = DMG_URL`.
- `platformString()`: "Mac Apple silicon" / "Mac Intel" / "Mac" / "iPhone" / "Android" / "Other", coarse, from `navigator.userAgentData` when present, else the UA.
- On iPhone or Android: send the beacon but do not navigate; the line becomes "YouFixIt is a Mac app. Open this page on your Mac to install it." with a link "Download the disk image" (DMG_URL).
- After a Mac download starts: the pill `perk`s to "Downloading" with a still drawn arrow for 4 s; the note becomes "Open the disk image and drag YouFixIt to Applications." plus a link "If it didn't start, download it directly." The finale's pebble period and the menu bar pebble each `hop` once (delight after a real action, Q100).
- Returning visitor: the field is prefilled; one press downloads; nothing is sent twice.
- `<meta name="yf-signup" content="https://script.google.com/macros/s/AKfycbyYJTV8Mm_N77moH5FPesW6b_7Khdt2XHBn9IvVHSbHGw43RxAkXjgibvvWu-QkzNuMRA/exec">` in the head; scripts read it only from there.

## J. Sections (five screens)
Template markers in order: `<!-- @section:hero -->` · `finds` · `never` · `faq` · `finale`. Each section is `<section id="<id>" aria-labelledby>`. Tones: paper, paper, paper, paper-2, paper-2 (one blended 160 px seam into faq, no rules). Sections left-aligned on the 1200 column; the hero is split around the panel; the finale is centred. Every section has its own composition (the jury note on one treatment repeated).

## hero
**Question:** "What is it, and can I see it work right now?"
Owner: hero builder (`web/sections/hero.html`, `site/css/hero.css`, `site/css/panel.css`, `site/js/hero.js`, `site/js/panel.js`).

Layout 1440 × 900: menu bar 36. A two-column grid on the 1200 column: text column (1fr, max 620) and the panel column (380 px, the app's true width) with 96 px between. The panel hangs from the menu bar pebble: top 8 px under the bar, `position: sticky; top: 44px` within the hero, its right edge on the column's right edge so the pebble sits above the panel's right third, where macOS puts a popover near the screen edge. The text column is vertically centred against the panel. Hero height `max(100svh, panel height + 120px)`. The pebble's light glows around it and the panel's head. (Q27 asks for a centred hero; the panel must hang from its pebble for the idea to be true, so the text sits to its left. Deliberate.) At 1280 × 720 the panel's list gets a max height with the app's 28 px bottom fade so Tidy up stays above the fold.

Copy (final):
- H1 (`--t-hero`): **"A little face in your menu bar that notices when your Mac gets heavy, and tidies it with one button."** (the GitHub description's logic: it notices on its own, you decide.)
- Sub (`--t-lead`, `--ink-2`, 17 words): "It finds the simulators, servers and caches you forgot about. Nothing changes until you press it."
- The email gate (§I.4).
- Under the gate, one row (`--t-small`): "Star it on GitHub" (drawn star + `[data-stars]`, `--go-text`) · "Free forever. A gift to the community." (`--ink-2`), middle dot between.
- Under the panel: the example label (§G.2), then, only while `heavy` and untouched, a second line "Press Tidy up." It goes for good after the first interaction with the panel (never ask twice).
- The hero's toys, all of them: Tidy up / Undo, row checks, Good to know, the footer Ask Claude note, and "Show the example again" in calm. Nothing else in the panel responds.

Animation:
- Load: nothing animates in; first paint is complete (panel heavy, haze amber, favicon amber). After `load` + 1.2 s idle, the nav pebble and the panel's header face `perk` together once (the heavy lift), linking the two faces for the eye; then `breathe`.
- Tidy up: §H. Rows `leave` (80 ms steps, 160 ms each, about 0.5 s total); menu bar count and badges roll down in step; haze amber → green over 600 ms; header swaps with `perk`; favicon swaps at `done`; the menu bar pebble `hop`s once after the smile hold.
- Undo: rows return top-down (`--ease-arrive` 220 ms, 80 ms stagger), counts roll up, haze back to amber.
- Scroll away: one ScrollTrigger on the hero. When the hero's bottom passes 45 % of the viewport, the panel `fold`s closed into the menu bar pebble (160 ms) and the pebble `perk`s; the grid slot keeps its size (`visibility: hidden`, zero CLS). Scrolling back folds it open (360 ms). Never scrubbed: open or closed, like a popover.

390 × 844 (a redesign, product first): menu bar 48 (its Download pill is the first-screen CTA). Top to bottom: H1 at 1.75rem (at most four lines, about 120 px), sub (two lines), then the panel as a compact sheet at `calc(100vw - 32px)`, 16 px under the sub: header, the "Running now" label, two rows with the app's 28 px bottom fade over the second, then Tidy up and its caption. The sheet's list scrolls inside (`overscroll-behavior: contain`) and its max-height is `min(340px, 100svh - 360px)`, so header and Tidy up stay visible. Budget: 48 + 20 + 120 + 12 + 50 + 16 + about 330 = about 600 px, inside 844 with room for the label. Below the first screen: the example label and hint, then the gate (stacked), then the star row. When the sheet appears the bar pebble `perk`s with its header face (the link to the menu bar; no connector line). The fold-into-pebble on scroll works the same.
Reduced motion: no perk (120 ms crossfade pose swaps); rows cross-fade out together over 220 ms; haze crossfades in 220 ms; the fold is a 160 ms opacity change; breathe keeps only the blink.

## finds
**Question:** "What does it actually find on my Mac, and how will I know when to open it?" (the second half was the cut `face` section's question)
Owner: `web/sections/finds.html`, `site/css/finds.css`, `site/js/finds.js`.
Hoy's move: the list is a sentence you read; the nouns are chips that came out of the app. Beside it, one docked app row shows how the app would say it. No grid, no row of icons.

Layout desktop: 12-column grid. H2 in cols 1 to 8. The two sentences in cols 1 to 8 (`--t-sentence`, max 30em). The example row card in cols 9 to 12, 360 px, `position: sticky; top: 30vh` within the section (no pin, no scroll script), with its caption under it. Then one muted line across cols 1 to 8.
Copy (final; [brackets] are chips; every noun is from FACTS "What Tidy up acts on"):
- H2: **"It looks for the things you started and forgot."**
- Lead (`--t-lead`, `--ink-2`, above S1, cols 1 to 8), with three still inline pebbles at 1em (calm, green with "3", amber with "5"; `aria-hidden`, the words carry the meaning; they do not breathe, glance or respond): "[calm pebble] Grey when it's fine, [green pebble] green with a number when something's idling, [amber pebble] amber when your Mac is struggling."
- S1: "Running now: [apps you haven't touched in an hour], [Docker or OrbStack with nothing running], [iPhone simulators], [leftover dev servers], [idle build daemons] and [Homebrew services] nobody is connected to."
- S2: "Taking up space: [Xcode build caches], [developer tool caches], [Claude Code scratch folders] and [old installers in Downloads]."
- Muted line (`--t-body`, `--ink-2`): "Everything else goes under Good to know: Spotlight indexing, software updates, browsers with many tabs, open Claude sessions, virtual machines. It explains them and leaves the choice to you."
- Card caption (`--t-small`, `--ink-2`): "Example row. The why line is the one the app writes."
Chip: `<button type="button" aria-controls="finds-card">`, inline-flex, 0.85em icon well (tint 14 % circle, the panel's stroke glyph) + words, `--p-card` fill, `--r-chip`, padding .1em .5em, `white-space: nowrap` (at 390 long chips may break between words with `box-decoration-break: clone`). Active chip: `--go-tonal` fill.
Card (one FindingRow replica: icon well, name, why line, size pill; system font; panel tokens; radius 14). Default active: Docker. Hover, focus or tap a chip → the card swaps with `fold` (.97 → 1, 220 ms arrive). Rows (name · why · pill):
apps → "Blender" · "Untouched since Wednesday" · 1.3 GB · Docker/OrbStack → "Docker" · "No containers running, nothing using it" · 3.7 GB · simulators → "iPhone 17" · "iOS 26.1, idle since Wednesday" · 1.2 GB · dev servers → "node" · "Port 3000 in my-app, from a finished coding session" · 240 MB · build daemons → "Gradle daemon" · "Gradle starts a fresh one on the next build" · 900 MB · Homebrew services → "postgresql" · "Nothing is using it. Stays off until you start it again." · 120 MB · Xcode → "Xcode build cache" · "Xcode rebuilds this when needed" · 14 GB · tool caches → "npm cache" · "Tools refill this as they need it" · 2.4 GB · Claude Code scratch → "Claude Code scratch" · "6 folders from sessions that ended days ago" · 85 MB · installers → "An old installer" · "An installer you already used" · 1.1 GB.
390: lead first (pebbles stay inline), sentences at 1.375rem; the card sits under the sentences, full width, not sticky, and swaps on tap; caption, then the muted line.
Reduced motion: the card swaps with a 120 ms opacity change.

## never
**Question:** "Can I trust it with my Mac?"
Owner: `web/sections/never.html`, `site/css/never.css` (no JS).
Honesty as design (Hoy's "It's early." panel; the app's own "so it stays." voice). The quiet screen: nothing animates on scroll.

Layout desktop: H2 and lead left. Two columns below: left (7/12) the never-list as plain rows separated by `--line` hairlines, no icons, no bullets; right (5/12) four app-row replica cards (app rows are objects, so cards are right) showing the app refusing, on a `--p-window` tray (radius 12, the popover shadow, 16 px padding, system font), with the caption under the tray. Nothing below the columns (Ask Claude is a feature, not a trust answer; it lives in the hero's footer note and FAQ 5).
Copy (final):
- H2: **"When in doubt, it stays."**
- Lead (`--t-lead`): "Every suggestion is checked twice: when it's found, and again the moment you press the button."
- Never-list (`--t-body`, `--ink`):
  1. "It never force-quits. Apps are asked to quit the normal way, so they can ask to save."
  2. "It never deletes anything on its own. Files go to the Trash, and Undo brings closed apps back for a minute."
  3. "It never stops what's in front of you or anything busy, playing audio or showing a dialog, and never moves a folder written to in the last ten minutes."
  4. "It never touches terminals, editors, browsers, messaging, password managers, VPNs, sync, remote access, or anything that belongs to macOS or another user."
- Tray cards (grey 28 px icon well with a drawn glyph, name, the app's refusal line as the why line, no check, no size):
  - "Blender" · "It has a dialog open, so it stays."
  - "ffmpeg" · "It's busy with something, so it stays."
  - "tmux" · "It holds terminal sessions, so it stays."
  - "postgres" · "Something is connected to it, so it stays."
- Tray caption (`--t-small`, `--ink-2`): "From the app, with example names. These are the lines it writes when it leaves something alone."
Interaction: tray cards take the app's card hover (fill to card hover, 120 ms). That is all.
390: H2, lead, the four rows, the tray full width, its caption.
Reduced motion: identical (nothing moves here).

## faq
**Question:** "What else should I know before I install it?"
Owner: `web/sections/faq.html`, `site/css/faq.css` (no JS). `paper-2` begins here and continues into the finale.
Plain rows (Q71): `<details name="faq">` with a drawn chevron, 1 px `--line` between, no cards. H2 left in cols 1 to 4 (sticky top 96 on desktop), rows in cols 5 to 12, max 720. Question `--t-lead` Mona 560; answer `--t-body` `--ink-2`. FAQPage JSON-LD generated by `build.mjs` from this HTML.
- H2: **"Plain answers."**
Five questions nothing else on the page answers (review cut the repeats of `never`, the gate note and the finale):
1. "Does it cost anything?" · "No, and it never will. The code is on GitHub under the MIT License, so you can read every line before you install it."
2. "Which Macs does it run on?" · "macOS 14.4 or newer, on Apple silicon and Intel. It's signed with a Developer ID and notarized by Apple."
3. "Why isn't it on the Mac App Store?" · "It has to see other programs to help with them, so it can't be sandboxed. You get it here or on GitHub."
4. "How do I install it, and get new versions?" · "Open the disk image and drag YouFixIt to Applications; its face shows up in your menu bar. There's no automatic updater: the download here always points to the newest release."
5. "Does anything leave my Mac?" · "No. The app has no network, no account and no analytics. The one exception is yours to make: Ask Claude opens a new Claude chat with a question about a row already written, your home folder shown as ~ and anything like a password blanked out. Claude gets the words, never your Mac."
Motion: content height via `interpolate-size: allow-keywords` and `::details-content` transition 220 ms arrive where supported, instant elsewhere; chevron rotates 90° in 120 ms.
390: H2 above the rows, not sticky; 52 px minimum tap height.
Reduced motion: rows open instantly; the chevron swaps without rotating.

## finale
**Question:** "Where do I get it, and what's the catch?"
Owner: `web/sections/finale.html`, `site/css/finale.css`, `site/js/finale.js`.
The big idea returns: the face finishes the page's last sentence, and it remembers what you did. Centred (Q23), on `paper-2`, one screen, the footer at its foot.

Layout desktop, centred, top to bottom: the giant line · one sentence · the state caption (after a tidy only) · the gate · the Star pill · the requirements line · footer.
Copy (final):
- Giant (`<h2>`, `--t-giant`, may wrap to two lines at 390): **"Free forever"** followed by **the pebble as its full stop**: an inline SVG pebble at the period's slot (0.62em wide, sitting on the baseline), `aria-hidden`; the heading's text includes a real "." in a visually hidden span. It is not a control (no button, no click): at the conversion moment nothing sends the visitor back into the demo.
- Sentence (`--t-lead`, max 34em): "YouFixIt is a gift to the community. Open source under the MIT License, no account, nothing to pay, now or later."
- The gate (§I.4), same component and copy as the hero.
- Star pill (tonal, 48 px, drawn star + "Star it on GitHub" + `[data-stars]`) → REPO_URL, same tab. The star glyph fills with `--go` over 120 ms on hover.
- Requirements (`--t-small`, `--ink-2`): "macOS 14.4 or newer · Apple silicon and Intel · Signed and notarized by Apple"
- Footer (§I.3).
The period remembers (IntersectionObserver at 40 %):
- After a tidy (`done` or `calm`): green with the smile, one `hop` on entry. Caption (`--t-small`, `--ink-2`, under the giant line): "You tidied the example. Your own Mac is next."
- Untouched (`heavy`): amber, lifted, its eyes glance once toward the gate on entry. No caption, no instruction.
- A small local glow sits behind the period only (radial, 40vmin, the matching haze colour at half strength): the page's light comes back where the idea comes back.
- After a download starts, the period `hop`s once with the smile.
390: giant line at about 19vw on two lines ("Free" / "forever" + pebble), gate stacked full width, Star pill full width, requirements wrap on the dots. No overflow at 320 (`clamp` floor 4rem).
Reduced motion: no hop or glance; the pose and the caption still follow the state.

## K. Performance
- JS at or under 90 KB gz in all (GSAP core, ScrollTrigger, CustomEase, site modules about 20 KB); ceiling 350. No WebGL, no Lenis, no video, no raster images in the page (only `og.png` in meta, favicon, touch icon). Every visual is HTML, CSS or inline SVG.
- Fonts at or under 120 KB woff2; Bricolage and Mona preloaded; Geist Mono lazy. Metric fallbacks so the swap does not move the H1.
- LCP is the H1 text (under 1.5 s on 4G). The panel's heavy state is in the HTML; JS only hydrates.
- One ticker, paused on `document.hidden`; `breathe` only on pebbles in view. Scroll work: one ScrollTrigger (hero fold) and IntersectionObservers (pebbles, finale). No scroll listeners.
- Animate only transform, opacity, clip-path and the `grid-template-rows` collapse inside the panel (`contain: layout paint`). Zero CLS: the hero panel's slot keeps its size when folded; the star count's growth happens inside a fixed-height flex row.
- `backdrop-filter` only on the menu bar. Haze layers `contain: strict`, opacity-only.
- `site/vercel.json`: `cleanUrls: true`; `Cache-Control: public, max-age=31536000, immutable` for `/fonts/*`, `/vendor/*`; `max-age=3600, must-revalidate` for `/css/*`, `/js/*` (build appends `?v=<hash>`); `max-age=0, must-revalidate` for HTML; `X-Content-Type-Options: nosniff`; `Referrer-Policy: strict-origin-when-cross-origin`; CSP `default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self' https://api.github.com https://script.google.com; frame-ancestors 'none'`. No `/download` redirect. The DMG is GitHub's `releases/latest/download/YouFixIt.dmg`, never hosted on Vercel.
- No analytics, no cookies, no consent banner (BRIEF §6).

## L. Accessibility
- `:focus-visible`: 2 px `--go` ring with 2 px paper offset on every control, chips, pebbles, row checks and `<summary>`.
- Landmarks: menu bar `header` with `nav`, `main` with five labelled sections, `footer`. One `h1`.
- The panel is fully keyboard-operable (§G.3); Return is true. Targets ≥ 44 px at ≤ 720.
- Every pebble has a text equivalent (the app's tooltip strings). Example labels are real text.
- Contrast pairs in §D.2; the architect re-measures in the browser in both themes and fails the build under 4.5 (text) or 3 (graphics, focus ring), including the amber ring and the panel's dark secondary.
- No overflow at 320: the panel becomes `calc(100vw - 24px)`, the giant line clamps, chips break between words.
- `prefers-reduced-motion: reduce`: every frame a poster, nothing hidden or waiting to animate. No springs (120 ms crossfades), rows cross-fade together, no pointer glance, no hop, the fold is a 160 ms opacity change, the haze crossfades in 220 ms, numbers swap without rolling, the 90 ms blink stays (it is the face). Shorter and calmer, never a still edition (Q60). Without JS the page is complete: panel heavy, FAQ native, gate submits to nothing but the download link (a `<noscript>` direct link under the gate).

## M. SEO and share
- `<title>`: "YouFixIt · A little face in your menu bar that notices when your Mac gets heavy". Description: "YouFixIt notices the simulators, servers and caches you forgot about and lets them go with one safe button. Free forever, open source, for macOS 14.4 or newer."
- Canonical https://getyoufixit.vercel.app/. OG and Twitter `summary_large_image`, 1200 × 630 `site/og.png` rendered from `web/og.html` with headless Chrome: bone paper; the menu bar strip across the top with the green pebble (done); a soft green haze from it; the H1 in Bricolage at 64 px on the left; the panel in its done state on the right ("Freed up 21 GB", smile face, Good to know row, Undo); a small "Example panel." in the corner.
- JSON-LD: `SoftwareApplication` (name YouFixIt, operatingSystem "macOS 14.4 or later", applicationCategory "UtilitiesApplication", offers price 0 USD, license https://opensource.org/licenses/MIT, downloadUrl DMG_URL, codeRepository REPO_URL), and `FAQPage` from §faq. No ratings.

## N. Ownership (one writer per file)
| Owner | Files |
|---|---|
| architect / integrator | `web/index.html` (template + markers), `web/build.mjs`, `web/og.html`, `site/css/tokens.css`, `site/css/base.css` (menu bar, gate, footer, haze, utilities), `site/js/main.js`, `site/js/lib/{store,format,pebble,motion,favicon,haze,signup,stars,config}.js`, `site/vendor/`, `site/fonts/`, `site/vercel.json`, `site/legal/index.html`, `site/404.html`, favicons, `site/og.png` |
| hero | `web/sections/hero.html`, `site/css/hero.css`, `site/css/panel.css`, `site/js/hero.js`, `site/js/panel.js` (the popover view reuses `panel.js`; the architect mounts it from `main.js`) |
| finds | `web/sections/finds.html`, `site/css/finds.css`, `site/js/finds.js` |
| never | `web/sections/never.html`, `site/css/never.css` |
| faq | `web/sections/faq.html`, `site/css/faq.css` |
| finale | `web/sections/finale.html`, `site/css/finale.css`, `site/js/finale.js` |
`main.js` imports a section's module only when its section exists and mounts it after `document.fonts.ready` (1.5 s fallback). The app-row replica markup (icon well, name, why, pill) is one shared partial in `panel.css` classes (`.row`, `.row__well`, `.row__name`, `.row__why`, `.row__size`) that `finds` and `never` reuse; they do not restyle it.

## O. Acceptance (QA before deploy)
1. 1440 × 900: H1, sub, gate, Star row and the whole panel including Tidy up visible. 1280 × 720: Tidy up above the fold. 390 × 844: H1, sub, the menu bar's Download pill, and the panel sheet's header, two rows and Tidy up all visible on the first screen without scrolling.
2. Tidy up by click, by Return with focus inside the panel, and by tap (Return with focus on `body` does nothing): rows leave nearest-first, counts roll, haze goes green, favicon smiles, menu bar pebble hops, "Freed up 21 GB". Undo the same three ways. Uncheck a row: the caption and count recompute through `format.size`. After 60 s: "Nothing to tidy." and "Show the example again".
3. Scroll past the hero: the panel folds into the pebble; back up, it opens; zero CLS. Click the pebble mid-page: the popover opens; Escape closes; focus returns.
4. `finds`: every chip by hover, Tab and tap swaps the card; the card never clips at 390 or 320.
5. Finale: the period reflects the state and is not focusable or clickable; the caption shows only after a tidy; download hops it.
10. Example labels: the hero panel and the popover both show the example label; the menu bar pebble's name and title and every live-region message start with "Example:". No Keep, no row sparkle, no glance from the nav.
6. Gate: empty and incomplete errors show the exact lines; a valid email fires the beacon and navigates to the DMG in the same task; a returning visitor downloads in one press with no second beacon; on a phone UA nothing downloads and the Mac line shows.
7. Star count only when the API returns ≥ 25; no gap otherwise.
8. Reduced motion: every frame complete, nothing hidden. 320 px: no horizontal overflow. No console errors; no long tasks over 50 ms during Tidy up; 0 long tasks over 3 s idle.
9. Copy audit: no em dashes, exclamation marks, emoji or rhetorical questions (FAQ summaries are a visitor's real questions); none of the banned words; "YouFixIt" spelled right; every demo row labelled as an example; every claim traces to FACTS.
