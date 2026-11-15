# FACTS · YouFixIt site (law)

Every sentence on the site must trace to a line here or to the named source. If it is not here, it does not go on the page.
Sources: `README.md`, `Sources/YouFixIt/Copy.swift` (every string the app shows), `Sources/YouFixIt/Theme.swift` (colours, sizes, motion), `Sources/YouFixIt/StatusIcon.swift` (the face), `Sources/YouFixIt/PopoverView.swift` and `FindingRow.swift` (the panel), `Sources/YouFixIt/Safety.swift` (the never-lists), `Info.plist`, `LICENSE`, GitHub release v0.5. Renders of every panel state, light and dark: `snapshots/*.png` (local only, gitignored; read them, do not publish them as-is).

## What it is
- Name: **YouFixIt** (capital Y, F, I; never "YouFixit", "You Fix It" or "YFI"). A small face in the Mac menu bar that notices when the Mac is struggling and offers one safe button. (README line 3)
- GitHub description: "A pebble in your menu bar that notices when your Mac is struggling and tidies it with one safe button".
- How it behaves: it watches quietly. When something the person is not using weighs the Mac down, the face turns green and shows how many things it found; amber means the Mac is struggling right now. Open it, read the plain-words list, press **Tidy up**. (README)
- Apps it closes can be reopened with **Undo** for a minute (60 s, `Theme.undoWindow`). Anything it clears from disk goes to the Trash first. (README, Copy.undoCaption "You can undo for the next minute.")
- Nothing changes until you press the button. (Copy.welcome3, Copy.subLight)

## The face (menu bar icon)
- A pebble: rounded rectangle 18 x 15 pt, corner radius 7.5, two round eye holes cut out (radius 1.3, 3 pt apart), drawn on a 22 pt canvas. (Theme, StatusIcon)
- Moods and poses: calm (grey, like other menu bar icons) · blink · glance (eyes look aside) · light (green, something to tidy) · heavy (amber, eyes bigger, lifted 1 pt: the Mac is struggling) · working (eyes down, slightly squashed) · done (smile arcs) · hop (smile, lifted 2 pt) · paused (grey, eyes closed, faded). Green and amber poses can carry a count next to the face. (StatusIcon.Pose, snapshots/icon-poses-*.png)
- Menu bar fills: green #259E80 (0.145, 0.620, 0.500), amber #EDA833 (0.930, 0.660, 0.200). (Theme.barGreen, barAmber)

## The panel (the living hero; rebuild it from the source, it is the product)
- 380 pt wide, max 560 tall, opaque window background, cards radius 14 with a soft fill and no border, 6 pt between cards, 4 pt grid. (Theme)
- App accent (tint): light #177D66 (0.090, 0.490, 0.400); dark #19846B. Accent as text in dark: #66CCAB. Amber face: light #D99A2B, dark #F0B445. Tonal pill = accent at 14 %. White on accent. (Theme)
- Type in the app is SF Pro / SF Pro Rounded with monospaced digits (title 17 semibold rounded, hero 24 semibold rounded, body 13, caption 12, button 15 semibold rounded). On the web, SF is only available on Apple devices via `system-ui`/`-apple-system`; the rebuilt panel may use the system stack so it looks like the real app. The site's own display face is a separate choice.
- Motion in the app: feedback 0.12 s, state 0.22 s, overlay 0.36 s, exit 0.16 s, count roll 0.6 s, stagger 0.08 s (cap 5), blink 0.09 s, smile hold 1.2 s; arrive/settle curve cubic-bezier(0.16, 1, 0.3, 1); perk = spring 0.45 s bounce 0.25; hop = spring 0.5 s bounce 0.3; pressed pill scales to 0.98. (Theme)
- Exact header strings: "Your Mac feels fine." · "A few things are idling in the background." + "Nothing changes until you press the button." · "Your Mac is working hard. Here's what you can let go." + "Letting these go helps right away." · "Tidying up…" · "Freed up {size}" + "Your Mac has more room to breathe." · "Nothing to tidy." + "Your Mac is doing great." (Copy)
- Sections: "Running now", "Taking up space", "Good to know" (with a count badge). Primary pill: "Tidy up" with a return-key glyph at its right end; under it "Frees about {X} of memory and {Y} of space". Done state: tonal "Undo" pill + "You can undo for the next minute." Footer: "Checked just now" · "Ask Claude" (sparkle) · pause · settings. Row controls on hover: Keep, Hide, Ask Claude sparkle. (Copy, snapshots)
- Real "why" lines the app writes (use these, with example values): "Untouched since Wednesday" · "No containers running, nothing using it" · "Port 3000 in my-app, from a finished coding session" · "3 leftover servers" / "Ports 3000 to 5173, from finished coding sessions" · "Gradle starts a fresh one on the next build" · "Left by a script, holds no tabs" · "Xcode rebuilds this when needed" · "Tools refill this as they need it" · "Left behind by a removed app" · "An installer you already used" · "Their iOS version is gone" · "Nothing is using it. Stays off until you start it again." · "{n} packages unused for two weeks, npx fetches them again" · "{n} folders from sessions that ended days ago". (Copy)
- Refusal lines (great proof of safety, real strings): "You're using it right now, so it stays." · "It's playing audio, so it stays." · "It has a dialog open, so it stays." · "It's busy with something, so it stays." · "Something is connected to it, so it stays." · "Part of macOS, so it stays." · "It holds terminal sessions, so it stays." · "{App} asked to save first, so it stayed open." (Copy)
- **Any rows shown in a demo are examples and must be labelled as an example** (one quiet line such as "Example panel. On your Mac it lists what your Mac is actually carrying."). Use neutral example names: Docker, an iPhone simulator, leftover dev servers, Xcode build cache, an old installer in Downloads, an app untouched since Wednesday. Never the owner's private project names, never real people's data.

## What Tidy up acts on (README; any subset may be featured, never extended)
Apps untouched for an hour with no window open and nothing going on inside them · Docker Desktop or OrbStack with no containers running · iPhone simulators nothing is using · dev servers in any language (Node, Bun, Deno, PHP, Python, Ruby) left behind by finished coding sessions with nobody connected · idle Gradle and Kotlin build daemons · headless test browsers · Homebrew services nothing is connected to (stopped and taken off the login list; Undo puts them back) · old npx downloads · Claude Code's scratch folders from sessions that ended days ago · Xcode build and preview caches · download caches of developer tools (npm, pnpm, Yarn, pip, Homebrew, CocoaPods, Gradle, Maven, Go, Cargo, Bun) · caches left behind by removed apps · old installers in Downloads · unusable simulators.

## Good to know (README)
Explains the rest; most rows have a button of their own for when you decide (Stop, Quit, Move to Trash, Skip this backup, Restart…, Empty Trash…, Remove…). Nothing there is ever selected for you, and the buttons that delete for good ask first, right in the row. Spotlight and Photos indexing, software updates, browsers with many tabs, open Claude coding sessions, virtual machines, memory pressure, thermal throttling, login items and worktrees with uncommitted changes are only explained, with a link to where you can act. Claude Code worktrees are never pre-selected, because a Claude session may still use one.

## Ask Claude (README, release v0.5)
A sparkle on every row and "Ask Claude" in the footer for everything at once. It opens a new Claude chat, in the Claude app or on claude.ai, with the question already written: what the thing is, what YouFixIt's button would do, and the folders or command lines behind it, so Claude can say whether it is safe to let go. The home folder shows as ~, anything that looks like a password or token is blanked out. Claude only gets the question; nothing on the Mac changes until you press one of YouFixIt's own buttons.

## Safety (README; the never-list, verbatim meaning)
It never force-quits · never deletes anything on its own · never touches anything owned by macOS or another user · never closes what is in front of you, playing audio or showing a dialog · never stops something busy with CPU or disk work unless you press that row's own button · never moves a folder something wrote into in the last ten minutes · never closes terminals, editors, browsers, messaging, password managers, VPNs, sync, remote access or media apps (Safety.neverBundles) · never touches browser tabs (Copy.never3). Apps are quit the normal way so they can ask to save; programs get a polite stop signal (Copy.askHow). Undo for a minute.

## Privacy and plain facts
- The app: no network, no account, no analytics. YouFixIt itself never goes online; Ask Claude hands its question to the Claude app or claude.ai in your browser. (README)
- Not sandboxed: it has to see other processes to help with them. (README) Not on the Mac App Store.
- The site: the email typed before the download is sent to the maker's Google Sheet (script.google.com) and nowhere else. Say so plainly next to the field. No cookies, no analytics on the site.

## Money, licence, download
- Price: **free**. Open source under the **MIT License**, © 2026 Yiftach Freeman. (LICENSE)
- "Free forever" and "a gift to the community": the maker's own words for this site (client brief 2026-11-15); allowed as the maker's promise.
- Source and stars: https://github.com/FreemanGT/YouFixIt (public). The star count is live data: fetch `https://api.github.com/repos/FreemanGT/YouFixIt` client-side and show `stargazers_count` only when it is 25 or more; below that, the button says "Star it on GitHub" with no number. Never a hard-coded count. On fetch failure, no number.
- Download: `https://github.com/FreemanGT/YouFixIt/releases/latest/download/YouFixIt.dmg` (always the newest release; v0.5 today, 4.4 MB DMG). Developer ID signed and notarized by Apple. Universal (Apple silicon and Intel). macOS 14.4 or newer. Install: open the disk image and drag YouFixIt to Applications. (release v0.5 notes, build.sh, Info.plist)
- Current version: 0.5 (Info.plist). Do not print the version in the hero; if shown at all, read it from nowhere hard-coded except a single constant in one file.

## Email gate (the client's rule Q94 + their pick 2026-11-15)
- Email is required before the download; the DMG starts the moment a valid email is entered; the download never waits on the network.
- POST form-encoded (e.g. `navigator.sendBeacon(url, new URLSearchParams(...))`, or `fetch` with `mode: 'no-cors', keepalive: true`) to the shared Apps Script web app: `https://script.google.com/macros/s/AKfycbyYJTV8Mm_N77moH5FPesW6b_7Khdt2XHBn9IvVHSbHGw43RxAkXjgibvvWu-QkzNuMRA/exec` (put it in one `<meta name="yf-signup">`). Fields: `type=mac`, `email`, `name` (empty), `platform` = `YouFixIt · ` + a short platform string, `ref` = document.referrer, honeypot `company` (hidden, never filled by humans). Then start the download immediately (navigate to the DMG URL).
- One field, 16 px input, inline error in plain words ("That email looks incomplete. Add the part after the @."), Return submits. Remember the email in localStorage so a returning visitor downloads in one press (still sends nothing twice).

## Not allowed (hard)
- Invented numbers: users, downloads, stars, GB freed "on average", speed-up percentages, battery gains, ratings, reviews, testimonials, "trusted by", press logos, awards.
- "AI-powered", "smart AI", "machine learning": the app is plain rules; Ask Claude only writes a question for Claude.
- "Cleans viruses/malware", "antivirus", "boosts performance by X%", "optimizes RAM", "deep clean", "junk files", any CleanMyMac-style scare copy or red warnings.
- "Deletes": it moves to the Trash. Never say it force-quits, kills, or closes anything without a press.
- Apple logo, App Store badge, Anthropic or Claude logos (the words "Claude" and "Ask Claude" are fine as the feature's name). Never imply affiliation with Apple or Anthropic.
- Automatic updates (there is no updater), Windows/Linux versions, a paid tier, a waitlist.
- The owner's private project or client names in demo rows (FreeFlow, Saves, Real Woo AI, etc.).

## Legal lines (on a small /legal page, linked from the footer; the footer itself shows only the copyright)
"© 2026 Yiftach Freeman. YouFixIt is open source under the MIT License." · "Mac and macOS are trademarks of Apple Inc. Claude is a trademark of Anthropic. YouFixIt is an independent project, not affiliated with either." · Email note: what is collected (the email, the referrer, a platform string), where it goes (a Google Sheet the maker reads), why (to say hello and share news about YouFixIt, rarely), and that a reply asking to be removed is honoured.

## Language and voice
English only. US spelling where it differs. The app's own voice: plain, warm, short sentences, "so it stays." No em dashes, no emoji, no exclamation marks, no rhetorical questions (profile §10).
