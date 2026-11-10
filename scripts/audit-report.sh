#!/usr/bin/env bash
# What the accessibility audits found, read from a result bundle (`make audit-report`).
#   audit-report.sh [RESULT]   default: the newest .xcresult under .build/DerivedData/Logs/Test
# Prints each test with unexempted audit issues and the issues, which exemptions were used and how often, and the
# declared exemptions no audit used in this run. Reads the step titles UITests/Support/Audit.swift writes:
#   "Audit exemptions declared · a, b, …"   once per audit
#   "Audit issue · <type> · <element>"      an issue no exemption matched (the audit fails)
#   "Audit exemption used · <name> · …"     an issue an exemption matched
# FC_XCRESULTTOOL is a seam for the bats tests.
set -euo pipefail
xcresulttool="${FC_XCRESULTTOOL:-xcrun xcresulttool}"

result="${1:-}"
if [ -z "$result" ]; then
	root="$(git rev-parse --show-toplevel)"
	result="$(/bin/ls -td "$root"/.build/DerivedData/Logs/Test/*.xcresult 2>/dev/null | head -1 || true)"
	if [ -z "$result" ]; then
		echo "no test results under .build/DerivedData/Logs/Test: run make retest, affected or full first" >&2
		exit 1
	fi
fi

# Each test case and its result, as "id<TAB>result".
cases="$($xcresulttool get test-results tests --path "$result" |
	jq -r '.. | objects | select(.nodeType == "Test Case") | "\(.nodeIdentifier)\t\(.result)"')"

audits=0
tests_audited=0
declared=""
used=""
issues_out=""
while IFS=$'\t' read -r id outcome; do
	[ -n "$id" ] || continue
	titles="$($xcresulttool get test-results activities --path "$result" --test-id "$id" |
		jq -r '.. | objects | select(has("title")) | .title' | grep '^Audit ' || true)"
	[ -n "$titles" ] || continue
	count="$(grep -c '^Audit exemptions declared · ' <<<"$titles" || true)"
	[ "$count" -gt 0 ] || continue
	audits=$((audits + count))
	tests_audited=$((tests_audited + 1))
	declared="$(grep '^Audit exemptions declared · ' <<<"$titles" | head -1 | sed 's/^Audit exemptions declared · //')"
	used+="$(grep '^Audit exemption used · ' <<<"$titles" | awk -F' · ' '{ print $2 }' || true)"$'\n'
	issues="$(grep '^Audit issue · ' <<<"$titles" | sed 's/^Audit issue · /  /' || true)"
	[ -z "$issues" ] || issues_out+="$id · $outcome"$'\n'"$issues"$'\n\n'
done <<<"$cases"

if [ "$audits" -eq 0 ]; then
	echo "no audits in $result"
	exit 0
fi

echo "Audits in $result · $audits audits in $tests_audited tests"
echo
if [ -n "$issues_out" ]; then
	printf '%s' "$issues_out"
else
	echo "No audit issues outside the exemptions."
	echo
fi

used="$(grep -v '^$' <<<"$used" || true)"
if [ -n "$used" ]; then
	echo "Exemptions used: $(sort <<<"$used" | uniq -c | awk '{ printf "%s%s ×%s", sep, $2, $1; sep = ", " }')"
else
	echo "Exemptions used: none"
fi
unused="$(tr ',' '\n' <<<"$declared" | sed 's/^ *//' | grep -vxF -f <(printf '%s\n' "$used" | grep . || echo '') || true)"
if [ -n "$unused" ]; then
	echo "Not used in this run ($audits audits): $(paste -sd, - <<<"$unused" | sed 's/,/, /g')"
fi
