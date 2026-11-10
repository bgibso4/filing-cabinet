#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# scripts/sim-tests.sh: scope, the whole-suite refusal, build once, the retest check and the run log.

REPO="$BATS_TEST_DIRNAME/../.."

setup() {
  export TMPDIR="$BATS_TEST_TMPDIR"
  FIX="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FIX/scripts" "$FIX/SnapshotTests/__Snapshots__/TrashSnapshotTests" "$FIX/bin"
  cp "$REPO/scripts/sim-tests.sh" "$REPO/scripts/build-fingerprint.sh" "$FIX/scripts/"
  printf 'let a = 1\n' >"$FIX/A.swift"
  printf 'png\n' >"$FIX/SnapshotTests/__Snapshots__/TrashSnapshotTests/trash_list.light.png"
  printf '.build/\n' >"$FIX/.gitignore"
  git -C "$FIX" init -q -b main
  cd "$FIX"

  # Stub xcodebuild: logs each call; build-for-testing makes the app and exits STUB_BUILD_STATUS,
  # test-without-building exits STUB_TEST_STATUS.
  export CALLS="$BATS_TEST_TMPDIR/calls"
  cat >"$FIX/bin/xcodebuild" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$CALLS"
case " $* " in
*" build-for-testing "*)
  [ "${STUB_BUILD_STATUS:-0}" -eq 0 ] && mkdir -p "$DERIVED/Build/Products/Debug-iphonesimulator/FilingCabinet.app"
  exit "${STUB_BUILD_STATUS:-0}" ;;
*" test-without-building "*) exit "${STUB_TEST_STATUS:-0}" ;;
esac
STUB
  cat >"$FIX/bin/affected" <<'STUB'
#!/usr/bin/env bash
printf '%s' "${STUB_AFFECTED:-}"
STUB
  chmod +x "$FIX/bin/xcodebuild" "$FIX/bin/affected"
  export FC_XCODEBUILD="$FIX/bin/xcodebuild" FC_AFFECTED_CMD="$FIX/bin/affected" FC_BEAUTIFY=cat
  export DERIVED="$FIX/.build/DerivedData" PROJECT=P.xcodeproj SIM_DEST="platform=iOS Simulator,name=X" XCB_FLAGS=""
  unset ONLY SKIP ALL BASE
}

sim() { run --separate-stderr scripts/sim-tests.sh "$@"; }
called() { grep -q -- "$1" "$CALLS" 2>/dev/null; }

@test "full refuses with no ONLY" {
  sim full
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"make affected"* && "$stderr" == *"make retest"* && "$stderr" == *"ALL=1"* ]]
  [ ! -e "$CALLS" ]
}

@test "full refuses a whole target" {
  ONLY="FilingCabinetUITests" sim full
  [ "$status" -eq 2 ]
  [ ! -e "$CALLS" ]
}

@test "full ALL=1 runs everything" {
  ALL=1 sim full
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p "$CALLS" | grep -c build-for-testing)" -eq 1 ]
  [ "$(sed -n 2p "$CALLS" | grep -c test-without-building)" -eq 1 ]
  ! called -only-testing
}

@test "full runs named classes" {
  ONLY="FilingCabinetUITests/TrashJourneyTests" sim full
  [ "$status" -eq 0 ]
  called "-only-testing:FilingCabinetUITests/TrashJourneyTests"
}

@test "full passes SKIP through" {
  ONLY="FilingCabinetUITests/TrashJourneyTests" SKIP="FilingCabinetUITests/TrashJourneyTests/testX" sim full
  called "-skip-testing:FilingCabinetUITests/TrashJourneyTests/testX"
}

@test "affected runs what the map picks" {
  STUB_AFFECTED="$(printf 'FilingCabinetUITests/A\nFilingCabinetSnapshotTests/B')" sim affected
  [ "$status" -eq 0 ]
  called "-only-testing:FilingCabinetUITests/A"
  called "-only-testing:FilingCabinetSnapshotTests/B"
}

@test "affected ALL runs everything without refusing" {
  STUB_AFFECTED=ALL sim affected
  [ "$status" -eq 0 ]
  called test-without-building
  ! called -only-testing
}

@test "docs-only diff runs nothing" {
  STUB_AFFECTED="" sim affected
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to run"* ]]
  [ ! -e "$CALLS" ]
}

@test "retest refuses with no build" {
  ONLY="FilingCabinetUITests/A" sim retest
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"make affected"* ]]
  [ ! -e "$CALLS" ]
}

@test "retest after a build runs without building" {
  ONLY="FilingCabinetUITests/A" sim full
  rm "$CALLS"
  ONLY="FilingCabinetUITests/A/testB" sim retest
  [ "$status" -eq 0 ]
  ! called build-for-testing
  called "test-without-building"
  called "-only-testing:FilingCabinetUITests/A/testB"
}

@test "retest refuses after a Swift edit" {
  ONLY="FilingCabinetUITests/A" sim full
  rm "$CALLS"
  printf 'let a = 2\n' >A.swift
  ONLY="FilingCabinetUITests/A" sim retest
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"changed since the last build"* ]]
  [ ! -e "$CALLS" ]
}

@test "retest allows a reference-only change" {
  ONLY="FilingCabinetUITests/A" sim full
  rm "$CALLS"
  printf 'new png\n' >SnapshotTests/__Snapshots__/TrashSnapshotTests/trash_list.light.png
  ONLY="FilingCabinetSnapshotTests/TrashSnapshotTests" sim retest
  [ "$status" -eq 0 ]
  ! called build-for-testing
}

@test "retest with no ONLY runs the affected classes" {
  ONLY="FilingCabinetUITests/A" sim full
  rm "$CALLS"
  STUB_AFFECTED="FilingCabinetUITests/C" sim retest
  called "-only-testing:FilingCabinetUITests/C"
}

@test "fingerprint recorded when tests fail but build succeeds" {
  STUB_TEST_STATUS=1 ONLY="FilingCabinetUITests/A" sim full
  [ "$status" -eq 1 ]
  scripts/build-fingerprint.sh current
}

@test "no fingerprint when the build fails" {
  STUB_BUILD_STATUS=65 ONLY="FilingCabinetUITests/A" sim full
  [ "$status" -eq 65 ]
  ! scripts/build-fingerprint.sh current
  [ "$(grep -c test-without-building "$CALLS")" -eq 0 ]
}

@test "each run appends one log line" {
  ONLY="FilingCabinetUITests/A" sim full
  ONLY="FilingCabinetUITests/A" sim retest
  [ "$(wc -l <.build/test-runs.log)" -eq 2 ]
  [ "$(awk -F'\t' '{ print NF }' .build/test-runs.log | sort -u)" = 6 ]
  [ "$(sed -n 2p .build/test-runs.log | cut -f2)" = retest ]
  [ "$(sed -n 2p .build/test-runs.log | cut -f4)" = 0 ]
  [[ "$output" == *"test-runs: retest"* ]]
}

@test "retest allows a change to the test-run scripts" {
  ONLY="FilingCabinetUITests/A" sim full
  rm "$CALLS"
  printf '# edited\n' >>scripts/sim-tests.sh
  ONLY="FilingCabinetUITests/A" sim retest
  [ "$status" -eq 0 ]
}

@test "retest refuses after a token generator change" {
  mkdir -p scripts && printf 'gen\n' >scripts/generate-tokens.swift
  ONLY="FilingCabinetUITests/A" sim full
  rm "$CALLS"
  printf '// edited\n' >>scripts/generate-tokens.swift
  ONLY="FilingCabinetUITests/A" sim retest
  [ "$status" -eq 2 ]
}
