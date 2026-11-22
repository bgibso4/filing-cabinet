#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# scripts/ci/nightly-issues.sh: a failed nightly job's failing tests become GitHub issues, one per test.

REPO="$BATS_TEST_DIRNAME/../../.."
SCRIPT="$REPO/scripts/ci/nightly-issues.sh"
RUN=https://github.com/owner/repo/actions/runs/5

setup() {
  export TMPDIR="$BATS_TEST_TMPDIR"
  export STUB="$BATS_TEST_TMPDIR/stub"
  mkdir -p "$STUB/bundle.xcresult" "$STUB/bin"
  BUNDLE="$STUB/bundle.xcresult"
  echo '[]' >"$STUB/issues"
  cp "$BATS_TEST_DIRNAME/fixtures/two-failures.json" "$STUB/results"

  # Stub gh: `issue list` answers from $STUB/issues; every other call is recorded in $STUB/calls.
  cat >"$STUB/bin/gh" <<'GH'
#!/usr/bin/env bash
if [ "$1 $2" = "issue list" ]; then cat "$STUB/issues"; exit; fi
printf '%s\n' "$*" >>"$STUB/calls"
GH
  # Stub xcresulttool: prints $STUB/results.
  printf '#!/usr/bin/env bash\ncat "$STUB/results"\n' >"$STUB/bin/xcresulttool"
  chmod +x "$STUB/bin/gh" "$STUB/bin/xcresulttool"
  export FC_GH="$STUB/bin/gh" FC_XCRESULTTOOL="$STUB/bin/xcresulttool"
}

calls() { cat "$STUB/calls" 2>/dev/null; }

@test "a new failure opens an issue" {
  run -0 "$SCRIPT" journeys-1 "$BUNDLE" "$RUN"
  [[ "$(calls)" == *"issue create --title Nightly: FavoritesJourneyTests/testFoo fails --label nightly --body"*"$RUN"*"drag moved nothing"* ]]
}

@test "two failures make two issues" {
  run -0 "$SCRIPT" journeys-1 "$BUNDLE" "$RUN"
  [ "$(calls | grep -c '^issue create')" -eq 2 ]
  [[ "$(calls)" == *"--title Nightly: FavoritesJourneyTests/testFooBar fails "* ]]
}

@test "a failure with an open issue comments on it" {
  echo '[{"number": 41, "title": "Nightly: FavoritesJourneyTests/testFoo fails"}]' >"$STUB/issues"
  run -0 "$SCRIPT" journeys-1 "$BUNDLE" "$RUN"
  [[ "$(calls)" == *"issue comment 41 --body"*"drag moved nothing"* ]]
  [ "$(calls | grep -c '^issue create')" -eq 1 ]
}

@test "titles match exactly, not by prefix" {
  echo '[{"number": 41, "title": "Nightly: FavoritesJourneyTests/testFoo fails"}]' >"$STUB/issues"
  run -0 "$SCRIPT" journeys-1 "$BUNDLE" "$RUN"
  [[ "$(calls)" == *"issue create --title Nightly: FavoritesJourneyTests/testFooBar fails "* ]]
  [ "$(calls | grep -c '^issue comment 41')" -eq 1 ]
}

@test "no result bundle opens an issue for the job" {
  run -0 "$SCRIPT" audits "$STUB/missing.xcresult" "$RUN"
  [[ "$(calls)" == *"issue create --title Nightly: audits failed outside its tests --label nightly"*"$RUN"* ]]
}

@test "a bundle with no failed test opens an issue for the job" {
  echo '{"testNodes": []}' >"$STUB/results"
  run -0 "$SCRIPT" audits "$BUNDLE" "$RUN"
  [[ "$(calls)" == *"--title Nightly: audits failed outside its tests "* ]]
}

@test "dry run writes nothing" {
  echo '[{"number": 41, "title": "Nightly: FavoritesJourneyTests/testFoo fails"}]' >"$STUB/issues"
  run -0 "$SCRIPT" journeys-1 "$BUNDLE" "$RUN" --dry-run
  [ -z "$(calls)" ]
  [[ "$output" == *"would comment on #41: Nightly: FavoritesJourneyTests/testFoo fails"* ]]
  [[ "$output" == *"would open: Nightly: FavoritesJourneyTests/testFooBar fails"* ]]
}

@test "gh failing fails the step" {
  printf '#!/usr/bin/env bash\nexit 1\n' >"$STUB/bin/gh"
  run "$SCRIPT" journeys-1 "$BUNDLE" "$RUN"
  [ "$status" -ne 0 ]
}
