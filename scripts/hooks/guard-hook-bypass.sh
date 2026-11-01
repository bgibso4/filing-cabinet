#!/usr/bin/env bash
# PreToolUse (Bash): the pre-commit and agent hooks are not optional.
set -euo pipefail
command -v jq >/dev/null || { echo "jq missing: brew install jq" >&2; exit 2; }
command="$(jq -r '.tool_input.command // empty')"
lower="$(tr '[:upper:]' '[:lower:]' <<<"$command")"
# `git ... commit ... -n` (also inside short-flag clusters such as -nm or -anm) is the same bypass.
short_n='(^|[^[:alnum:]_])git[[:space:]]+(.*[[:space:]])?commit[[:space:]]+(.*[[:space:]])?-[a-mo-zA-Z]*n[a-zA-Z]*([[:space:]]|$)'
if [[ "$lower" == *--no-verify* || "$lower" == *core.hookspath* || "$command" =~ $short_n ]]; then
	echo "Blocked: bypassing git hooks (--no-verify, commit -n, core.hooksPath) is not allowed. Fix what the hook reports instead." >&2
	exit 2
fi
exit 0
