#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# scripts/affected-tests.sh: changed paths → the simulator test classes to run.

REPO="$BATS_TEST_DIRNAME/../.."
AFFECTED="$REPO/scripts/affected-tests.sh"

setup() {
  export TMPDIR="$BATS_TEST_TMPDIR"
  FIX="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FIX/scripts" "$FIX/UITests" "$FIX/SnapshotTests"
  cp "$REPO/scripts/test-map.txt" "$FIX/scripts/"
  printf 'final class TrashJourneyTests: XCTestCase {}\n' >"$FIX/UITests/TrashJourneyTests.swift"
  printf 'final class CleanupJourneyTests: XCTestCase {}\n' >"$FIX/UITests/CleanupJourneyTests.swift"
  printf 'final class ScanJourneyTests: XCTestCase {}\n' >"$FIX/UITests/ScanJourneyTests.swift"
  printf 'extension ScanJourneyTests {}\n' >"$FIX/UITests/ScanJourneyTests+EditTrashRestore.swift"
  printf 'final class TrashSnapshotTests: XCTestCase {}\n' >"$FIX/SnapshotTests/TrashSnapshotTests.swift"
  printf 'struct ViewerBehaviourTests {}\n' >"$FIX/SnapshotTests/ViewerBehaviourTests.swift"
  git -C "$FIX" init -q -b main
  git -C "$FIX" config user.email t@example.com
  git -C "$FIX" config user.name t
  git -C "$FIX" add -A
  git -C "$FIX" commit -qm base
  git -C "$FIX" switch -qc work
  cd "$FIX"
}

TRASH="$(printf 'FilingCabinetSnapshotTests/TrashSnapshotTests\nFilingCabinetUITests/CleanupJourneyTests\nFilingCabinetUITests/TrashJourneyTests')"

# Commits a change to each path given (creating it if needed).
change() {
  for path in "$@"; do
    mkdir -p "$(dirname "$path")"
    printf 'changed %s\n' "$RANDOM" >>"$path"
  done
  git add -A && git commit -qm change
}

@test "a Trash screen change picks the Trash classes" {
  change Packages/FilingCabinetKit/Sources/Screens/Trash/TrashView.swift
  run --separate-stderr "$AFFECTED" main
  [ "$status" -eq 0 ]
  [ "$output" = "$TRASH" ]
}

@test "a test file change picks its own class" {
  change "UITests/ScanJourneyTests+EditTrashRestore.swift"
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "FilingCabinetUITests/ScanJourneyTests" ]
}

@test "a Swift Testing suite is found by its struct" {
  change SnapshotTests/ViewerBehaviourTests.swift
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "FilingCabinetSnapshotTests/ViewerBehaviourTests" ]
}

@test "a reference change picks its class" {
  change SnapshotTests/__Snapshots__/TrashSnapshotTests/trash_list.light.png
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "FilingCabinetSnapshotTests/TrashSnapshotTests" ]
}

@test "a shared change runs everything" {
  change Packages/FilingCabinetKit/Sources/Screens/DesignSystem/Tokens.swift
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "ALL" ]
}

@test "unmapped path runs everything" {
  change NewFolder/X.swift
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "ALL" ]
  [[ "$stderr" == *"no rule for NewFolder/X.swift"* ]]
}

@test "docs-only diff runs nothing" {
  change docs/x.md README.md
  run --separate-stderr "$AFFECTED" main
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "untracked and uncommitted files count" {
  mkdir -p Packages/FilingCabinetKit/Sources/Screens/Trash
  printf 'new\n' >Packages/FilingCabinetKit/Sources/Screens/Trash/New.swift
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "$TRASH" ]
}

@test "the reasoning goes to stderr" {
  change Packages/FilingCabinetKit/Sources/Screens/Trash/TrashView.swift
  run --separate-stderr "$AFFECTED" main
  [[ "$stderr" == *"Screens/Trash/TrashView.swift → TrashJourneyTests TrashSnapshotTests CleanupJourneyTests"* ]]
}

@test "the map names only classes that exist" {
  cd "$REPO"
  run "$AFFECTED" --check-map
  [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "the map check flags a test class missing from the map" {
  printf 'final class NewJourneyTests: XCTestCase {}\n' >UITests/NewJourneyTests.swift
  run "$AFFECTED" --check-map
  [ "$status" -eq 1 ]
  [[ "$output" == *"NewJourneyTests is not in the map"* ]]
}

@test "the map check flags a class that doesn't exist" {
  printf 'Packages/X/ GhostTests\n' >>scripts/test-map.txt
  run "$AFFECTED" --check-map
  [ "$status" -eq 1 ]
  [[ "$output" == *"the map names GhostTests"* ]]
}
