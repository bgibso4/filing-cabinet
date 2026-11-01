#!/usr/bin/env bash
# PostToolUse (Edit|Write|MultiEdit): remember that this session touched Swift, so the Stop gate runs.
set -euo pipefail
command -v jq >/dev/null || { echo "jq missing: brew install jq" >&2; exit 2; }
input="$(cat)"
file="$(jq -r '.tool_input.file_path // empty' <<<"$input")"
session="$(jq -r '.session_id // empty' <<<"$input" | tr -c 'A-Za-z0-9_-\n' '_')"
case "$file" in
*.swift) [ -n "$session" ] && touch "${TMPDIR:-/tmp}/fc-dirty-$session" ;;
esac
exit 0
