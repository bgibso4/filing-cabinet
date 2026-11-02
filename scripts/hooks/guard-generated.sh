#!/usr/bin/env bash
# PreToolUse (Edit|Write|MultiEdit): generated files are never edited by hand.
set -euo pipefail
command -v jq >/dev/null || { echo "jq missing: brew install jq" >&2; exit 2; }
file="$(jq -r '.tool_input.file_path // empty')"
case "$file" in
*.xcodeproj/* | */Generated/* | Generated/*)
	echo "Blocked: $file is generated. Change its source (project.yml, the tokens source) and run 'make generate'." >&2
	exit 2
	;;
esac
exit 0
