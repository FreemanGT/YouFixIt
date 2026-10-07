# YouFixIt

A small face in your menu bar that notices when your Mac is struggling and offers one safe button.

It watches quietly. When something you are not using is weighing the Mac down, the pebble perks up. Open it, read the plain-words list, press **Tidy up**. Apps it closes can be reopened with **Undo** for a minute, and anything it clears from disk goes to the Trash first.

It acts on: apps untouched for an hour with no window open, iPhone simulators nothing is using, dev servers and headless test browsers left behind by finished coding sessions, Xcode build caches, download caches of developer tools, caches left behind by removed apps, old installers in Downloads, and unusable simulators.

It explains, and never touches: Spotlight and Photos indexing, Time Machine, software updates, browsers with many tabs, open Claude coding sessions, memory pressure, thermal throttling, apps that open at login, long uptimes, and leftovers of other kinds.

It never force-quits, never deletes outright, never touches anything owned by macOS or another user, never closes what is in front of you, playing audio, or showing a dialog.

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
