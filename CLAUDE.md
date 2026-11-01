@AGENTS.md

# Claude Code notes

Rules, commands and the definition of done are in AGENTS.md. This file holds what is specific to Claude Code.

## Where we are

**Phase: foundation built (branch `foundation`, local only).** Package, app, tokens, snapshot and UI tests, lint, hooks and the CI workflow are in place. Next: push to GitHub (pending Ben's go-ahead), then the Plan 1 rewrite in a fresh session. There is no feature code yet.

- Requirements win over the design spec and this file (for example, iOS 27 minimum). `docs/superpowers/specs/2026-07-12-filing-cabinet-design.md` is superseded: history only.
- We work mock-driven: build what `design/` shows; raise anything it doesn't cover rather than guessing in code.
- Process is Superpowers: brainstorming → spec → plan → TDD → verification. No feature code without an approved plan.

## Hooks (committed in `.claude/settings.json`, scripts in `scripts/hooks/`)

- **Stop / SubagentStop gate** (`stop-gate.sh`): runs `make fast` only when the Swift content fingerprint differs from `.build/fc-fast-green` (any edit method; survives commits). Failing tests and compiler errors lead the block message. After 3 failed attempts it hands back with a message. Internal errors block loudly. If `jq` is missing it fails open with a message.
- **Format on edit** (`format-on-edit.sh`): formats edited Swift files.
- **Guards** (PreToolUse): `guard-generated.sh` blocks edits to the generated `.xcodeproj` and `Generated/`; `guard-hook-bypass.sh` blocks commit/push hook-skip flags and `core.hooksPath` overrides.
- Hook behaviour is covered by `make test-hooks`. Changing hook config needs Ben's OK.

## Verification

Dispatch the `ios-verifier` agent for build/test evidence before claiming anything builds, passes or works. Every new piece of logic gets unit tests; every bug fix gets a regression test.

## Workspace

- Personal agent tooling (XcodeBuildMCP, Axiom, SwiftUI skills) comes from arsenal's `ios` profile via `arms apply`: local scope, uncommitted.
- `.claude/settings.json` (project hooks) IS committed here, by approved exception. **Never commit** `.claude/skills/`, `skills-lock.json`, `.claude/settings.local.json` or `.herdr/`.
- Git repo is local only (no remote yet).
