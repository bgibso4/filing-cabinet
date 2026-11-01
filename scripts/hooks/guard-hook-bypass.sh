#!/usr/bin/env bash
# PreToolUse (Bash): the pre-commit and agent hooks are not optional.
set -euo pipefail
command -v jq >/dev/null || { echo "jq missing: brew install jq" >&2; exit 2; }
command="$(jq -r '.tool_input.command // empty')"
# Inspect options only: drop the quoted argument of -m/--message so a commit message can mention a flag.
stripped="$(perl -0pe 's/(^|\s)(--message[= ]|-[A-Za-z]*m\s*)("(?:[^"\\]|\\.)*"|\x27[^\x27]*\x27)/$1$2/g' <<<"$command")"
lower="$(tr '[:upper:]' '[:lower:]' <<<"$stripped")"
# `git ... commit ... -n` (also inside short-flag clusters such as -nm or -anm) is the same bypass.
short_n='(^|[^[:alnum:]_])git[[:space:]]+(.*[[:space:]])?commit[[:space:]]+(.*[[:space:]])?-[a-mo-zA-Z]*n[a-zA-Z]*([[:space:]]|$)'
if [[ "$lower" == *--no-verify* || "$lower" == *core.hookspath* || "$stripped" =~ $short_n ]]; then
	echo "Blocked: bypassing git hooks (--no-verify, commit -n, core.hooksPath) is not allowed. Fix what the hook reports instead." >&2
	exit 2
fi
exit 0
