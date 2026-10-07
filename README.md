# YouFixIt

A small face in your menu bar that notices when your Mac is struggling and offers one safe button.

It watches quietly. When something you are not using is weighing the Mac down, the pebble turns green and shows how many things it found; amber means the Mac is struggling right now. Open it, read the plain-words list, press **Tidy up**. Apps it closes can be reopened with **Undo** for a minute, and anything it clears from disk goes to the Trash first.

It acts on: apps untouched for an hour with no window open and nothing going on inside them, Docker Desktop or OrbStack with no containers running, iPhone simulators nothing is using, dev servers (with nobody connected) and headless test browsers left behind by finished coding sessions, Xcode build and preview caches, download caches of developer tools (npm, pnpm, Yarn, pip, Homebrew, CocoaPods, Gradle, Maven, Go, Cargo, Bun), caches left behind by removed apps, old installers in Downloads, and unusable simulators.

It explains, and never touches: Spotlight and Photos indexing, Time Machine, software updates, browsers with many tabs, open Claude coding sessions, Parallels and other virtual machines, Homebrew services, menu bar apps holding memory, whatever has been working hard in the background for minutes, memory pressure, thermal throttling, apps that open at login, long uptimes, tool folders that would need reinstalling, and leftovers of other kinds.

It never force-quits, never deletes outright, never touches anything owned by macOS or another user, never closes what is in front of you, playing audio, showing a dialog, or busy with CPU or disk work, and never moves a folder something wrote into in the last ten minutes.

## Build

Needs Xcode 26 or newer.

```bash
./build.sh install        # universal release build, ad-hoc signed, installed to /Applications and opened
swift build               # debug build for iteration
.build/debug/YouFixIt --selftest           # rules, safety, spike detector, nudge budget, disk rows, wording
.build/debug/YouFixIt --scan --window 60   # watch this Mac from the terminal; N shrinks the idle thresholds
.build/debug/YouFixIt --mock heavy         # run the UI on a fixture
.build/debug/YouFixIt --snapshot snapshots # render every state to PNG, light and dark
./build.sh dmg                             # dist/YouFixIt.dmg
./build.sh release                         # Developer ID signed, notarized, stapled
```

macOS 14.4 or newer. Not sandboxed: it has to see other processes to help with them. No network, no account, no analytics.
