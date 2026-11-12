# YouFixIt

A small face in your menu bar that notices when your Mac is struggling and offers one safe button.

It watches quietly. When something you are not using is weighing the Mac down, the pebble turns green and shows how many things it found; amber means the Mac is struggling right now. Open it, read the plain-words list, press **Tidy up**. Apps it closes can be reopened with **Undo** for a minute, and anything it clears from disk goes to the Trash first.

**Tidy up** acts on: apps untouched for an hour with no window open and nothing going on inside them, Docker Desktop or OrbStack with no containers running, iPhone simulators nothing is using, dev servers in any language (Node, Bun, Deno, PHP, Python, Ruby) left behind by finished coding sessions with nobody connected (small ones share a row), idle Gradle and Kotlin build daemons, headless test browsers, Homebrew services nothing is connected to (stopped and taken off the login list; Undo puts them back), old npx downloads, Claude Code's scratch folders from sessions that ended days ago, Xcode build and preview caches, download caches of developer tools (npm, pnpm, Yarn, pip, Homebrew, CocoaPods, Gradle, Maven, Go, Cargo, Bun), caches left behind by removed apps, old installers in Downloads, and unusable simulators.

**Good to know** explains the rest, and most rows there come with a button of their own for when you decide: Stop a database or program a coding session left running, a busy program, or a Homebrew service that is in use; Quit a menu bar app holding memory, or an app that has kept the Mac awake for an hour; Move a big app cache, a tool folder that needs reinstalling, or Claude Code worktrees nothing has touched for a day to the Trash (merged ones, ones that still hold local files such as an .env, and unmerged ones whose branches keep the commits; never selected for you, because a Claude session may still use one); Skip a Time Machine backup; open the Restart window after a long uptime; Empty the Trash; remove an old simulator or test iPhone. Nothing there is ever selected for you, and the buttons that delete for good ask first, right in the row. Spotlight and Photos indexing, software updates, browsers with many tabs, open Claude coding sessions, virtual machines, memory pressure, thermal throttling, apps that open at login and worktrees with uncommitted changes are only explained, with a link to where you can act.

It never force-quits, never deletes anything on its own, never touches anything owned by macOS or another user, never closes what is in front of you, playing audio or showing a dialog, never stops something busy with CPU or disk work unless you press that row's own button, and never moves a folder something wrote into in the last ten minutes.

## Build

Needs Xcode 26 or newer.

```bash
./build.sh install        # universal release build, ad-hoc signed, installed to /Applications and opened
swift build               # debug build for iteration
.build/debug/YouFixIt --selftest           # rules, safety, spike detector, nudge budget, disk rows, wording
.build/debug/YouFixIt --scan --window 60   # watch this Mac from the terminal; N shrinks the idle thresholds
.build/debug/YouFixIt --scan --window 60 --apply ID --then-undo   # run one row's action, then take it back
.build/debug/YouFixIt --scan --window 60 --explain PID            # why a process is, or is not, a row
.build/debug/YouFixIt --mock heavy         # run the UI on a fixture
.build/debug/YouFixIt --snapshot snapshots # render every state to PNG, light and dark
./build.sh dmg                             # dist/YouFixIt.dmg
./build.sh release                         # Developer ID signed, notarized, stapled
```

macOS 14.4 or newer. Not sandboxed: it has to see other processes to help with them. No network, no account, no analytics.
