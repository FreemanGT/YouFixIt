# YouFixIt

Menu-bar app that notices when the Mac is struggling and tidies it with one safe button. Swift 6, SwiftUI views, AppKit shell, SwiftPM executable packed into an .app by `build.sh`. No Xcode project. Plan and rationale: `~/.claude/plans/pasted-content-id-74f8-i-want-mighty-wozniak.md`.

- `swift build` — debug build for iteration (`.build/debug/YouFixIt`)
- `./build.sh` — universal release app in `build/`, ad-hoc signed
- `./build.sh install` — replace `/Applications/YouFixIt.app` and open it
- `.build/debug/YouFixIt --selftest` — fixture-based checks of every rule, the spike detector and the safety filter
- `.build/debug/YouFixIt --scan [--window N]` — sample this Mac and print findings as text (N scales idle thresholds, in seconds)
- `.build/debug/YouFixIt --scan --apply ID [--then-undo]` — run one finding's action from the CLI
- `.build/debug/YouFixIt --mock NAME` — run the UI on a fixture (no sampling, actions are pretend)
- `.build/debug/YouFixIt --snapshot DIR` — render every popover state and the icon poses to PNG

Rules: safety first (never-lists in `Safety.swift` are evaluated at scan time and again at apply time; nothing is ever force-quit or deleted outright, disk cleanup goes to the Trash). Every user-facing string lives in `Copy.swift`; every colour, size and duration in `Theme.swift`. New rules are pure functions in `Rules.swift` with a fixture in `Fixtures.swift`.
