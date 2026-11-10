#!/usr/bin/env bash
# Every local simulator test run goes through here (`make full`, `make affected`, `make retest`).
#   sim-tests.sh full      ONLY/SKIP as given; a whole-suite run needs ALL=1 (the run policy: once before a PR)
#   sim-tests.sh affected  the classes the branch's changes touch (scripts/affected-tests.sh, BASE=origin/main)
#   sim-tests.sh retest    ONLY, or the affected classes, without building; refuses if the sources changed since
#                          the last good build
# full and affected build once (build-for-testing), record the build fingerprint (even when tests then fail, so
# retest works next), then run test-without-building. Every run appends a line to .build/test-runs.log:
# time, mode, scope, build seconds, test seconds, exit status.
# Reads ONLY SKIP ALL BASE SIM_DEST XCB_FLAGS PROJECT DERIVED from the environment (the Makefile exports them).
# FC_XCODEBUILD, FC_AFFECTED_CMD and FC_BEAUTIFY are seams for the bats tests.
set -uo pipefail
root="$(git rev-parse --show-toplevel)"
cd "$root"
mode="${1:-}"
xcodebuild="${FC_XCODEBUILD:-xcodebuild}"
affected="${FC_AFFECTED_CMD:-scripts/affected-tests.sh}"
beautify="${FC_BEAUTIFY:-xcbeautify}"
fingerprint="scripts/build-fingerprint.sh"
app="$DERIVED/Build/Products/Debug-iphonesimulator/FilingCabinet.app"

policy() {
	cat >&2 <<'EOF'
Run policy (AGENTS.md):
  while fixing:             make retest ONLY=<Target/Class[/test]>   (no rebuild)
  at the end of a task:     make affected                            (the classes your changes touch)
  once before a PR:         make full ALL=1                          (or let CI's Full suite run)
EOF
}

# The test identifiers to run, one per line, or ALL, or nothing.
case "$mode" in
full)
	scope="${ONLY:-}"
	whole=""
	[ -n "$scope" ] || whole=1
	for id in $scope; do [[ "$id" == */* ]] || whole=1; done
	if [ -n "$whole" ] && [ "${ALL:-}" != 1 ]; then
		echo "error: make full without ONLY=<Target/Class> runs a whole suite. Pass ALL=1 if that's what you mean." >&2
		policy
		exit 2
	fi
	[ -n "$scope" ] || scope=ALL
	;;
affected | retest)
	scope="${ONLY:-}"
	if [ -z "$scope" ] || [ "$mode" = affected ]; then
		scope="$("$affected" "${BASE:-origin/main}")" || exit
	fi
	;;
*)
	echo "usage: sim-tests.sh full|affected|retest" >&2
	exit 64
	;;
esac
scope="$(echo $scope)" # one line, space-separated
if [ -z "$scope" ]; then
	echo "nothing to run: the changes touch no app code or tests."
	exit 0
fi

args=()
if [ "$scope" != ALL ]; then
	for id in $scope; do args+=("-only-testing:$id"); done
fi
for id in ${SKIP:-}; do args+=("-skip-testing:$id"); done
common=($XCB_FLAGS -project "$PROJECT" -scheme FilingCabinet -derivedDataPath "$DERIVED")

build_seconds=0
status=0
if [ "$mode" = retest ]; then
	if [ ! -d "$app" ] || ! "$fingerprint" current; then
		echo "error: the sources changed since the last build (or there is none), so retest would run stale code." >&2
		echo "Rebuild with make affected, or make full ONLY=<Target/Class>." >&2
		exit 2
	fi
else
	start=$SECONDS
	before="$("$fingerprint")"
	"$fingerprint" forget # products change from here on; only a good build records again
	"$xcodebuild" build-for-testing "${common[@]}" -destination "$SIM_DEST" | "$beautify"
	status=$?
	build_seconds=$((SECONDS - start))
	[ "$status" -eq 0 ] && "$fingerprint" record "$before"
fi

test_seconds=0
if [ "$status" -eq 0 ]; then
	start=$SECONDS
	"$xcodebuild" test-without-building "${common[@]}" -destination "$SIM_DEST" ${args[@]+"${args[@]}"} | "$beautify"
	status=$?
	test_seconds=$((SECONDS - start))
fi

mkdir -p .build
printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$mode" "$scope" "$build_seconds" "$test_seconds" \
	"$status" >>.build/test-runs.log
count="$(echo "$scope" | wc -w | tr -d ' ')"
[ "$scope" = ALL ] && what="everything" || what="$count test ids"
echo "test-runs: $mode · $what · build ${build_seconds} s · tests ${test_seconds} s · exit $status"
exit "$status"
