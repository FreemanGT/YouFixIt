# Spec · YouFixIt launch site · lens: TYPE (editorial-kinetic)

Status: complete and buildable. Read with `web/BRIEF.md` and `web/FACTS.md`; where this spec and FACTS disagree, FACTS wins.

## 0. The one idea

**The headline weighs what the Mac weighs: press Tidy up on the example panel and the sentence itself sheds its weight, word by word, from heavy to light.**

The app already names its moods `heavy` and `light` (StatusIcon.Pose). The site turns that into type: one variable face whose weight and casual axes are driven by a single number, the example Mac's load. Heavy Mac, heavy stiff headline. Tidy up, and the type relaxes in a wave that starts at the panel and travels across the sentence. Undo, and it puts the weight back on. The juror sentence: "you press Tidy up and the headline loses weight."

It returns twice, never as decoration: the face's colour states explained inline in section 2 (no motion), and the finale's colossal "Free forever." which sheds on scroll as you arrive ("costs nothing, weighs nothing").

Why this is calm, not a toy: one number drives everything (`--load`), one press triggers it, nothing on the page moves on its own except the pebble's blink.

## 1. Design tokens (site/css/tokens.css, owned by the architect)

### 1.1 Faces

| Role | Face | npm (fontsource) | Axes used | Why |
|---|---|---|---|---|
| Display, body, data | **Recursive** | `@fontsource-variable/recursive` (use `full.css` source files, latin subset) | `wght` 300 to 1000, `CASL` 0 to 1, `MONO` 0 or 1; pin `slnt` 0, `CRSV` 0.5 | One open-source family whose axes map to the app's states: weight = load, Casual = relaxed, Mono = data. Outside the usual list (Q29, Q36); not used by Claude Meter, Notched or FreeFlow. This is the project's one aesthetic risk (Q16). |
| Panel replica only | system stack `-apple-system, BlinkMacSystemFont, system-ui, sans-serif`; rounded titles `ui-rounded, -apple-system, system-ui` | none | system | So the example panel reads as the real app (BRIEF §6 override). |

Font file: one woff2, built by the architect with fontTools:
`fonttools varLib.instancer Recursive.ttf slnt=0 CRSV=0.5 wght=300:1000 CASL=0:1 MONO=0:1 -o rec.ttf` then `pyftsubset rec.ttf --unicodes="U+0000-00FF,U+2018-201F,U+2026,U+00B7,U+2191,U+21A9,U+2318,U+2325" --layout-features="kern,liga,tnum,lnum,case,ss01" --flavor=woff2 -o site/fonts/recursive.woff2`. Target ≤ 150 KB; hard cap 200 KB. `font-display: swap`, preloaded.

Metric fallback (verify with capsize, adjust within ±3 %):
```css
@font-face { font-family: "Recursive Fallback"; src: local("Helvetica Neue"), local("Arial");
  size-adjust: 106%; ascent-override: 92%; descent-override: 24%; line-gap-override: 0%; }
--font: "Recursive", "Recursive Fallback", sans-serif;
--mono: "Recursive", ui-monospace, "SF Mono", monospace; /* with font-variation-settings "MONO" 1 */
```

Type scale (desktop 1440 / phone 390). All sentence case. Display leading 1.02, tracking -0.02em. Body leading 1.5.

| Token | Size | Default axes | Use |
|---|---|---|---|
| `--t-colossal` | clamp(84px, 16vw, 248px) | wght 900→340 by scroll, CASL 0→1 | finale "Free forever." only |
| `--t-hero` | clamp(40px, 5.4vw, 80px) | wght driven by `--load` | H1 only |
| `--t-h2` | clamp(32px, 3.6vw, 52px) | wght 640, CASL 0.4 | section headings and the section 2 sentence |
| `--t-lead` | clamp(18px, 1.5vw, 22px) | wght 430, CASL 0.6 | sub lines, plain sentences |
| `--t-body` | 17px (16px at 390) | wght 420, CASL 0.5 | body, FAQ answers |
| `--t-small` | 14px | wght 450, CASL 0.5 | captions, notes, footer |
| `--t-data` | inherits size | MONO 1, wght 500, `tnum` `lnum` | numbers only: sizes, versions, ports, star count, clock |

Body CASL 0.5 is deliberate: the page is half relaxed at rest; the H1 is the only text that ever goes fully stiff.

### 1.2 Colour (light and dark both designed; follow the OS, no toggle)

Material: cool bone paper, ink tinted green-grey. Colour only from the product: the accent for go (Download, Tidy up, Star), amber only for the heavy face. Not the banned near-black plus acid green: the accent is a deep, quiet teal-green, used on four controls.

| Token | Light | Dark | Use |
|---|---|---|---|
| `--paper` | #F5F6F3 | #101211 | page |
| `--paper-2` | #ECEEEA | #161917 | sections 3 and 5 (Things-style tonal pacing, no rules) |
| `--mint` | #E2EEE9 | #11241E | finale, the one full-bleed colour moment |
| `--ink` | #151816 | #ECEEEB | text |
| `--ink-2` | #545B56 | #A2A9A4 | secondary text |
| `--ink-3` | #7A817C | #6E7570 | non-text only (hairlines, inactive glyphs) |
| `--line` | #DADDD8 | #2A2E2B | 1 px borders |
| `--accent` | #177D66 | #19846B | filled pills (Theme.tint) |
| `--accent-text` | #177D66 | #66CCAB | accent as text (links on paper only) |
| `--on-accent` | #FFFFFF | #FFFFFF | text on pills |
| `--tonal` | rgba(23,125,102,.14) | rgba(25,132,107,.22) | tonal pills (Star, Undo) |
| `--amber` | #D99A2B | #F0B445 | heavy face in the panel header |
| `--bar-green` | #259E80 | #259E80 | menu bar face, light pose |
| `--bar-amber` | #EDA833 | #EDA833 | menu bar face, heavy pose |
| `--error` | #B42318 | #FF8A80 | email error line |

Contrast, computed (WCAG 2.x), every text pair used:

| Pair | Light | Dark |
|---|---|---|
| ink on paper | 16.49 | 16.12 |
| ink-2 on paper | 6.44 | 7.83 |
| ink-2 on paper-2 | 5.98 | 7.38 |
| ink on mint | 15.02 | 13.90 |
| ink-2 on mint | 5.86 | 6.76 |
| accent-text on paper | 4.65 | 9.66 |
| accent-text on mint | 4.24 light: **never use**; use ink | 8.33 |
| on-accent on accent (pill, 15 px semibold) | 5.05 | 4.61 |
| error on paper | 6.06 | 8.24 |
| ink on bar-amber (count beside face) | 8.73 | n/a |
| ink-3 on paper | 3.68 (non-text only) | 3.98 (non-text only) |
| panel title #1D1D1F on window #ECECEC | 14.25 | sample dark from snapshot |
| panel secondary #3C3C43 (ish) on #ECECEC | 9.26 | sample |

Panel replica colours (from Theme.swift, used only inside the panel): window light #ECECEC, dark #2A2A2A (sample `snapshots/heavy-dark.png` and match); card rgba(0,0,0,.055) / rgba(255,255,255,.085); card hover .09 / .13; pill rgba(0,0,0,.08) / rgba(255,255,255,.08); tint light #177D66, dark #19846B; tint text dark #66CCAB; amber #D99A2B / #F0B445; key-on-accent rgba(255,255,255,.22).

### 1.3 Radii, space, depth

- Radii: `--r-pill` 999px · `--r-card` 14px (panel cards, example row) · `--r-panel` 16px (the panel window) · `--r-slab` 28px (the cropped Mac screen) · `--r-chip` 10px · `--r-key` 5px.
- Space: 4 px grid. `--s-1` 4 · `--s-2` 8 · `--s-3` 12 · `--s-4` 16 · `--s-6` 24 · `--s-8` 32 · `--s-12` 48 · `--s-16` 64 · `--s-24` 96 · `--s-32` 128. Section padding 128 desktop, 72 at 390. Content column 1200 at 1440; text measure 640.
- Depth: flat 1 px `--line` by default. Two exceptions, both product: the panel window (`0 24px 60px -20px rgba(21,24,22,.28), 0 0 0 .5px rgba(0,0,0,.18)`; dark `rgba(0,0,0,.6)` and a .5px white 10% inner edge), and pills on press (scale .98, no shadow).

### 1.4 Easing and duration (from Theme.swift, so the page moves like the app)

| Token | Value | Use |
|---|---|---|
| `--ease-arrive` | cubic-bezier(0.16, 1, 0.3, 1) | everything that settles without overshoot |
| `--ease-exit` | cubic-bezier(0.4, 0, 1, 1) | rows leaving |
| `--spring-perk` | GSAP `CustomEase` from spring(0.45 s, bounce 0.25), or `back.out(1.3)` at 0.45 s | one overshoot: Undo return, chip card, H1 regaining weight |
| `--spring-hop` | spring(0.5 s, bounce 0.3), or `back.out(1.6)` at 0.5 s | the pebble hop only |
| `--d-feedback` | 120ms | hover, press |
| `--d-state` | 220ms | panel state swaps |
| `--d-overlay` | 360ms | one word shedding, card settle |
| `--d-exit` | 160ms | one row leaving |
| `--d-count` | 600ms | rolling digits |
| `--d-stagger` | 80ms, cap 5 | rows |
| `--d-wave` | 45ms per word | shed wave delay |
| `--d-blink` | 90ms | pebble blink |
| `--d-smile` | 1200ms | smile hold before calm |

## 2. Motion grammar (four verbs; anything else is cut)

1. **shed** · variable type changes weight and casual, never position. One registered custom property `--load` (0 light, 1 heavy). Triggers: Tidy up (H1), Undo (H1, back to heavy with one overshoot), scroll scrub (finale colossal line only).
2. **leave** · panel rows exit one by one: opacity 1→0, translateX 0→24px, height collapses via a FLIP on the list (no layout thrash), 160 ms `--ease-exit`, stagger 80 ms, delay ordered by distance from the Tidy up pill (bottom row first). Undo plays it in reverse as **settle**.
3. **settle** · one spring, one overshoot, then still: panel state swaps (220 ms cross-fade plus 6 px rise), the example row card in section 2, the Undo return, the H1 regaining weight, FAQ rows opening (height via `grid-template-rows: 0fr→1fr`, 220 ms arrive).
4. **blink** · the pebble's ambient life, real poses from StatusIcon: blink (eyes to 1 px lines for 90 ms) every 3.5 to 7 s at random, a glance (eyes 1 px aside, 600 ms) every third blink, hop and smile only after the visitor did something. Paused when offscreen or the tab is hidden.

Not in the grammar, so not on the page: scroll fade-ins, parallax, marquees, split-text reveals, intro, loader, custom cursor, smooth scroll, page transitions. Every section is complete at rest and appears as it is. Controls react with colour and a 1 px lift at 120 ms; that is feedback, not a verb.

### 2.1 Shared utilities the architect provides (site/js/lib/, site/css/base.css)

- `lib/load.js` · the one number. `export const load = { get(), set(v, {wave=true, spring=false}) , subscribe(fn) }`. `set` writes `--load` on the `<h1 id="hero-title">` element only (not :root), plus `data-mood="heavy|light"`. CSS does the rest (§3.3).
- CSS in base.css: `@property --load { syntax: "<number>"; inherits: true; initial-value: 1; }` and `.shed` / `.shed > .w` rules (§3.3).
- `lib/split.js` · `splitWords(el)` wraps each word in `<span class="w" style="--i:N">`, keeps spaces as text nodes, sets `--n` (word count) on the parent, idempotent, runs once after `document.fonts.ready` (no reflow later). The h1 keeps its text for assistive tech; spans carry no aria.
- `lib/pebble.js` · `createPebble({size, pose, count, label})` returns an SVG element and `{ setPose(p), setCount(n|null), blink(), hop(), destroy() }`. Poses: `calm blink glance light heavy working done hop paused`. Geometry from Theme/StatusIcon: on a 22-unit canvas, body rect x 2 y 3.5 w 18 h 15 rx 7.5; eyes radius 1.3, centres 3 apart horizontally, at y 10 (heavy: radius 1.6, body lifted 1; working: eyes y 11.5, body scaleY .94 from the bottom; done/hop: eyes become 1.2-wide smile arcs, hop lifts 2). Eyes are cut out with an SVG `<mask>` so the background shows through, as in the menu bar. Fill: calm and blink `currentColor`; light, working, done, hop `--bar-green`; heavy `--bar-amber`; paused `currentColor` at 45 % with closed eyes. The count is a sibling `<span class="data">` (Recursive MONO, 13 px, wght 600) 4 px to the right.
- `lib/ambient.js` · one shared scheduler for every pebble's blink (one `gsap.ticker` callback, `IntersectionObserver` + `visibilitychange` pause). Each pebble registers; never more than one blinks in the same 400 ms.
- `lib/roll.js` · `roll(el, from, to, {unit})` rolling digits for real sizes (panel totals, Freed up, star count). 600 ms arrive, tabular figures so nothing jiggles. Reduced motion: swaps the text after a 120 ms cross-fade.
- `lib/gate.js` · the email gate behaviour (§4.3), used by the hero and the finale form.
- `lib/stars.js` · fetches `https://api.github.com/repos/FreemanGT/YouFixIt` once per page view (cache in sessionStorage 10 min, wrapped in try/catch), resolves `stargazers_count` only when ≥ 25, else `null`. Every Star control renders the number only when non-null (via `roll`).
- `lib/motion.js` · `reduced` (a live `matchMedia` boolean with a change event), `gsap` import from `/vendor/gsap/`, `ScrollTrigger` registered once. The only `gsap.ticker` user is `ambient.js`.
- GSAP 3.13 core + ScrollTrigger self-hosted (`site/vendor/gsap/gsap.min.js`, `ScrollTrigger.min.js`, plus `CustomEase.min.js` for the two springs). Nothing else.

## 3. The hero (screen 1 · "What is it, right now?")

### 3.1 Layout

Desktop 1440 × 900, everything above the fold:
- Nav (§4.1) 64 px.
- Left column, x 120 to 760 (640 wide): H1 at y ≈ 150, `--t-hero` (≈ 78 px), 5 lines with fixed line breaks (one `<span class="line">` per line, `white-space: nowrap`). Then the sub (`--t-lead`, ink-2, max 520 px), then the gate form (§4.3), then one quiet row: "Star it on GitHub" tonal pill (§4.2) and the plain note "Free forever · macOS 14.4 or newer" in `--t-small` ink-2, `14.4` in data mono.
- Right side, x 800 to the right edge of the viewport (full bleed right): **the slab**, a cropped Mac screen in the Alcove manner: a rounded rectangle (top-left and bottom-left radius 28, right edge bleeds off), height 720, top at y 104. Wallpaper: two radial gradients in paper tones, a hint of mint at the top right where the face sits (light: #E7ECE8 to #F5F6F3; dark: #1A1F1C to #101211). No Apple wallpaper, no Apple glyph.
- The slab's menu bar: a 24 px strip at its top, background paper at 72 % with `backdrop-filter: blur(20px) saturate(1.4)`; right-aligned items in the system face at 13 px: the **pebble with its count** (true scale: 22 px canvas), a drawn wifi glyph and a drawn battery glyph (1.5 px strokes, ink-2), and the **visitor's real local time** ("Sat 15 Nov 14:32", `Intl.DateTimeFormat`, updates each minute, the only clock on the page).
- **The panel** hangs from the pebble: 380 px wide, top 8 px under the menu bar, its right edge aligned 12 px left of the pebble's centre + 190 (like a real popover anchored under the icon), clamped inside the slab. Height grows with content (≈ 610 px with 5 rows).
- Under the slab's bottom edge, inside the slab at its bottom-left, the example caption (§3.2).

Desktop 1280 × 720 (short laptops): H1 drops to 64 px, 5 lines; the panel shows its first section and the Tidy up pill by limiting the "Taking up space" section to one row at viewport height < 800 (the second row is simply not rendered; totals use what is rendered). The pill must be above the fold at 1280 × 720.

Phone 390 × 844 (a redesign, not a reflow):
- Nav 56 px: pebble + wordmark left, "Download" filled pill right (this is the first-screen CTA, Q63).
- H1 at 38 px, 6 lines, fixed breaks for 390 (separate `.line` set via `data-lines-m`), left-aligned, 16 px gutters.
- Directly under it (12 px): the slab becomes a **menu bar strip** only, 24 px tall, full width, radius 12 top corners, showing just the clock and the pebble at the right. The panel hangs from it at full width (358 px; real layout, not a transform scale), with **3 rows** (Docker, 3 leftover servers, Xcode build cache) so the Tidy up pill lands at y ≈ 700, inside the first screen, and the H1 stays in view while the visitor presses: the shed is seen on the phone too.
- Then the sub, the gate form, the Star pill and the note, then the caption.

### 3.2 Hero copy (final)

H1 (one sentence that says what it is, the product finishes it):
> A little face in your menu bar that makes a heavy Mac feel light.

Desktop line breaks: "A little face in" / "your menu bar" / "that makes a" / "heavy Mac" / "feel light." · Phone: "A little face" / "in your menu bar" / "that makes" / "a heavy Mac" / "feel light." (5 lines at 38 px; if the face measures wider, 6 with "feel" / "light." split). The words "heavy" and "light" carry `data-anchor` so the shed lands on them last and first (§3.3).

Sub (26 words):
> YouFixIt notices what your Mac is carrying that you forgot about, and puts it away when you press Tidy up. Free forever. A gift to the community.

Note line: "Free forever · macOS 14.4 or newer"

Example caption, under the panel, `--t-small`, ink-2, with a 6 px grey dot before it:
> Example panel. Press Tidy up, then Undo. On your Mac it lists what your Mac is actually carrying.

After the undo minute runs out (§3.4): the caption's second sentence becomes a text button "Run the example again".

### 3.3 The shed (implementation)

```css
#hero-title { --load: 1; }
#hero-title .w {
  font-variation-settings: "wght" calc(330 + 590 * var(--load)), "CASL" calc(1 - var(--load)), "MONO" 0;
  transition: --load var(--d-overlay) var(--ease-arrive) calc(var(--d) * var(--d-wave-ms, 45ms));
}
```
- Each word span gets `--d` = its distance rank from the panel: on desktop the panel is to the right, so rank = (word's last-line index from the bottom) × 4 + (words from the line's end); the bottom-right word ("light.") sheds first, the top-left ("A") last. On the phone the panel is below, so rank = lines from the bottom. Total wave ≤ 13 words × 45 ms ≈ 600 ms, matching the rows leaving.
- Per row leaving, `load.set()` drops by the row's share of the selected total (share by bytes, so the Xcode cache sheds more weight than a server): `load = 0.12 + 0.88 × remaining / selectedTotal`. After the last row: `load.set(0)`. Each `set` restarts the CSS transition from the current value, so the type sheds in steps that follow the rows.
- Undo: `load.set(1, {spring:true})`: JS tweens `--load` with GSAP from 0 to 1.06 then settles to 1 (`--spring-perk`), and the wave runs in reverse order (top-left first).
- Deselecting a row before Tidy up (check off) does not change the weight; weight is what the Mac carries, not what you chose.
- No layout shift: every `.line` is `nowrap`; the H1 box has `min-height` equal to its heavy layout (lines × line-height), so lighter words only take less width inside a fixed box. Font size is chosen so the heaviest line fits the column (tested at 1440, 1280, 390, 320).
- Reduced motion: `--d-wave-ms: 0ms`, duration 160 ms, no overshoot. The weight change still happens (it is information, not decoration).
- Pointer delight, one only: hovering the H1 does nothing. Hovering the Tidy up pill pre-sheds the H1 by 4 % (`load` 1→0.96, 220 ms) as a tiny hint of what the press will do; leaving restores. Not on touch.

### 3.4 The living panel (component `site/js/hero.js`, styles `site/css/hero.css`)

Built in HTML and CSS from PopoverView.swift and FindingRow.swift; the system font stack; every string from Copy.swift. Owned by the hero builder.

```js
// site/js/hero.js
export function mountPanel(root, {
  rows,              // example rows (below), already filtered for the viewport
  know: 2,           // "Good to know" count, collapsed
  onLoadChange,      // (load:number, opts) => void   → lib/load.js
  onPose,            // (pose:string, count:number|null) => void → menu bar pebble
}) → { tidy(), undo(), reset(), state }  // state: "heavy" | "working" | "done" | "empty"
```

Example rows (names neutral, why lines verbatim from Copy.swift, sizes illustrative and labelled by the caption):

| Section | Icon (drawn, 14 px, in a 28 px well) | Name | Why line | Pill | Kind |
|---|---|---|---|---|---|
| Running now | phone outline | iPhone simulator | Untouched since Wednesday | 1.2 GB | memory |
| Running now | cube | Docker | No containers running, nothing using it | 3.7 GB | memory |
| Running now | server stack | 3 leftover servers | Ports 3000 to 5173, from finished coding sessions | 640 MB | memory |
| Taking up space | hammer | Xcode build cache | Xcode rebuilds this when needed | 18 GB | space |
| Taking up space | disk image | Installer in Downloads | An installer you already used | 1.1 GB | space |

Phone: rows 2, 3, 4 only. Short desktop (< 800 tall): rows 1 to 4.

States (strings exact):
1. **heavy** (initial). Header face 40 × 32, amber, eyes bigger; title "Your Mac is working hard. Here's what you can let go." (title 17 px semibold rounded); sub "Letting these go helps right away." Section labels "Running now" and "Taking up space" each with a count badge (pill, data digits). Rows with filled check circles. Pill "Tidy up" 44 px, filled accent, return-key glyph in a 18 px rounded key at its right end (white 22 %). Under it: "Frees about 5.5 GB of memory and 19 GB of space" (sizes roll when checks change; phone: "Frees about 4.3 GB of memory and 18 GB of space"). Collapsed row "Good to know" with badge 2 and a chevron (opens with **settle** to show two plain lines, verbatim from Copy.swift: "Spotlight is building its search index. It finishes on its own." and "Photos is looking through your library. It finishes on its own, mostly while charging."; no buttons, never selected, never counted in Tidy up). Footer: "Checked just now" · sparkle "Ask Claude" · pause glyph · gear glyph. Menu bar pebble: heavy, count 5.
2. **working**. On Tidy up (click, Space, or Return while focus is in the panel or on `body`): title cross-fades to "Tidying up…", header face to working pose; rows **leave** bottom-first (80 ms stagger, 160 ms each); after each row, `onLoadChange` (§3.3); section labels collapse when empty. Menu bar pebble: working, count counts down with each row.
3. **done**. Header face smile (done pose), title "Freed up 24.6 GB" (always the sum of the rows actually tidied: 24.6 GB with all 5 desktop rows, 22.3 GB with the 3 phone rows, 23.5 GB on short desktops; formatted like the app, one decimal under 100 GB) with the number rolling up from 0 (600 ms); sub "Your Mac has more room to breathe." Tonal "Undo" pill (32 px, return-key glyph tinted) and under it "You can undo for the next minute." The menu bar pebble does `done` → `hop` once → holds the smile 1.2 s → `calm` with no count. The headline is light.
4. **undo** (within 60 s): rows **settle** back top-first, header returns to heavy, H1 regains weight with one overshoot, menu bar pebble back to heavy, count 5.
5. **empty** (after 60 s without Undo): header face calm, "Nothing to tidy." + "Your Mac is doing great."; the Undo pill fades; caption offers "Run the example again" which calls `reset()` (cross-fade back to heavy, no wave, H1 to load 1 over 360 ms).

Interactions inside the panel (all keyboard and touch operable):
- Row check toggles (button with `aria-pressed`), recomputes totals with `roll`. Tidy up acts on checked rows only; disabled (and reads "Nothing selected") when none are checked.
- Row hover shows "Keep" and "Hide" text buttons and the sparkle at the right, as in `hover-ask-*.png`. In the example they do one honest thing each: Keep and Hide remove the row from this example with the leave verb (no weight change, it is still on the Mac); the sparkle shows the Ask Claude line (below). On touch, these show on the focused row.
- Footer "Ask Claude" and every row sparkle: never opens anything from the example. It swaps the caption, for 6 s, to: "On your Mac, this opens a new Claude chat with the question already written." 
- Pause and gear glyphs are drawn, `aria-hidden`, not focusable.
- Focus ring: 2 px `--accent` at 2 px offset, 14 px radius on cards, pill-shaped on pills.
- Live region (`aria-live="polite"`, visually hidden) announces "Tidying up", "Freed up 24.6 GB. You can undo for the next minute.", "Undone".

Theme: the panel follows the OS like the page: light window #ECECEC, dark window sampled from `snapshots/heavy-dark.png`. Cards radius 14, gap 6, padding 10, no border.

### 3.5 Hero performance

HTML and CSS only above the fold; `hero.js` is a module loaded with `type="module"` (deferred); the panel's initial heavy state is fully in the HTML, so it renders complete before any JS. LCP is the H1 text. No images in the hero except inline SVG.

## 4. Global elements

No intro. No loader. Native cursor. No theme toggle (the OS decides).

### 4.1 Nav (`site/css/nav.css`, architect)

- Sticky, 64 px (56 at 390), paper background at 86 % with `backdrop-filter: blur(16px)`; a 1 px `--line` bottom border appears only after 8 px of scroll (class toggle from an IntersectionObserver sentinel, no scroll listener).
- Left: the pebble (calm pose, ink, 22 px canvas, blinks via `ambient.js`) + wordmark "YouFixIt" in Recursive wght 760, CASL 0.6, 19 px, tracking -0.01em. Links to `#top`.
- Right (desktop): "Star it on GitHub" tonal pill (with count when ≥ 25) and "Download" filled accent pill. Right (390): "Download" only.
- Nav "Download": scrolls to the nearest gate form (hero if the hero is in view, else the finale) with native `scrollIntoView({block:"center"})` (instant under reduced motion) and focuses its email field. If an email is remembered, it downloads at once instead (§4.3).
- No menu, no other links. The page is one screen of answers; FAQ answers the rest.

### 4.2 Star it on GitHub (control, used in nav, hero, finale)

- Tonal pill (`--tonal` fill, `--accent-text` text in dark, ink in light), 40 px (32 in nav), a drawn 5-point star glyph (1.5 px stroke, fills with accent on hover over 120 ms) + "Star it on GitHub" + when `stars.js` resolves non-null, a data-mono count after a middle dot: "Star it on GitHub · 128" (digits roll in from 0 once). Links to https://github.com/FreemanGT/YouFixIt, `rel="noopener"`, same tab.
- Never a hard-coded number; on fetch failure or below 25, no number and no gap.

### 4.3 The email gate (`lib/gate.js` + `site/css/gate.css`, architect)

- One pill-shaped form, 56 px tall (52 at 390), max 460 px: the email field fills it (16 px input text, Recursive wght 450; placeholder "you@example.com" in ink-2), and a filled accent button at its right end: "Download YouFixIt" with the return-key glyph (the app's own Tidy up grammar, and true: Return submits). At 390 the button text is "Download" when the pill is narrower than 380.
- Visible `<label>` above the field, `--t-small`, ink-2: "Your email, then the download starts."
- Note under it, `--t-small`, ink-2: "It goes to the maker's Google Sheet, nowhere else. Rare news, and a reply removes you." (The legal link lives in the footer only.)
- Validation on submit only: `^[^\s@]+@[^\s@]+\.[^\s@]{2,}$`. Missing @ or domain: error line in `--error`, `aria-describedby`, field `aria-invalid`: "That email looks incomplete. Add the part after the @." Empty: "Add your email first, then the download starts." Error appears with **settle**; nothing shakes.
- On valid submit (all synchronous, the download never waits on the network): honeypot `company` empty check; `navigator.sendBeacon(meta[name=yf-signup].content, new URLSearchParams({type:"mac", email, name:"", platform:"YouFixIt · " + platformString(), ref: document.referrer, company:""}))`, falling back to `fetch(url, {method:"POST", mode:"no-cors", keepalive:true, body})`; store the email in localStorage (try/catch); then `location.href = "https://github.com/FreemanGT/YouFixIt/releases/latest/download/YouFixIt.dmg"`.
- `platformString()`: "Mac Apple silicon" / "Mac Intel" / "iPhone" / "Other", from `navigator.userAgentData` when present, else the UA, short and coarse.
- After submit: the form is replaced (settle) by one line, ink: "Downloading. Open the disk image and drag YouFixIt to Applications." with a text link "Download again" (direct DMG URL). The finale pebble (and the nav pebble) **hop** once with a smile. That is the delight after a real action (Q100).
- Returning visitor (email in localStorage): the field is pre-filled and the button stays; one press downloads. A beacon is sent only if this email was never sent from this browser (store a `sent` flag).
- On a phone (iPhone or Android UA): same form, same button, same download (there is no send-a-link service, so none is promised). The success line reads instead: "YouFixIt is a Mac app. Open this page on your Mac to install it." with the "Download again" link.

### 4.4 Footer and legal

- One line, `--t-small`, ink-2, on the finale's mint: "© 2026 Yiftach Freeman · Legal · GitHub". 
- `/legal/index.html` (a separate small page, same tokens): the three FACTS legal lines, verbatim, plus the email note (what, where, why, removal). A wordmark link back home. No other content.

## 5. Sections (6 screens; ≤ 7 allowed)

Order answers the visitor's questions in the order they ask them: what is it · what will it find · will it break something · what does it cost me · what else · where do I get it. Sections join by tone (paper → paper-2 → paper → paper-2 → mint), never rules. All left-aligned in the 1200 column; text measure ≤ 640. No eyebrows, no numbers, no section labels.

### Section 1 · `hero` · "What is it, right now?"
§3.

### Section 2 · `finds` · "What will it find on my Mac?"

Background `--paper`. One screen. Desktop: a 12-column grid; the sentence in columns 1 to 8, the example row card docked in columns 9 to 12 at the sentence's vertical centre (sticky inside the section while the sentence is read, `position: sticky; top: 30vh`, no pin, no scroll script).

Heading: none separate; the sentence is the heading (`<h2>`, `--t-h2`, wght 560, CASL 0.4, leading 1.18):
> It looks for what you stopped using but your Mac still carries: [iPhone simulators] nothing is using, [Docker] with no containers running, [dev servers] left by finished coding sessions, idle [Gradle daemons], [Xcode caches], old [installers] in Downloads and [caches] from apps you removed.

Each [bracket] is an inline **chip**: a button styled like a small app card (`--r-chip` 10, fill `card` tone of the page: rgba(21,24,22,.06) light / rgba(236,238,235,.08) dark, 4 px 10 px padding, a 16 px drawn icon in a 22 px well, the label in the sentence's own face at wght 560). The chip text is part of the sentence for screen readers (the button's text is the word itself, `aria-describedby` the card).

The card (one `FindingRow` replica, 360 px, the panel's system type, radius 14): shows the example row for the active chip. Default active: "Docker". Hover, focus or tap a chip → the card swaps with **settle** (cross-fade + 6 px rise, 220 ms). Card rows (name · why · pill), verbatim why lines:
- iPhone simulators → iPhone simulator · Untouched since Wednesday · 1.2 GB
- Docker → Docker · No containers running, nothing using it · 3.7 GB
- dev servers → 3 leftover servers · Ports 3000 to 5173, from finished coding sessions · 640 MB
- Gradle daemons → Gradle daemon · Gradle starts a fresh one on the next build · 900 MB
- Xcode caches → Xcode build cache · Xcode rebuilds this when needed · 18 GB
- installers → Installer in Downloads · An installer you already used · 1.1 GB
- caches → Old app cache · Left behind by a removed app · 420 MB
Under the card, `--t-small` ink-2: "Example row. The why line is the one the app writes."

Below the sentence (32 px), a `--t-lead` paragraph with three inline pebbles drawn at text size (no motion except blink on the first):
> The face sits in your menu bar, grey and calm. It turns [green 3] when it finds something you can let go, and [amber] when your Mac is struggling right now. Open it, read the list, press Tidy up.

Then one `--t-body` line, ink-2:
> Everything else it notices, from Spotlight indexing to worktrees with uncommitted changes, goes under Good to know: explained in plain words, never selected for you.

Phone 390: the sentence at 26 px; chips wrap inline; the card is **not** sticky: it sits directly under the sentence, full width, and swaps on tap. Paragraphs follow.
Reduced motion: card swaps with a 120 ms cross-fade, no rise.
Animation budget: settle only. Nothing on scroll.

### Section 3 · `safe` · "Will it break something I'm using?"

Background `--paper-2`. One screen. Desktop two columns: left (cols 1 to 6) heading + four plain sentences + the Ask Claude paragraph; right (cols 7 to 12) the **refusals**: the app's real "so it stays." lines as a quiet stack.

Heading (`<h2>`, `--t-h2`):
> It knows what to leave alone.

Plain sentences (`--t-lead`, ink, one per line, 16 px apart, no bullets, no icons):
> Nothing changes until you press the button.
> Apps quit the normal way, so they can ask to save. It never force-quits.
> What it clears from disk goes to the Trash, and apps it closes come back with Undo for a minute.
> Terminals, editors, browsers, password managers and anything busy are never on the list, and it never moves a folder something wrote to in the last ten minutes.

Ask Claude paragraph (`--t-body`, ink-2, with the sparkle glyph drawn inline at text size in accent-text, 24 px above):
> If a row puzzles you, press its sparkle. YouFixIt writes the question for you and opens a new Claude chat, with your home folder shown as ~ and anything like a password blanked out. Claude only gets the question. Nothing changes until you press one of YouFixIt's own buttons.

Refusals (right column): seven rows, each one line of the app's own refusal strings, set in the panel's system face at 15 px on a card (these are app objects, so cards are allowed): a 22 px calm pebble (ink, eyes open) at the left, the string, nothing else. Radius 14, gap 6, the panel's card fill on `--paper-2`. Verbatim from Copy.swift:
- You're using it right now, so it stays.
- It's playing audio, so it stays.
- It has a dialog open, so it stays.
- It's busy with something, so it stays.
- Something is connected to it, so it stays.
- It holds terminal sessions, so it stays.
- Part of macOS, so it stays.
Under the stack, `--t-small` ink-2: "Real lines from the app, shown when it leaves something alone."

The only motion: each refusal row's pebble **blinks** through `ambient.js` (one at a time, at random, only while the section is on screen). It reads as seven little faces that are fine where they are. No reveal.

Phone 390: heading, the four sentences, then the refusal stack full width (cards 52 px), then the Ask Claude paragraph last.
Reduced motion: blinks continue at half the rate (blink is 90 ms, not movement across space).

### Section 4 · `facts` · "What does it cost me, and what does it touch?"

Background `--paper`. Short screen (≈ 70 vh desktop). Heading (`<h2>`, `--t-h2`):
> No account. No analytics. No network.

A plain definition list (not cards): each row a 1 px `--line` top border, term left (cols 1 to 4, `--t-body` wght 600), value right (cols 5 to 12, `--t-body`). Data in mono only where marked `{}`.

| Term | Value |
|---|---|
| Price | Free forever. Open source under the MIT License. |
| Network | The app never goes online. Ask Claude hands its question to the Claude app or claude.ai in your browser. |
| Your Mac | macOS {14.4} or newer, on Apple silicon and Intel. |
| Install | A disk image, signed with a Developer ID and notarized by Apple. Open it and drag YouFixIt to Applications. |
| Updates | There is no updater. The newest version is always here and on GitHub. |
| Source | Every rule it follows is on GitHub, in the open. → link "github.com/FreemanGT/YouFixIt" (accent-text) |

Phone: term above value, 16 px gutters. No motion at all.

### Section 5 · `faq` · "What else should I know?"

Background `--paper-2`. Heading (`<h2>`, `--t-h2`): "Questions, answered plainly." Seven rows, plain expandable rows (`<details>`/`<summary>` with a drawn plus that rotates 45° in 220 ms), 1 px `--line` between, no cards; question `--t-lead` wght 560, answer `--t-body` ink-2, max 640. FAQPage JSON-LD built from the same strings at build time (`web/build.mjs` reads `web/sections/faq.html`).

1. **Does it delete my files?** No. Anything it clears from disk goes to the Trash first, so you can put it back. Deleting for good, like emptying the Trash, only happens from a Good to know button, after it asks you right in the row.
2. **Will it close something I'm using?** No. It skips whatever is in front of you, playing audio, showing a dialog or busy with work. Terminals, editors, browsers and messaging apps are never on the list.
3. **What does Undo bring back?** For one minute after Tidy up, Undo reopens the apps it closed and puts back the Homebrew services it stopped. Anything it cleared from disk is in the Trash either way.
4. **Why does it need to see my other apps?** To tell an idle app from a busy one, it has to look at other processes. That's why it isn't sandboxed. It isn't on the Mac App Store.
5. **Does Ask Claude send my stuff somewhere?** Only when you press it. It opens a new chat in the Claude app or on claude.ai with the question already written, your home folder shown as ~ and anything like a password blanked out. YouFixIt itself never goes online.
6. **Why is it free?** It's a gift to the community. YouFixIt is open source under the MIT License and stays free forever. If it helps, star it on GitHub.
7. **Which Macs does it run on?** macOS 14.4 or newer, on Apple silicon and Intel.


Phone: same rows, 16 px gutters. Reduced motion: rows open instantly, plus does not rotate (swaps to minus).

### Section 6 · `finale` · "Where do I get it?"

Full-bleed `--mint` (the one colour moment), min-height 100 vh desktop, 90 vh phone. The footer line sits at its bottom.

The colossal line (`<h2>`, `--t-colossal`, ink, leading 0.92, tracking -0.03em, left-aligned, may bleed past the column to the viewport edge but never overflows it):
> Free forever.

The full stop is **the pebble**: an inline SVG pebble at cap height (the period's slot, sized `0.62em` wide), calm pose in ink, blinking. It is the app's face finishing the sentence (the Hoy borrow: the product replaces a glyph). `aria-hidden`; the h2 text includes a real "." in a visually hidden span.

Shed on arrival (the idea returns): a ScrollTrigger on the h2, `start: "top bottom"`, `end: "center 55%"`, `scrub: 0.4`, tweens the h2's own `--load` 1 → 0, so "Free forever" goes from wght 920 stiff to wght 330 casual as it rises into place. At rest (end reached, or reduced motion, or no JS) it is light. Width stays inside the viewport at both extremes (size tested at heavy).

Under it (40 px), `--t-lead`, ink, max 560:
> A gift to the community. Open source, no account, no catch. Download it, and if it makes your Mac feel lighter, star it on GitHub.

Then the gate form (§4.3) and the Star pill side by side (desktop), stacked (phone). On successful submit the pebble-period **hops** with a smile (`--spring-hop`), holds 1.2 s, returns to calm.

Footer line (§4.4) 48 px from the bottom.

Phone 390: the colossal line at 84 px on two lines ("Free" / "forever."), pebble as the period; then copy, form full width, Star pill full width, footer.
Reduced motion: no scrub; the line renders light; the hop becomes a 160 ms smile swap.

## 6. Mobile summary (390 is a redesign)

- Hero: H1 then the panel directly under it, 3 rows, Tidy up in the first screen, the H1 visible while pressing (§3.1).
- Finds: card under the sentence, tap chips.
- Safe: refusals between the sentences and Ask Claude.
- Finale: two-line colossal, pebble as the period.
- No horizontal scroll at 320: the colossal line uses `clamp(64px, 22vw, …)` at ≤ 360; chips wrap; the panel is 100 % width with `min-width: 0` on every flex child; long why lines wrap to two lines like the app.

## 7. Reduced motion (every frame a poster, nothing hidden)

- `prefers-reduced-motion: reduce` sets `--d-wave-ms: 0ms`, durations to 160 ms, springs to `--ease-arrive` with no overshoot.
- Hero: shed still happens (weight is the information) in one 160 ms step per row; rows leave with a 120 ms fade, no slide; the pebble swaps poses without hop.
- Finale: no scrub; the line is light from the start.
- Blinks: half rate. Nothing is ever hidden waiting to animate; without JS the page is complete (hero panel in its heavy state, finale light, FAQ as native `<details>`).

## 8. Accessibility

- Landmarks: `header` (nav), `main` with six `section`s each `aria-labelledby` its h2, `footer`. One h1.
- Focus visible everywhere: 2 px `--accent` ring, 2 px offset; on mint the ring is ink.
- The panel: Tidy up and Undo are `<button>`s; Return triggers Tidy up only when focus is inside the panel or on `body` (never while typing in a field). Row checks `aria-pressed`. Live region per §3.4. The menu bar slab is `aria-hidden` except the pebble's `role="img" aria-label="YouFixIt face, heavy, 5 things to tidy"` which updates.
- Chips: buttons, Space/Enter activate, arrow keys move between chips (roving tabindex optional, Tab must work).
- Contrast: §1.2. Touch targets ≥ 44 px (row checks get a 44 px hit area around the 18 px circle).
- No overflow at 320 px (QA `--overflow`).
- `lang="en"`, US spelling.

## 9. SEO and share

- `<title>`: "YouFixIt · a little face that tidies your Mac"
- Description: "A small face in your Mac menu bar that notices when your Mac is struggling and tidies it with one safe button. Free forever, open source."
- Canonical `https://getyoufixit.vercel.app/`. OG and Twitter: `og.png` 1200 × 630.
- OG image (`web/og.html`, rendered with headless Chrome): paper background; left, the H1 at its **light** weight in Recursive at 64 px over 4 lines; right, the menu bar strip with the green pebble (done pose) and the panel's done state cropped at the bottom edge ("Freed up 24.6 GB", Undo pill). Bottom-left in 20 px ink-2: "Free forever · getyoufixit.vercel.app".
- JSON-LD: `SoftwareApplication` (name YouFixIt, operatingSystem "macOS 14.4 or later", applicationCategory "UtilitiesApplication", offers price 0 USD, license MIT URL, downloadUrl the DMG URL, codeRepository GitHub) and `FAQPage` from section 5. No ratings.
- Favicon: the pebble SVG (calm, ink; dark mode via `prefers-color-scheme` inside the SVG).

## 10. Performance plan

- Budget: JS ≤ 60 KB gz total (GSAP core ≈ 27 KB, ScrollTrigger ≈ 12 KB, CustomEase ≈ 3 KB, site modules ≈ 15 KB); fonts one woff2 ≤ 150 KB (cap 200 KB); no images except `og.png` (not loaded by the page). Far under the 350 KB cap.
- Critical path: HTML + `tokens.css` + `base.css` + `hero.css` inlined or preloaded; `recursive.woff2` preloaded; all JS `type="module"`, deferred. The page is complete before JS.
- One ticker (`ambient.js`), paused offscreen and on `visibilitychange`. ScrollTrigger only for the finale scrub. No scroll listeners elsewhere (IntersectionObserver for the nav border and pause logic).
- Animate only `opacity`, `transform`, and the registered `--load` (which changes font variations: paint-only on fixed-width `nowrap` lines; measure in QA that shedding causes no layout shift outside the H1 box and stays under 4 ms per frame).
- No CLS: the H1 box has a fixed min-height; the panel's heavy state is server-rendered at its final height; the star count slot reserves no space (number appended inside the pill, pill width grows, nothing below it moves because the pill row is a flex row with fixed height).
- `vercel.json`: `cleanUrls: true`; headers: `/fonts/*` and `/vendor/*` `Cache-Control: public, max-age=31536000, immutable`; `/css/*`, `/js/*` `max-age=3600, must-revalidate`; HTML `max-age=0, must-revalidate`; a redirect `/download` → the DMG URL (302) for links shared elsewhere (it bypasses the gate on purpose: the gate is a request, not a lock); security headers (`X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`). No analytics, no cookies.

## 11. Files and owners (for parallel builders)

| Owner | Files |
|---|---|
| architect / integrator | `web/index.html` (template with `<!-- @section:hero -->`, `finds`, `safe`, `facts`, `faq`, `finale`), `web/build.mjs`, `site/css/tokens.css`, `site/css/base.css`, `site/css/nav.css`, `site/css/gate.css`, `site/js/main.js`, `site/js/lib/{load,split,pebble,ambient,roll,gate,stars,motion}.js`, `site/fonts/`, `site/vendor/gsap/`, `site/legal/index.html`, `site/vercel.json`, `web/og.html`, favicon |
| hero builder | `web/sections/hero.html`, `site/css/hero.css`, `site/js/hero.js` |
| finds builder | `web/sections/finds.html`, `site/css/finds.css`, `site/js/finds.js` |
| safe + facts builder | `web/sections/safe.html`, `web/sections/facts.html`, `site/css/safe.css`, `site/css/facts.css` |
| faq + finale builder | `web/sections/faq.html`, `web/sections/finale.html`, `site/css/faq.css`, `site/css/finale.css`, `site/js/finale.js` |

`main.js` imports each section module only if its section exists, and calls `mount*()` after `document.fonts.ready` (with a 1.5 s timeout fallback).

## 12. Acceptance (what QA checks before deploy)

1. At 1440 × 900 and 390 × 844, first screen: the H1, the live panel with the Tidy up pill, and a Download control are visible; a stranger can say what it is.
2. Press Tidy up (mouse, Return, touch): rows leave bottom-first, the H1 sheds weight in a wave from the panel side, menu bar pebble goes working → done → hop → calm, "Freed up 24.6 GB" rolls. Undo restores rows and weight with one overshoot. After 60 s: "Nothing to tidy." and "Run the example again".
3. Finale "Free forever." sheds as it scrolls in; pebble-period blinks; download hop works.
4. Email gate: invalid shows the exact error line; valid fires the beacon and navigates to the DMG URL in the same tick; returning visitor downloads in one press.
5. Star count appears only when the API returns ≥ 25.
6. Reduced motion: every frame complete; nothing hidden.
7. No overflow at 320; no console errors; no long tasks > 50 ms during the shed; CLS 0.00.
8. Copy audit: no em dashes, no exclamation marks, no emoji, no rhetorical questions in body copy (FAQ questions and the section-question labels in this spec are not on the page except as FAQ summaries, which are real questions a visitor asks), none of the banned words, every claim traceable to FACTS.
