@AGENTS.md

# Claude Code notes

Rules, commands and the definition of done are in AGENTS.md. This file holds what is specific to Claude Code.

## Where we are

**Phase: Plan 4 (favorites, search and share) is approved and committed on branch `plan-4`; execution has not started.** Plans 1–3 are merged. The plan is `docs/superpowers/plans/2026-11-09-04-favorites-search-share.md`. Execution waits for the test-improvements PR (`make affected`, `make retest`) to merge; then merge `main` into `plan-4` and start Task 1.

- Requirements win over the design spec and this file (for example, iOS 27 minimum). `docs/superpowers/specs/2026-07-12-filing-cabinet-design.md` is superseded: history only.
- We work mock-driven: build what `design/` shows; raise anything it doesn't cover rather than guessing in code.
- Process is Superpowers: brainstorming → spec → plan → TDD → verification. No feature code without an approved plan.

## Hooks (committed in `.claude/settings.json`, scripts in `scripts/hooks/`)

- **Stop / SubagentStop gate** (`stop-gate.sh`): runs `make fast` only when the Swift content fingerprint differs from `.build/fc-fast-green` (any edit method; survives commits). Failing tests and compiler errors lead the block message. After 3 failed attempts it hands back with a message. Internal errors block loudly. If `jq` is missing it fails open with a message.
- **Format on edit** (`format-on-edit.sh`): formats edited Swift files.
- **Guards** (PreToolUse): `guard-generated.sh` blocks edits to the generated `.xcodeproj` and `Generated/`; `guard-hook-bypass.sh` blocks the git hook-bypass flags named in AGENTS.md's hard rules.
- A green Stop gate means the Fast (macOS) tests pass. It does not compile the Screens, App or UI test targets: run `make build` / `make full` per the definition of done.
- Hook behaviour is covered by `make test-hooks`. Changing hook config needs Ben's OK.

## Verification

Use the `ios-verifier` agent for build/test evidence (see the definition of done in AGENTS.md).

For a task, run the snapshot and UI tests for the screens it touched with `make full ONLY="FilingCabinetUITests/<Class> FilingCabinetSnapshotTests/<Class>"`. CI runs `checks` on every push; the simulator suite runs on `main` and once a PR is ready for review (not on drafts, and not when a PR changes only `docs/` and Markdown).

## Workspace

- Personal agent tooling (XcodeBuildMCP, Axiom, SwiftUI skills) comes from arsenal's `ios` profile via `arms apply`: local scope, uncommitted.
- `.claude/settings.json` (project hooks) IS committed here, by approved exception. **Never commit** `.claude/skills/`, `skills-lock.json`, `.claude/settings.local.json` or `.herdr/`.
- Remote: github.com/bgibso4/filing-cabinet (public). CI runs on PRs and pushes to `main`.
