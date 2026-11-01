#!/usr/bin/env bash
# Stop / SubagentStop: `make fast` must have passed on the current Swift sources before anyone finishes.
# Decided by content fingerprint (swift-fingerprint.sh), not by which tool edited what.
# FC_FAST_CMD overrides the command (tests). Serialized across sessions with a portable mkdir lock,
# because macOS has no flock.
set -euo pipefail
# Fail open: a missing jq must not trap every session behind an unfinishable gate.
command -v jq >/dev/null || {
	printf '{"systemMessage":"jq missing: Fast gate skipped — brew install jq"}\n'
	exit 0
}

tmp="${TMPDIR:-/tmp}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fingerprint="${FC_FINGERPRINT_CMD:-$here/swift-fingerprint.sh}"
# Counter is keyed by agent_id when present (SubagentStop), else session_id.
session="$(jq -r '.agent_id // .session_id // empty' | tr -c 'A-Za-z0-9_-\n' '_')"
counter="$tmp/fc-stop-$session"
lock="$tmp/fc-fast.lock.d"
max_attempts=3

output=""
holding_lock=0
failed_command=""
# Fail loud: any unexpected internal error blocks with its cause. A bare exit 1 is a non-blocking
# error to Claude Code, which would let the session finish unverified.
on_error() { failed_command="$BASH_COMMAND"; }
on_exit() {
	local status=$?
	[ -z "$output" ] || rm -f "$output"
	[ "$holding_lock" -eq 0 ] || rm -rf "$lock"
	if [ "$status" -ne 0 ]; then
		jq -n --arg cmd "$failed_command" --arg status "$status" \
			'{decision: "block", reason: ("stop gate error: `" + $cmd + "` exited " + $status + ". Run `make fast` and check scripts/hooks/stop-gate.sh.")}'
		exit 0
	fi
}
trap on_error ERR
trap on_exit EXIT

cd "${CLAUDE_PROJECT_DIR:-$PWD}"
[ -n "$session" ] || exit 0
"$fingerprint" current && exit 0

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
	holding_lock=1
}
acquire_lock
output="$(mktemp "$tmp/fc-fast-out.XXXXXX")"

# Another gate may have verified these exact sources while we waited for the lock.
"$fingerprint" current && exit 0

# Record the pre-run value: content edited during the run is never marked green.
before="$("$fingerprint")"
if bash -c "${FC_FAST_CMD:-make fast}" >"$output" 2>&1; then
	"$fingerprint" record "$before"
	rm -f "$counter"
	exit 0
fi

attempts=$(($(cat "$counter" 2>/dev/null || echo 0) + 1))
if [ "$attempts" -ge "$max_attempts" ]; then
	rm -f "$counter"
	jq -n '{systemMessage: "Fast tests are still failing after 3 attempts — handing back. Run `make fast` to see the failures."}'
	exit 0
fi
echo "$attempts" >"$counter"

# Lead with what failed (ANSI stripped): the Failing tests block, ✖ lines and compiler errors; then a short tail.
clean="$(perl -pe 's/\e\[[0-9;]*[A-Za-z]//g' "$output")"
failures="$(awk '
	/Failing tests:/ { block = 1; next }
	block && /^[[:space:]]*$/ { block = 0 }
	block || /✖/ || /error:/ { print }
' <<<"$clean" | head -n 30)"
{
	[ -z "$failures" ] || printf '%s\n\n' "$failures"
	printf 'make fast failed (attempt %s of 3). Fix it before finishing. Last 20 lines:\n' "$attempts"
	tail -n 20 <<<"$clean"
} | jq -Rs '{decision: "block", reason: .}'
