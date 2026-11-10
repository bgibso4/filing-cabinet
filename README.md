# Filing Cabinet

A private, on-device document library for iPhone. Scan receipts, IDs and cards; they're filed into smart collections automatically, and old ones clean themselves up.

Nothing leaves the phone: scanning (VisionKit), understanding (Vision) and filing all run on-device. There are no accounts. Analytics are anonymous counts only, never document content.

**Status:** engineering foundation in place; no features yet.

## Stack

iPhone only, portrait, iOS 27 minimum. Swift 6, SwiftUI, SwiftData, Swift Testing. The Xcode project is generated with XcodeGen from `project.yml`; all logic lives in the local package `Packages/FilingCabinetKit`.

## Getting started

Requires Xcode 27, XcodeGen, SwiftLint and Periphery (`make setup` checks for them).

```sh
make setup   # install the pre-commit hook, generate the project
make build   # build for the pinned simulator (FC iPhone 17: iPhone 17, iOS 27.0)
make fast    # unit tests on macOS, no simulator
make affected  # the simulator tests your changes touch
make full ALL=1  # everything on the simulator: package, snapshot and UI tests
make ci      # everything CI runs
```

`AGENTS.md` has the full command list, the architecture and the project's rules.

## Docs

- Requirements: `docs/superpowers/specs/2026-10-10-filing-cabinet-requirements.html`
- Engineering foundations: `docs/superpowers/specs/2026-10-31-engineering-foundations-design.md`
- Design handoff: `design/README.md`
