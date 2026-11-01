#!/usr/bin/env bash
# PostToolUse (Edit|Write|MultiEdit): format the edited Swift file in place.
set -euo pipefail
command -v jq >/dev/null || { echo "jq missing: brew install jq" >&2; exit 2; }
file="$(jq -r '.tool_input.file_path // empty')"
case "$file" in
*.swift) [ -f "$file" ] && swift format -i "$file" ;;
esac
exit 0
