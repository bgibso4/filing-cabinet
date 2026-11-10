#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# scripts/audit-report.sh: audit issues and exemption use, read from a result bundle's activities.
# The fixtures are trimmed from a real run (BrowseJourneyTests' dark-mode audit failing, HomeJourneyTests passing);
# the exemption-used line in the Home fixture was added by hand in the title format Audit.swift writes.

REPO="$BATS_TEST_DIRNAME/../.."
REPORT="$REPO/scripts/audit-report.sh"
FIXTURES="$BATS_TEST_DIRNAME/fixtures/audit"

setup() {
  export TMPDIR="$BATS_TEST_TMPDIR"
  export FIXTURES
  # Stub xcresulttool: `get test-results tests` prints tests.json; `activities --test-id X` prints the fixture named
  # after X's letters, or no activities.
  STUB="$BATS_TEST_TMPDIR/xcresulttool"
  cat >"$STUB" <<'STUB'
#!/usr/bin/env bash
case " $* " in
*" tests "*) cat "$FIXTURES/tests.json" ;;
*" activities "*)
  while [ $# -gt 0 ]; do [ "$1" = --test-id ] && id="$2"; shift; done
  f="$FIXTURES/$(printf '%s' "$id" | tr -dc 'A-Za-z').json"
  if [ -f "$f" ]; then cat "$f"; else echo '{"testRuns":[{"activities":[]}]}'; fi ;;
esac
STUB
  chmod +x "$STUB"
  export FC_XCRESULTTOOL="$STUB"
}

@test "prints each unexempted issue under its test" {
  run "$REPORT" /r/Test.xcresult
  [ "$status" -eq 0 ]
  [[ "$output" == *"BrowseJourneyTests/testViewerAuditInDarkMode() · Failed"$'\n'"  contrast · no element"* ]]
  [[ "$output" != *"testHomeShowsCollectionsAndScan() ·"* ]]
}

@test "counts the audits that ran" {
  run "$REPORT" /r/Test.xcresult
  [[ "$output" == *"3 audits in 3 tests"* ]]
}

@test "counts exemption use" {
  run "$REPORT" /r/Test.xcresult
  [[ "$output" == *"Exemptions used: dark-viewer-header ×1"* ]]
}

@test "lists declared exemptions not used" {
  run "$REPORT" /r/Test.xcresult
  [[ "$output" == *"Not used in this run (3 audits): deep-text-under-scan, camera-off-sheet-clipped, trash-glass-buttons, trash-bar-unresolved, grid-select-unresolved"* ]]
}

@test "says so when the bundle has no audits" {
  export FIXTURES="$BATS_TEST_TMPDIR/empty"
  mkdir -p "$FIXTURES"
  echo '{"testNodes":[{"children":[{"nodeType":"Test Case","nodeIdentifier":"A/testB()","result":"Passed"}]}]}' >"$FIXTURES/tests.json"
  run "$REPORT" /r/Test.xcresult
  [ "$status" -eq 0 ]
  [[ "$output" == *"no audits in /r/Test.xcresult"* ]]
}

@test "fails clearly when there is no result bundle" {
  cd "$BATS_TEST_TMPDIR"
  git init -q
  run "$REPORT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no test results"* ]]
}

@test "lists every declared exemption when none was used" {
  ONLY_DARK="$BATS_TEST_TMPDIR/dark"
  mkdir -p "$ONLY_DARK"
  cp "$FIXTURES/BrowseJourneyTeststestViewerAuditInDarkMode.json" "$ONLY_DARK/"
  echo '{"testNodes":[{"children":[{"nodeType":"Test Case","nodeIdentifier":"BrowseJourneyTests/testViewerAuditInDarkMode()","result":"Failed"}]}]}' >"$ONLY_DARK/tests.json"
  export FIXTURES="$ONLY_DARK"
  run "$REPORT" /r/Test.xcresult
  [[ "$output" == *"Exemptions used: none"* ]]
  [[ "$output" == *"Not used in this run (1 audits): deep-text-under-scan, camera-off-sheet-clipped, dark-viewer-header, trash-glass-buttons, trash-bar-unresolved, grid-select-unresolved"* ]]
}
