#!/usr/bin/env bash
# Stop / SubagentStop: if this session edited Swift, `make fast` must pass before it can finish.
# FC_FAST_CMD overrides the command (tests). Serialized across sessions with a portable mkdir lock,
# because macOS has no flock.
set -euo pipefail
command -v jq >/dev/null || { echo "jq missing: brew install jq" >&2; exit 2; }

tmp="${TMPDIR:-/tmp}"
session="$(jq -r '.session_id // empty' | tr -c 'A-Za-z0-9_-\n' '_')"
dirty="$tmp/fc-dirty-$session"
counter="$tmp/fc-stop-$session"
lock="$tmp/fc-fast.lock.d"
max_attempts=3

[ -n "$session" ] && [ -f "$dirty" ] || exit 0

acquire_lock() {
	until mkdir "$lock" 2>/dev/null; do
		# Reclaim a lock whose owner died.
		owner="$(cat "$lock/pid" 2>/dev/null || true)"
		if [ -n "$owner" ] && ! kill -0 "$owner" 2>/dev/null; then
			rm -rf "$lock"
		fi
		sleep 0.1
	done
	echo $$ >"$lock/pid"
}
acquire_lock
trap 'rm -rf "$lock"' EXIT

cd "${CLAUDE_PROJECT_DIR:-$PWD}"
output="$(mktemp "$tmp/fc-fast-out.XXXXXX")"
trap 'rm -rf "$lock" "$output"' EXIT
if bash -c "${FC_FAST_CMD:-make fast}" >"$output" 2>&1; then
	rm -f "$dirty" "$counter"
	exit 0
fi

attempts=$(($(cat "$counter" 2>/dev/null || echo 0) + 1))
if [ "$attempts" -ge "$max_attempts" ]; then
	rm -f "$counter"
	jq -n '{systemMessage: "Fast tests are still failing after 3 attempts — handing back. Run `make fast` to see the failures."}'
	exit 0
fi
echo "$attempts" >"$counter"
tail -n 60 "$output" | jq -Rs '{decision: "block", reason: ("make fast failed (attempt '"$attempts"' of 3). Fix it before finishing. Last 60 lines:\n" + .)}'
