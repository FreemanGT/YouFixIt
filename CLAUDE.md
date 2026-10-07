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

Rules: safety first (never-lists in `Safety.swift` are evaluated at scan time and again at apply time; an app with CPU or disk traffic over the idle window is "busy" and never a row; a cache folder written to in the last 10 minutes is never trashed; nothing is ever force-quit or deleted outright, disk cleanup goes to the Trash). Every user-facing string lives in `Copy.swift`; every colour, size and duration in `Theme.swift`. New rules are pure functions in `Rules.swift` with a fixture in `Fixtures.swift`.

## Skill routing

When the user's request matches an available skill, invoke it via the Skill tool. Route only to skills in the session's available-skills list; answer directly for quick questions or small scoped edits.

Key routing rules:
- Product ideas/brainstorming → invoke /office-hours
- Strategy/scope → invoke /plan-ceo-review
- Architecture → invoke /plan-eng-review
- Design system/plan review → invoke /design-consultation or /plan-design-review
- Full review pipeline → invoke /autoplan
- Bugs/errors → invoke /investigate
- QA/testing site behavior → invoke /qa or /qa-only
- Code review/diff check → invoke /review
- Visual polish → invoke /design-review
- Ship/deploy/PR → invoke /ship or /land-and-deploy
- Save progress → invoke /context-save
- Resume context → invoke /context-restore
