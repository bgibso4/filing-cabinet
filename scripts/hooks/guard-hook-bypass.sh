#!/usr/bin/env bash
# PreToolUse (Bash): the pre-commit and agent hooks are not optional.
set -euo pipefail
command -v jq >/dev/null || { echo "jq missing: brew install jq" >&2; exit 2; }
command="$(jq -r '.tool_input.command // empty')"
case "$command" in
*--no-verify* | *core.hooksPath*)
	echo "Blocked: bypassing git hooks (--no-verify / core.hooksPath) is not allowed. Fix what the hook reports instead." >&2
	exit 2
	;;
esac
exit 0
