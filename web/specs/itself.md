# Spec · ON ITSELF · YouFixIt launch site

Lens: the site has the app installed on itself. Operating the product changes the page you are on.
Canonical: https://getyoufixit.vercel.app/ · Source of truth for every claim: `web/FACTS.md` · Taste: `web/BRIEF.md`.

## 0. The one idea (the sentence a juror repeats)

**"The website has YouFixIt in its own menu bar: press Tidy up and the page you're on calms down."**

How it is true, concretely:
- The site's nav is drawn as a Mac menu bar (a thin translucent strip, nothing fake in it). The YouFixIt pebble lives at its right end, live, with its count. There is no device frame anywhere: the browser page is the desktop.
- On the first screen the panel hangs from that pebble exactly as the real popover does (8 px under the bar, its right edge on the column edge). It is operable: Tidy up, Undo, Good to know, Return key.
- The face's light falls on the page. A soft haze radiates from the pebble across the top of the page in the face's colour: amber while the example Mac is "working hard", green after Tidy up, gone when all is calm. The browser tab's favicon is the pebble in the same pose. Press Tidy up and the whole page, its tab and its menu bar change mood together.
- Scroll past the hero and the panel folds back into the pebble, like a popover closing. The pebble stays in the menu bar for the whole page; click it anywhere to open the panel again. The app is installed on the site, not pictured on it.
- The finale's big pebble remembers what you did.

Every other decision serves that sentence and stays quiet. No intro, no loader, no scroll reveals, no marquee. The only motion is the app's own.

## 1. Design tokens

All tokens live in `site/css/tokens.css` (architect). Light and dark follow `prefers-color-scheme`; no toggle.

### 1.1 Faces (site's own type; the panel replica uses the system stack, BRIEF §6 override)

| Role | Package (npm, self-hosted subset woff2) | Axes used | Why |
|---|---|---|---|
| Display | `@fontsource-variable/bricolage-grotesque` (5.3.0) | `opsz` 12 to 96, `wdth` 75 to 100, `wght` 200 to 800 | Soft, slightly swollen terminals and ink traps at high opsz read as a pebble's rounded edges; a grotesk with a grin, never a template sans. `opsz` 96 for display, `wdth` 75 for the one giant word in the finale. |
| Body and UI | `@fontsource-variable/mona-sans` (5.3.0) | `wdth` 100 to 112, `wght` 400 to 650 | A calm neutral with real width range; one notch wide (`wdth` 106) for buttons so pills feel generous like the app's. |
| Data | `@fontsource-variable/geist-mono` (5.3.0) | `wght` 400 to 500 | Sizes in the "what it finds" chips, the live star count, port numbers. Data only (Q31). |
| Panel replica | `system-ui, -apple-system, "SF Pro Text", "Mona Sans Variable", sans-serif`; rounded titles `ui-rounded, "SF Pro Rounded", system-ui` | as the app | It must look like the real app on a Mac. Mona Sans is the fallback off Apple devices. |

Subsets: Latin basic + punctuation (U+0020-007E, U+00A0-00FF, U+2018-201F, U+2026, U+2190-21FF for the return glyph is drawn in SVG anyway, U+00B7). Target total under 120 KB woff2. Metric-matched fallbacks via `@font-face { src: local("Arial"); size-adjust; ascent-override; descent-override }` named `"Bricolage Fallback"` and `"Mona Fallback"` (compute with fontaine-style numbers from the real files; architect).

Type scale (desktop / 390):
- `--t-hero` 4.5rem / 2.375rem, Bricolage opsz 96, wght 640, wdth 92, leading 1.02, tracking -0.025em.
- `--t-h2` 3rem / 2rem, Bricolage opsz 72, wght 600, wdth 96, leading 1.05, tracking -0.02em.
- `--t-giant` clamp(6rem, 19vw, 17rem), Bricolage opsz 96, wght 760, wdth 75, leading 0.9, tracking -0.03em. Finale only, one word.
- `--t-lead` 1.25rem / 1.125rem, Mona wght 430, leading 1.45.
- `--t-body` 1.0625rem / 1rem, Mona wght 420, leading 1.55.
- `--t-small` 0.875rem, Mona wght 450, leading 1.4.
- `--t-btn` 1rem, Mona wght 600, wdth 106.
- `--t-data` 0.9375rem, Geist Mono wght 450, `font-variant-numeric: tabular-nums`.
Sentence case everywhere. No uppercase, no eyebrows, no italics (the one italic is not needed here).

### 1.2 Colour (one material: bone paper; the product's green and amber are the only colour)

Light (`:root`):
| Token | Hex | Use | Contrast |
|---|---|---|---|
| `--paper` | #F4F3EE | page | base |
| `--paper-2` | #EAE9E3 | FAQ and finale seam tone (Things-style pacing, no rules) | n/a |
| `--ink` | #191B1A | text | 15.58 on paper · 14.23 on paper-2 |
| `--ink-2` | #565C59 | secondary text | 6.16 on paper · 5.62 on paper-2 |
| `--line` | #DEDDD6 | hairlines (FAQ rows, menu bar bottom) | non-text |
| `--go` | #177D66 | Download pill, focus ring, Tidy up (app tint) | white text 5.05 |
| `--go-text` | #136B57 | accent as text (links, star count) | 5.78 on paper · 5.17 on tonal |
| `--go-tonal` | #DFE9E4 (go at 14 % on paper) | Undo pill, tonal surfaces | n/a |
| `--face-green` | #259E80 | pebble fill (bar green) | non-text, 3.01 on paper (graphic, ≥3 ok) |
| `--face-amber` | #EDA833 | pebble heavy fill (bar amber) | non-text; eyes cut out, never carries text |
| `--haze-amber` | rgba(237,168,51,.16) | mood haze, heavy | n/a |
| `--haze-green` | rgba(37,158,128,.13) | mood haze, light/done | n/a |
| `--bar` | rgba(244,243,238,.72) + `backdrop-filter: saturate(1.6) blur(20px)` | menu bar | text ink on it ≥ 14 |

Dark (`@media (prefers-color-scheme: dark)`):
| Token | Hex | Contrast |
|---|---|---|
| `--paper` | #111312 | base |
| `--paper-2` | #181B19 | n/a |
| `--ink` | #ECEDE8 | 15.85 on paper · 14.60 on paper-2 |
| `--ink-2` | #9CA29E | 7.17 on paper · 6.61 on paper-2 |
| `--line` | #262A28 | non-text |
| `--go` | #19846B | white text 4.61 |
| `--go-text` | #66CCAB | 9.59 on paper · 6.27 on tonal |
| `--go-tonal` | #1F2E28 | n/a |
| `--face-green` | #259E80 | 5.58 on paper |
| `--face-amber` | #EDA833 | 9.11 on paper |
| `--haze-amber` | rgba(237,168,51,.12) | n/a |
| `--haze-green` | rgba(37,158,128,.14) | n/a |
| `--bar` | rgba(17,19,18,.66) + same blur | n/a |

Panel replica tokens (`--p-*`, from Theme.swift; the panel never borrows site colours):
- Light: window #ECECEC · card rgba(0,0,0,.055) · card hover rgba(0,0,0,.09) · pill rgba(0,0,0,.08) · text #1D1D1F (14.25 on window) · secondary #5E5E62 (≥4.7 on window and card; verify, must be ≥4.5) · tint #177D66 · tonal rgba(23,125,102,.14) · tonal text #136B57 (5.17) · amber face #D99A2B.
- Dark: window #2A2A2C · card rgba(255,255,255,.085) · card hover rgba(255,255,255,.13) · text #F5F5F7 (13.16) · secondary #A8A8AD (verify ≥4.5 on card #3A3A3C; #A1A1A6 measured 4.41, so lift it) · tint #19846B · tint text #66CCAB · amber face #F0B445.
- Shadow of the popover: `0 0 0 .5px rgba(0,0,0,.18), 0 18px 50px -12px rgba(0,0,0,.28)` light; `0 0 0 .5px rgba(255,255,255,.12), 0 18px 50px -12px rgba(0,0,0,.6)` dark. The only shadow on the site.

Accent rule (Q47): `--go` appears only on Download, Tidy up, focus rings and the live star link. Amber appears only on the face. Nothing decorative is green.

### 1.3 Radii, space, sizes
- `--r-card` 14px (panel cards) · `--r-panel` 12px (popover, matches macOS) · `--r-pill` 999px · `--r-key` 5px · `--r-field` 999px.
- 4 px grid. Column 1200 max, gutters 24 desktop, 16 at 390. Section padding block: 9rem desktop, 5.5rem at 390.
- Menu bar height: 36px desktop, 48px at ≤ 720px (touch target).
- Pebble in the menu bar: 24 × 20 css px (18 × 15 pt drawn at 4/3 so it reads on non-retina), on a 30 px hit target (44 px on touch).

### 1.4 Easing and durations (ported from Theme.swift; nothing else is allowed)
- `--ease-arrive` cubic-bezier(.16, 1, .3, 1) · `--ease-leave` cubic-bezier(.42, 0, 1, 1) (easeIn).
- `--d-feedback` 120ms · `--d-state` 220ms · `--d-overlay` 360ms · `--d-exit` 160ms · `--d-count` 600ms · `--d-stagger` 80ms (cap 5) · `--d-blink` 90ms · `--d-smile` 1200ms · `--d-haze` 600ms (= count roll).
- Springs (GSAP `CustomEase` generated once from the SwiftUI springs, or a tiny spring solver in `js/lib/spring.js`): `perk` = 0.45s, bounce 0.25 (one overshoot about 6 %); `hop` = 0.5s, bounce 0.3. Nothing bounces twice.
- Pressed pill: scale .98 in 120ms. Hover on every control: background tone shift + 1px lift in 150ms (Q55).

## 2. Motion grammar (four verbs; anything else is cut)

1. **breathe** · the pebble idles like the real icon: a blink (eyes to slits for 90ms) every 4 to 7 s, random; a glance (eyes 1px aside for 600ms) once every 3 to 4 blinks, toward the pointer when it is near. Only on the pebbles that are on screen. Never a loop on anything else.
2. **perk** · the `perk` spring on a state change: pebble pose swap (scale .9 to 1 through one overshoot), count badges, the panel header swap, the Undo pill arriving. The finale pebble's `hop` is the same verb at the `hop` spring.
3. **leave** · rows exit on Tidy up: each card fades and slides 8px up while its height collapses, `--d-exit` with `--ease-leave`; delay = its distance from the Tidy up pill, nearest first (Monocle's "delays by distance"), 80ms per step, cap 5. Undo plays it backwards with `--ease-arrive` from the top.
4. **fold** · the popover opens out of the pebble and folds back into it: transform-origin at the pebble's centre, scale .94 to 1 + opacity, `--d-overlay` `--ease-arrive` to open, `--d-exit` `--ease-leave` to close. Used for the hero's scroll-away, every pebble click and Escape.

The mood haze is not a verb of its own: it is the face's light, so it crossfades with the face's pose over `--d-haze` (part of perk).

Not allowed: scroll reveals of text, parallax, split-text, a marquee, a custom cursor, a smooth-scroll library, an intro. The page is finished at rest (Q10).

### 2.1 Shared utilities the architect provides (`site/js/lib/`, `site/js/main.js`)
- `store.js` · the single example state machine (§3.2). `subscribe(fn)`, `get()`, `dispatch(action)`. Persists nothing beyond the tab (no storage), except the email (§4.4).
- `pebble.js` · `renderPebble(el, {pose, count, size})` builds the inline SVG (§3.1) and swaps poses with the perk spring; `breathe(el)` starts the idle blink/glance with an IntersectionObserver gate. One `requestAnimationFrame` ticker for all pebbles (GSAP's ticker; `gsap.ticker.lagSmoothing(0)` off; pause when `document.hidden`).
- `motion.js` · `perk(el)`, `hop(el)`, `leave(els, originEl)`, `fold(el, originEl, open)`; each checks `matchMedia('(prefers-reduced-motion: reduce)')` and swaps to the reduced variant (§7.2). Exports the eases and durations from §1.4 as constants read from CSS custom properties.
- `favicon.js` · keeps `<link rel="icon">` in step with the store: an SVG data URL of the pebble in the current pose (calm grey #8A8F8C, light/done green, heavy amber, done = smile arcs). Static fallback `favicon.svg` (calm) + `apple-touch-icon.png` 180 (green pebble on paper).
- `haze.js` · sets `html[data-mood]` = `heavy | light | done | calm | paused` from the store; the CSS crossfades two fixed full-bleed layers (`.haze--amber`, `.haze--green`) by opacity over `--d-haze`. Each layer is one radial gradient: `radial-gradient(120vmax 70vmax at var(--pebble-x) -10vmax, var(--haze-*) 0%, transparent 60%)`, where `--pebble-x` is the nav pebble's centre, measured once on load and on resize. `pointer-events: none; z-index: -1; contain: strict`.
- `signup.js` · the email gate (§4.4); exported `mountGate(formEl)` used in the hero and the finale.
- `stars.js` · fetch `https://api.github.com/repos/FreemanGT/YouFixIt` once (`cache: 'force-cache'`), fill every `[data-stars]` with `stargazers_count` in Geist Mono only when ≥ 25; otherwise and on failure leave the text "Star it on GitHub" alone (FACTS). The number rolls in once (`--d-count`) when real.
- `vendor/gsap.min.js` 3.13 + `ScrollTrigger.min.js` + `CustomEase.min.js`. No other plugins.

## 3. The hero component: the living panel

Rebuilt in HTML/CSS from `PopoverView.swift`, `FindingRow.swift`, `Theme.swift`, `Copy.swift`, checked against `snapshots/heavy-*.png`, `working-mid-*.png`, `done-*.png`, `empty-*.png`, `know-open-*.png`, `icon-poses-*.png`. Owner: hero builder (`web/sections/hero.html`, `site/css/panel.css`, `site/js/panel.js`).

### 3.1 The pebble (`<span class="pebble" data-pose data-count>`)
Inline SVG, viewBox `0 0 22 22`: rounded rect x 2, y 3.5, w 18, h 15, rx 7.5 filled with the pose colour; eyes cut out with a mask (circles r 1.3, centres x 9.5 and 12.5, y 11; on `heavy` r 1.6 and the body lifted 1 unit). Poses from `StatusIcon.swift`:
- `calm` ink fill (the menu bar's own monochrome, `--ink`) · `blink` eyes as 2.6 × .8 slits · `glance` eyes shifted 1 unit x · `light` green · `heavy` amber, bigger eyes, lifted · `working` eyes down 1 unit, body scaleY .94 · `done` smile arcs (stroke 1.2, paper colour) · `hop` done + lifted 2 · `paused` grey #8A8F8C at .7 opacity, eyes closed.
- Count: a Geist Mono numeral at the pebble's right, 13px wght 500, `--ink`. Rolls digit by digit over `--d-count` when it changes (a real count of the example rows).
- The panel header uses the same SVG at the 40 × 32 face size with the in-app fills (`--p-amber`, `--p-tint`).

### 3.2 State machine (`store.js`), the example only
States: `heavy` (initial) → `working` → `done` → (after 60 s, the real undo window) `empty`. From `done`, Undo → `heavy` again. From `empty`, "Show the example again" → `heavy`.
- `heavy`: pebble amber, count 5. Header face amber. Title "Your Mac is working hard. Here's what you can let go." Sub "Letting these go helps right away."
- `working`: pebble `working`, header "Tidying up…" (the app's own ellipsis character), rows leave one by one (`leave`), the count rolls 5 → 0 as each row goes.
- `done`: pebble `done` (smile) for `--d-smile`, then a single `hop`, then stays `done` with no count. Header "Freed up 21 GB" (the example's 5.6 GB of memory + 15 GB of space through the app's `Format.size`: 20.6 → "21 GB"), sub "Your Mac has more room to breathe." Tonal Undo pill with the return glyph, caption "You can undo for the next minute." Good to know row stays.
- `empty` (after 60 s in `done`, or never if the visitor leaves): pebble `calm`, header "Nothing to tidy." sub "Your Mac is doing great." plus a quiet text button "Show the example again" (site string, labelled as the example's control).
- Page mood map: heavy → amber haze; working → amber fading to green over the leave; done → green haze; empty → no haze (calm). Favicon follows.

### 3.3 Panel content (example rows; neutral names, real why lines from Copy.swift)
Running now · badge 3
1. Icon well: phone glyph · "iPhone 16 Pro" · "iOS 18.4, idle since Wednesday" · pill "1.2 GB"
2. Icon well: cube glyph · "Docker" · "No containers running, nothing using it" · pill "3.7 GB"
3. Icon well: server glyph · "3 leftover servers" · "Ports 3000 to 5173, from finished coding sessions" · pill "690 MB"
Taking up space · badge 2
4. Icon well: hammer glyph · "Xcode build cache" · "Xcode rebuilds this when needed" · pill "14 GB"
5. Icon well: disk glyph · "An old installer in Downloads" · "An installer you already used" · pill "1.1 GB"
Good to know · badge 2 (collapsed row with chevron; expands to two plain lines from Copy: "Spotlight is building its search index. It finishes on its own." and "Safari has about 40 tabs open (2.1 GB). Closing the ones you're done with helps. Tabs are never closed for you.")
Tidy up pill (44px, `--p-tint`, white 15px semibold rounded, return-key glyph 18px in a white 22 % key at its right end). Under it "Frees about 5.6 GB of memory and 15 GB of space".
Footer: "Checked just now" · sparkle + "Ask Claude" (tint text) · pause glyph · settings glyph.
Memory sum check: 1.2 + 3.7 + 0.69 = 5.59 → "5.6 GB"; space 14 + 1.1 = 15.1 → "15 GB". Any edit to a size must recompute both lines and the done header with a JS port of `Format.size`.

Each row: check (18px filled tint circle with a white tick; toggles; unchecking a row updates the pill caption and the count), icon well 28px tint 14 % circle with a 14px glyph, name 13px semibold, why 12px secondary (two lines max), size pill (the app's pill fill, 12px system font with tabular nums, since it is the app). Glyphs drawn as inline SVG strokes, never Apple's SF Symbols files.

Footer controls on the example (honest, never pretend to act on the visitor's Mac):
- Ask Claude: opens a small inline note inside the panel: "On your Mac this opens a new Claude chat with the question already written. Claude only gets the question." It never opens claude.ai from the site.
- Pause and settings: `aria-disabled="true"`, tooltip "Works in the app." Row hover controls (Keep, Hide, sparkle) appear on hover/focus like the app; Keep moves the row out with `leave` and shows the app's "On your Always keep list." line for 2 s, then the row returns (it is the example).

The label (FACTS, required): one quiet line under the panel, `--t-small` `--ink-2`, left-aligned to the panel: **"Example panel. On your Mac it lists what your Mac is actually carrying."**

### 3.4 Component API (`site/js/panel.js`)
`mountPanel(rootEl, { store, mode: 'hero' | 'popover', anchor: pebbleEl })` renders from `store.get()` and subscribes. Both instances (the hero panel and the menu bar popover) render the same state, so tidying in one shows in the other. Keyboard: the panel is a `role="dialog"` with `aria-label="YouFixIt, example panel"`; Tab order header → rows (checkbox) → Good to know (button, `aria-expanded`) → Tidy up → footer. **Return activates Tidy up or Undo whenever focus is inside the panel and not on another control** (the glyph must be true). Escape closes the popover (not the hero instance). Live region: `aria-live="polite"` announces the header text on each state change (the app's tooltip strings: "YouFixIt, 5 things to tidy, about 21 GB" / "YouFixIt, tidying up" / "YouFixIt, your Mac feels fine").

## 4. Global elements (architect / integrator)

### 4.1 The menu bar (the nav)
- `<header class="menubar">`, `position: sticky; top: 0`, full bleed, 36px tall (48px ≤ 720px), `--bar` material with backdrop blur, 1px `--line` bottom hairline. It is the page's real nav, styled as the place the app lives. Nothing fake in it: no Apple menu, no clock, no wifi, no other apps' icons (costume, and Apple's marks are banned).
- Left, on the 1200 column: the wordmark "YouFixIt" in Mona Sans 15px wght 650 (like an app name in the menu bar). Links to `#top`.
- Right, in this order: "Star it on GitHub" (text button: drawn star glyph + words, and `[data-stars]` count when ≥ 25) · "Download" (small `--go` pill, 28px tall; scrolls to and focuses the nearest email gate, never opens a modal) · the live pebble + count (button, `aria-haspopup="dialog"`, `aria-expanded`, `aria-label` = the app's tooltip string for the current state).
- At 390: wordmark left; right: the star glyph only (accessible name "Star it on GitHub"), the Download pill, the pebble. 48px tall, every target ≥ 44 × 44.
- Pebble click (anywhere on the page, any time): opens the popover instance of the panel under the pebble (`fold` from the pebble), right edge 16px from the viewport edge on desktop; at ≤ 720px a full-width sheet under the bar, max-height `calc(100svh - 64px)`, scrolls inside. Click outside, Escape or pebble again: `fold` closed, focus returns to the pebble. While the hero panel is on screen the pebble click just moves focus into the hero panel (no second copy on screen).

### 4.2 The haze and the favicon
As in §2.1. The haze is the single full-bleed colour moment the profile allows (Q42): it lives at the top of the page in the hero and fades out by 120vh (the layer is `position: absolute` in the hero wrapper, not fixed, so it is the hero's light, not a site-wide tint). After the hero only the favicon and the menu bar pebble carry the mood.

### 4.3 Footer (one line, Q23)
"© 2026 Yiftach Freeman · Legal · Source on GitHub", `--t-small`, `--ink-2`, centred under the finale. "Legal" goes to `/legal/` (a plain page with the three FACTS legal lines and the email note, same tokens, menu bar included, no panel).

### 4.4 The email gate (one component, two places: hero and finale)
- Markup: `<form class="gate" novalidate>` with a visually-associated label "Your email", one `<input type="email" autocomplete="email" inputmode="email" required>` at 16px, a hidden honeypot `company`, and the submit pill "Download for Mac" with the return glyph at its right end (true: Return submits).
- At rest the gate is the field and pill side by side in one 56px rounded capsule (field left, pill right inside it). At 390 they stack: field 52px, pill 52px, full width.
- One line under it, `--t-small` `--ink-2`, always visible: "Free. Your email goes to a sheet only the maker reads. The app itself never goes online."
- Submit: validate (`/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/`). Invalid → inline error under the field, `role="alert"`, in `--ink` with a 2px amber left rule: "That email looks incomplete. Add the part after the @." Valid → `navigator.sendBeacon(META_URL, new URLSearchParams({type:'mac', email, name:'', platform:'YouFixIt · ' + shortPlatform(), ref: document.referrer, company}))` (fallback `fetch(..., {method:'POST', mode:'no-cors', keepalive:true, body})`), then immediately `location.href = 'https://github.com/FreemanGT/YouFixIt/releases/latest/download/YouFixIt.dmg'`. The download never waits on the network.
- After submit the pill becomes "Downloading YouFixIt.dmg" for 4 s (perk), with a text link under it: "If it didn't start, download it directly." Then the line "Open the disk image and drag YouFixIt to Applications." stays.
- Remember the email in `localStorage` (try/catch). A returning visitor sees the field prefilled and one press downloads; nothing is sent twice for the same email.
- `<meta name="yf-signup" content="https://script.google.com/macros/s/AKfycbyYJTV8Mm_N77moH5FPesW6b_7Khdt2XHBn9IvVHSbHGw43RxAkXjgibvvWu-QkzNuMRA/exec">` in the head; the script reads it from there only.

## 5. Sections (six screens; each answers one visitor question)

Order and ids (template markers `<!-- @section:<id> -->`): `hero` · `face` · `finds` · `never` · `faq` · `finale`.
Sections join by tone, not rules: paper → paper → paper → paper → paper-2 (faq) → paper-2 (finale). Left-aligned sections on the 1200 column (Q27), centred finale.

### 5.1 `hero` · "What is it, and can I see it work right now?"
Layout, 1440 × 900: menu bar 36. Below it a two-column grid on the 1200 column: text column (1fr, max 620) and the panel column (380px, the app's true width) with 96px between. The panel hangs from the menu bar pebble: its top is 8px under the bar, `position: sticky; top: 44px`, its right edge on the column's right edge, so the pebble sits above the panel's right third, exactly where macOS puts a popover near the screen edge. The text column is vertically centred against the panel. Hero height `max(100svh, panel height + 120px)`. The haze rises from the pebble behind both. (Q61 allows the product beside the headline; the panel must hang from its pebble for the idea to be true, so the hero text sits left of it rather than centred, the one deliberate departure from Q27.)

Copy (final):
- H1: **"A little face in your menu bar that tidies your Mac when it gets heavy."**
- Sub (`--t-lead`, max 30 words): "YouFixIt notices the simulators, servers and caches you forgot about, and lets them go with one safe button. Nothing changes until you press it."
- The email gate (§4.4).
- Under the gate, one row: "Star it on GitHub" (text link with the drawn star and `[data-stars]`) · "Free forever. Open source." (`--ink-2`). Middle dot between.
- Under the panel: the required example label (§3.3) and, only in the `heavy` state, a second muted line that invites the one move: "Press Tidy up, or hit Return." It disappears for good once the visitor has touched the panel (Monocle: never ask twice).

Animation:
- Load: nothing animates in. The page is complete at first paint (panel in `heavy`, haze amber, favicon amber). After `load` + 1.2 s idle, the nav pebble and the panel's face do one `perk` together (the heavy lift), then `breathe` starts. That single perk links the two faces for the eye.
- Tidy up → §3.2 sequence. Rows `leave` (5 rows: 80ms steps, each 160ms; total ≈ 0.5 s), the menu bar count and the panel badge roll down in step, haze amber → green over 600ms, header swaps with `perk`, favicon swaps at `done`. Done hold, then the menu bar pebble `hop`s once.
- Undo → rows return top-down with `--ease-arrive` 220ms, staggered 80ms; count rolls up; haze back to amber.
- Scroll away (ScrollTrigger on the hero, desktop and mobile): when the hero's bottom passes 45 % of the viewport, the hero panel `fold`s closed into the menu bar pebble (scale .94 toward the pebble's centre, opacity 0, 160ms) and the pebble `perk`s; its grid slot keeps its size (visibility hidden, no CLS). Scroll back above the line and it `fold`s open (360ms). Not scrubbed: it behaves like a popover, open or closed, never half.

390 × 844 (a redesign, not a stack): menu bar 48. H1 at 2.375rem over three or four lines, sub, the gate (stacked, Download visible above the fold), then the panel full width (`calc(100vw - 32px)`), in flow, not sticky, 24px under the gate. No connector line to the menu bar pebble (costume); the shared state and the matching faces make the link. The panel shows the header, Running now (3 rows) and the Tidy up pill; Taking up space is collapsed behind "Taking up space · 2" so the whole panel fits in about 620px and Tidy up is reachable by the thumb. The fold-into-pebble on scroll works the same.

Reduced motion: no perk (instant pose swaps with a 120ms crossfade), rows cross-fade out together over 220ms instead of leaving by distance, the haze crossfades over 220ms, the fold becomes a 160ms opacity change, breathe keeps only the blink (no glance, no hop).

### 5.2 `face` · "How will I know when to open it?"
The answer is the face itself, at large scale: three live pebbles, each with one plain sentence. No cards (they are not objects), no icons beside them.

Layout desktop: left-aligned H2 on the column, then a row of three equal columns, each a pebble drawn 120 × 100 css px (the real geometry scaled; eye holes cut out) above its sentence. Generous air: section ~ 80vh.

Copy (final):
- H2: **"It only speaks up when it has something to say."**
- Calm pebble (ink, blinking): "Grey and quiet, like every other icon up there. Your Mac is fine."
- Green pebble with count "3": "Green, with a number. A few things you're not using are idling in the background."
- Amber pebble with count "5": "Amber means your Mac is struggling right now. Open it and let a few things go."
- One line under the three, `--ink-2`: "It watches quietly. Nothing changes until you press the button."

Interaction: each big pebble `breathe`s while on screen and its eyes `glance` toward the pointer when it is within 240px (pointermove, rAF-throttled, translate the eye mask by at most 2 units). Hover or tap a pebble: it plays its own pose once (calm blinks, green perks, amber lifts). That is all.

390: the three stack as rows: pebble 72 × 60 left, sentence right; same copy.
Reduced motion: blinks only, no glance follow, no perk.

### 5.3 `finds` · "What does it actually find on my Mac?"
Hoy's move: the list is a sentence you read, and the nouns are chips that came out of the app. No feature grid, no icons in a row.

Layout desktop: H2 left on the column; below it two paragraphs at `--t-h2`-adjacent size (Bricolage opsz 32, 1.75rem, wght 480, leading 1.5, max 30em), each chip inline. One muted line after.

Copy (final; chips in [brackets]; every noun is from FACTS "What Tidy up acts on"):
- H2: **"It looks for the things you started and forgot."**
- P1: "Running now: [apps you haven't touched in an hour], [Docker or OrbStack with nothing running], [iPhone simulators], [leftover dev servers], [idle build daemons], [headless test browsers] and [Homebrew services] nobody is connected to."
- P2: "Taking up space: [Xcode build caches], [old npx downloads], [developer tool caches], [Claude Code scratch folders], [caches left by removed apps], [old installers in Downloads] and [simulators that can't run anymore]."
- Muted line (`--ink-2`, `--t-body`): "Everything else goes under Good to know: Spotlight indexing, software updates, browsers with many tabs, open Claude sessions, virtual machines. It explains them and leaves the choice to you."

Chip: inline-flex, 0.85em tall icon well (tint 14 % circle, drawn stroke glyph) + the words, `--p-card` fill, radius 10px, padding .1em .5em, never wraps inside itself (`white-space: nowrap`; long chips may wrap between words at 390 via `box-decoration-break: clone`). Chips are `<button type="button" aria-describedby>`.

Interaction: hover, focus or tap a chip and a small bubble opens under it: one panel row exactly as the app writes it (icon well, name, why line in the app's secondary colour, system font), so the visitor reads how the app would say it. One bubble at a time; Escape or tap elsewhere closes. Bubble text (example values, from Copy.swift):
apps → "Untouched since Wednesday" · Docker/OrbStack → "No containers running, nothing using it" · simulators → "iOS 18.4, idle since Wednesday" · dev servers → "Port 3000 in my-app, from a finished coding session" · build daemons → "Gradle starts a fresh one on the next build" · test browsers → "Chrome (test copy)" + "Left by a script, holds no tabs" · Homebrew services → "Nothing is using it. Stays off until you start it again." · Xcode → "Xcode rebuilds this when needed" · npx → "38 packages unused for two weeks, npx fetches them again" · tool caches → "Tools refill this as they need it" · Claude Code scratch → "6 folders from sessions that ended days ago" · removed apps → "Left behind by a removed app" · installers → "An installer you already used" · broken simulators → "Their iOS version is gone".
Bubble motion: `fold` from the chip (scale .96 → 1, 220ms arrive). On itself: while a bubble is open, the menu bar pebble's eyes `glance` toward it (the app is watching what you look at). Same verb, no new motion.

390: the paragraphs at 1.375rem; bubbles open as a bottom-anchored row under the paragraph (full width), not floating, so they never clip.
Reduced motion: bubbles appear with a 120ms opacity change; no glance.

### 5.4 `never` · "Can I trust it with my Mac?"
Honesty as design (Hoy's "It's early." panel; the app's own "so it stays." voice).

Layout desktop: H2 left. Two columns below: left (7/12) the never-list as plain rows separated by `--line` hairlines, no icons, no bullets; right (5/12) three replica cards (these are app rows, so cards are right) showing the app refusing, under the label "From the app, with example names." in `--t-small` `--ink-2`.

Copy (final):
- H2: **"When in doubt, it stays."**
- Lead: "Every suggestion is checked twice: when it's found, and again the moment you press the button."
- Never-list rows:
  1. "It never force-quits. Apps are asked to quit the normal way, so they can ask to save."
  2. "It never deletes anything on its own. Files go to the Trash, and Undo brings closed apps back for a minute."
  3. "It never closes what's in front of you, what's playing audio, or anything showing a dialog."
  4. "It never stops something busy, and never moves a folder something wrote to in the last ten minutes."
  5. "It never touches terminals, editors, browsers or their tabs, messaging, password managers, VPNs, sync or remote access."
  6. "It never touches anything that belongs to macOS or another user."
- Replica cards (system font, panel tokens, grey 28px icon well, name + the app's refusal line):
  - "Preview" · "It has a dialog open, so it stays."
  - "Podcasts" · "It's playing audio, so it stays."
  - "tmux" · "It holds terminal sessions, so it stays."
- Under both columns, one line with the sparkle glyph: "Not sure about a row? Press the sparkle and it opens a new Claude chat with the question already written. Claude only gets the question; nothing changes until you press one of YouFixIt's own buttons."

Animation: none on scroll. The replica cards respond to hover like the app's cards (fill to card hover, 120ms). Static is the point: this section is the quiet one.
390: H2, lead, the six rows, then the three cards full width, then the Ask Claude line.

### 5.5 `faq` · "What else should I know before I install it?"
Plain rows (Q71), `paper-2` tone begins here and continues into the finale (one blended seam). `<details>` rows with a drawn chevron, hairline separators, no cards. FAQPage JSON-LD generated from the same text at build time (`build.mjs` reads the section HTML).

- H2: **"Plain answers."**
1. "Does it cost anything?" · "No. YouFixIt is free forever and open source under the MIT License. It's a gift to the community."
2. "Which Macs does it run on?" · "macOS 14.4 or newer, on Apple silicon and Intel. It's signed with a Developer ID and notarized by Apple."
3. "Will it delete my files?" · "Never on its own. Anything it clears from disk goes to the Trash first. Emptying the Trash or removing a simulator only happens from a Good to know button, and it asks you first, right in the row."
4. "What happens to the apps it closes?" · "They're quit the normal way, so they can ask to save. Programs get a polite stop signal. Press Undo within a minute and the apps come back."
5. "Will it close my terminal or my Claude sessions?" · "No. Anything that is or holds a terminal stays. Open Claude coding sessions are only explained under Good to know, and Claude Code worktrees are never picked for you."
6. "Does it send anything anywhere?" · "No. The app has no network, no account and no analytics. Ask Claude hands its question to the Claude app or claude.ai in your browser, with your home folder written as ~ and anything that looks like a password or token blanked out."
7. "Why isn't it on the Mac App Store?" · "It has to see other programs to help with them, so it can't be sandboxed. You get it here or on GitHub."
8. "How do I get new versions?" · "There's no automatic updater. The download here always points to the newest release on GitHub."

Motion: `<details>` open/close: content height via `interpolate-size: allow-keywords` + `::details-content` transition 220ms arrive where supported; otherwise instant. Chevron rotates 90° in 120ms.
390: same rows, 52px minimum tap height.

### 5.6 `finale` · "Where do I get it, and what's the catch?"
The big idea returns: the face, large, remembering what you did on this page. Centred (Q23), on `paper-2`, one screen.

Layout desktop, top to bottom, centred: the big pebble (180 × 150 css px, the real geometry) · the giant line · one sentence · the gate · the star button · the requirements line · footer.

Copy (final):
- Giant (`--t-giant`, may wrap to two lines at 390): **"Free forever."**
- Sentence (`--t-lead`): "YouFixIt is a gift to the community. Open source under the MIT License, no account, nothing to pay, now or later."
- The email gate (§4.4), same component and copy as the hero.
- Star button (tonal pill, 48px, drawn star + words + `[data-stars]`): "Star it on GitHub" → https://github.com/FreemanGT/YouFixIt
- Requirements (`--t-small`, `--ink-2`): "macOS 14.4 or newer · Apple silicon and Intel · Signed and notarized by Apple"
- Footer line (§4.3).

The pebble remembers (on itself, the payoff): it reads the store when the finale enters view (IntersectionObserver, 40 %).
- If the visitor tidied (`done` or `empty`): the pebble is green with the smile, plays one `hop`, caption under it (`--t-small`, `--ink-2`): "You tidied the example. Your own Mac is next."
- If not (`heavy`): the pebble is amber with its count, lifted, and `glance`s at the gate. Caption: "The example Mac is still carrying 5 things. Press the face to tidy it." Pressing the big pebble opens the menu bar popover (the one panel, `fold` from the menu bar pebble), not a second panel.
- The finale's background picks up the same haze for this one screen (green after tidy, amber before), at half strength, from the big pebble: the page's light comes back where the idea comes back.

390: pebble 120 × 100, giant "Free forever." at ~19vw on two lines, gate stacked full width, star button full width, requirements wrap on the dots.
Reduced motion: no hop or glance; the pose and caption still reflect the state.

## 6. Performance plan
- Budget: JS ≤ 90 KB gz total (GSAP core 28 + ScrollTrigger 18 + CustomEase 3 + site modules ~20). Well under the 350 KB ceiling: no WebGL, no Lenis, no video, no images in the page except the OG and the favicon. Every visual is HTML, CSS or inline SVG.
- Fonts: three variable subsets, ≤ 120 KB woff2 total; preload Bricolage (hero H1) and Mona Sans; Geist Mono loads lazily (`font-display: swap`, used below the fold and in the nav star count). Metric-matched fallbacks so the swap does not move the H1.
- LCP is the H1 text (target < 1.5 s on 4G). The panel is server-rendered HTML in its `heavy` state inside `index.html` (build.mjs stitches it), so it paints with the page; JS only hydrates it.
- One ticker (GSAP), paused when `document.hidden`; `breathe` runs only on pebbles inside the viewport (IntersectionObserver). No scroll listeners besides one ScrollTrigger (hero fold) and one IntersectionObserver (finale).
- Animate only transform, opacity and clip-path. Row `leave` collapses height via a `grid-template-rows: 1fr → 0fr` wrapper transition, contained inside the panel (`contain: layout paint`), so the page never shifts. The hero panel's grid slot keeps its size when folded: zero CLS.
- `backdrop-filter` only on the 36px menu bar. The haze layers are `contain: strict`, two gradients, opacity-only crossfades.
- `vercel.json`: `cleanUrls`, long cache (`public, max-age=31536000, immutable`) for `/vendor/*`, `/fonts/*`, hashed `/css` `/js`; `max-age=0, must-revalidate` for HTML; `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, a CSP allowing `connect-src https://api.github.com https://script.google.com` and nothing else third-party. The download link points at GitHub, not Vercel.

## 7. Accessibility
### 7.1 Always
- `:focus-visible` ring: 2px `--go` + 2px paper offset, on every control including chips, pebbles, rows and `<summary>`.
- The panel is fully keyboard-operable (§3.4); Return is true. Touch targets ≥ 44px at ≤ 720px.
- Every pebble has a text equivalent (the app's tooltip strings). The example label is real text, not an `aria-hidden` decoration.
- Contrast pairs recorded in §1.2; the builder re-runs the contrast script on the final CSS and fails the build under 4.5 (text) or 3 (graphics, focus ring).
- No overflow at 320px: the panel becomes `calc(100vw - 24px)`, the giant line clamps, chips wrap between words.

### 7.2 `prefers-reduced-motion: reduce`
Every frame is a poster and nothing is hidden: no perk springs (120ms crossfades), rows cross-fade together, no glance or pointer follow, no hop, the hero fold is a 160ms opacity change, the haze crossfades in 220ms, the star count appears without rolling, the blink stays (it is 90ms and it is the face). Shorter and calmer, never a still edition (Q60).

## 8. SEO and share
- `<title>`: "YouFixIt · A little face in your menu bar that tidies your Mac"
- Description: "YouFixIt notices the simulators, servers and caches you forgot about and lets them go with one safe button. Free forever, open source, for macOS 14.4 or newer."
- Canonical https://getyoufixit.vercel.app/. OG and Twitter card 1200 × 630 from `web/og.html`, rendered with headless Chrome: bone paper, the H1 in Bricolage at 64px left, the panel in its `done` state on the right ("Freed up 21 GB", smile face, Undo), the menu bar strip across the top with the green pebble, a soft green haze from it. Small "Example panel." in the corner. Dark variant not needed.
- JSON-LD: `SoftwareApplication` (name, operatingSystem "macOS 14.4 or later", applicationCategory "UtilitiesApplication", offers price 0 USD, license MIT URL, downloadUrl the GitHub latest link, codeRepository) and `FAQPage` from §5.5. No `aggregateRating` (none exists).
- `/legal/` page (§4.3) and a `404.html`: the pebble in `paused` pose, "Nothing here. The page you wanted was tidied away, or never existed." and a link "Back to YouFixIt".

## 9. Ownership (one writer per file)
- Architect/integrator: `web/index.html` template, `web/build.mjs`, `site/css/tokens.css`, `site/css/base.css` (menu bar, gate, footer, haze), `site/js/main.js`, `site/js/lib/{store,pebble,motion,favicon,haze,signup,stars}.js`, `site/vercel.json`, `legal/`, `404.html`, `og.html`, fonts and vendor.
- Hero builder: `web/sections/hero.html`, `site/css/panel.css`, `site/css/hero.css`, `site/js/panel.js`, `site/js/hero.js`.
- Section builders: `face`, `finds`, `never`, `faq`, `finale`, each `web/sections/<id>.html` + `site/css/<id>.css` + `site/js/<id>.js` (faq may need no JS).

## 10. Cut on purpose (so nobody adds them back)
Intro or loader · device frame or laptop render · fake menu bar items (Apple menu, clock, wifi, other apps) · scroll reveals of text · a product tour of pinned scenes (the hero panel already shows every state by touch) · a feature grid · "how it works" icons · stat counters, user counts, "GB freed on average" · testimonials, logos, ratings · a newsletter block · section numbers, eyebrows, scroll meters · a marquee · a dark-mode toggle · analytics and cookie banners · the version number in the hero · any red, any warning copy.
