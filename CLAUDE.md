@AGENTS.md

# Claude Code notes

Rules, commands and the definition of done are in AGENTS.md. This file holds what is specific to Claude Code.

## Where we are

**Phase: Plans 1–6, the AI follow-up and the library lock are merged (Plan 6: PR #96, 2026-11-14; AI follow-up: PR #99, 2026-11-14; library lock, #26 with the storage decisions of #93: PR #101, 2026-11-16), so every green merge to `main` uploads to TestFlight.** Follow-ups: #90 (suggestion quality), #95, #85 (header text size), #104 (tests that failed only in CI), a glass Scan button.

- Requirements win over the design spec and this file (for example, iOS 27 minimum). `docs/superpowers/specs/2026-07-12-filing-cabinet-design.md` is superseded: history only.
- We work mock-driven: build what `design/` shows; raise anything it doesn't cover rather than guessing in code.
- Process is Superpowers: brainstorming → spec → plan → TDD → verification. No feature code without an approved plan.

## Hooks (committed in `.claude/settings.json`, scripts in `scripts/hooks/`)

- **Stop / SubagentStop gate** (`stop-gate.sh`): runs `make fast` only when the Swift content fingerprint differs from `.build/fc-fast-green` (any edit method; survives commits). Failing tests and compiler errors lead the block message. After 3 failed attempts it hands back with a message. Internal errors block loudly. If `jq` is missing it fails open with a message.
- **Format on edit** (`format-on-edit.sh`): formats edited Swift files.
- **Guards** (PreToolUse): `guard-generated.sh` blocks edits to the generated `.xcodeproj` and `Generated/`; `guard-hook-bypass.sh` blocks the git hook-bypass flags named in AGENTS.md's hard rules.
- A green Stop gate means the Fast (macOS) tests pass. It does not compile the Screens, App or UI test targets: run `make build` / `make affected` per the definition of done.
- Hook behaviour is covered by `make test-hooks`. Changing hook config needs Ben's OK.

## Verification

Use the `ios-verifier` agent for build/test evidence (see the definition of done in AGENTS.md).

Follow the run policy in AGENTS.md: `make retest ONLY=…` while fixing, `make affected` at the end of a task, `make full ALL=1` once before a PR. Ask `ios-verifier` for exactly those commands. CI runs `checks` on every push; the simulator suite runs on `main` and once a PR is ready for review (not on drafts, and not when a PR changes only `docs/` and Markdown).

## Workspace

- Personal agent tooling (XcodeBuildMCP, Axiom, SwiftUI skills) comes from arsenal's `ios` profile via `arms apply`: local scope, uncommitted.
- `.claude/settings.json` (project hooks) IS committed here, by approved exception. **Never commit** `.claude/skills/`, `skills-lock.json`, `.claude/settings.local.json` or `.herdr/`.
- Remote: github.com/bgibso4/filing-cabinet (public). CI runs on PRs and pushes to `main`.
