#!/usr/bin/env bash
# Files what a failed nightly job found as GitHub issues (label `nightly`), one per failing test.
#   nightly-issues.sh <job> <xcresult> <run-url> [--dry-run]
# Each failing test gets the open issue titled "Nightly: <Class>/<test> fails": a comment when it is already open, a new
# issue otherwise, so a test failing night after night is one issue with a comment per night. Titles match exactly. A
# job that failed with no failing test (no result bundle, a build error, a step after the tests) gets one issue titled
# "Nightly: <job> failed outside its tests". Nothing is ever closed here: Ben closes them.
# --dry-run prints what it would file and writes nothing.
# Calls GitHub through gh (GH_TOKEN, issues: write). FC_GH and FC_XCRESULTTOOL are seams for the tests.
set -euo pipefail
gh="${FC_GH:-gh}"
job="$1" bundle="$2" run_url="$3" dry="${4:-}"
artifact="The result bundle is the run's \`nightly-$job\` artifact."

# "<Class>/<test>\t<first failure message>" per failed test, or nothing.
failures() {
	[ -d "$bundle" ] || return 0
	local json
	if [ -n "${FC_XCRESULTTOOL:-}" ]; then
		json="$("$FC_XCRESULTTOOL" "$bundle")" || return 0
	else
		json="$(xcrun xcresulttool get test-results tests --path "$bundle")" || return 0
	fi
	jq -r '.. | objects | select(.nodeType? == "Test Case" and .result? == "Failed")
		| "\(.nodeIdentifier | sub("\\(\\)$"; ""))\t\([.. | objects | select(.nodeType? == "Failure Message") | .name][0] // "no message")"' \
		<<<"$json"
}

open_issues="$("$gh" issue list --label nightly --state open --limit 200 --json number,title)"

# Comments on the open issue with this exact title, or opens one.
file() { # <title> <body>
	local number
	number="$(jq -r --arg t "$1" '.[] | select(.title == $t) | .number' <<<"$open_issues" | head -1)"
	if [ -n "$dry" ]; then
		[ -n "$number" ] && echo "would comment on #$number: $1" || echo "would open: $1"
	elif [ -n "$number" ]; then
		"$gh" issue comment "$number" --body "$2" >/dev/null
		echo "commented on #$number: $1"
	else
		"$gh" issue create --title "$1" --label nightly --body "$2" >/dev/null
		echo "opened: $1"
	fi
}

found="$(failures)"
if [ -z "$found" ]; then
	file "Nightly: $job failed outside its tests" \
		"The nightly job \`$job\` failed, and no test in it failed: $run_url. Its log says why. $artifact"
	exit 0
fi
while IFS=$'\t' read -r test message; do
	file "Nightly: $test fails" "Failed in the nightly run: $run_url

\`\`\`
$message
\`\`\`

$artifact"
done <<<"$found"
