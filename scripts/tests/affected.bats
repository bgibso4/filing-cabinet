#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# scripts/affected-tests.sh: changed paths → the simulator test classes to run.

REPO="$BATS_TEST_DIRNAME/../.."
AFFECTED="$REPO/scripts/affected-tests.sh"

setup() {
  export TMPDIR="$BATS_TEST_TMPDIR"
  FIX="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FIX/scripts" "$FIX/UITests" "$FIX/SnapshotTests" "$FIX/Packages/FilingCabinetKit/Tests/ScreensTests"
  printf 'struct TokensTests {}\n' >"$FIX/Packages/FilingCabinetKit/Tests/ScreensTests/TokensTests.swift"
  cp "$REPO/scripts/test-map.txt" "$FIX/scripts/"
  printf 'final class CleanupJourneyTests: XCTestCase {}\n' >"$FIX/UITests/CleanupJourneyTests.swift"
  printf 'final class FavoritesJourneyTests: XCTestCase {}\n' >"$FIX/UITests/FavoritesJourneyTests.swift"
  printf 'final class ScanJourneyTests: XCTestCase {}\n' >"$FIX/UITests/ScanJourneyTests.swift"
  printf 'extension ScanJourneyTests {}\n' >"$FIX/UITests/ScanJourneyTests+EditTrashRestore.swift"
  printf 'final class TrashSnapshotTests: XCTestCase {}\n' >"$FIX/SnapshotTests/TrashSnapshotTests.swift"
  printf 'struct ViewerBehaviourTests {}\n' >"$FIX/SnapshotTests/ViewerBehaviourTests.swift"
  # A string catalog, a screen that uses one of its strings, and the identifiers with one test that uses Trash's.
  STRINGS="Packages/FilingCabinetKit/Sources/ScreenModels/Localizable.xcstrings"
  IDS="Packages/FilingCabinetKit/Sources/Core/Accessibility/AccessibilityID.swift"
  mkdir -p "$FIX/$(dirname "$STRINGS")" "$FIX/$(dirname "$IDS")" "$FIX/Packages/FilingCabinetKit/Sources/Screens/Trash"
  catalog "$(keys a a a a)" >"$FIX/$STRINGS"
  printf 'Button(String(localized: "Empty Trash"))\nText("\\(count) scans · \\(name)")\n' \
    >"$FIX/Packages/FilingCabinetKit/Sources/Screens/Trash/TrashView.swift"
  printf 'public enum AccessibilityID {\n    public enum Home {\n        public static let scan = "home.scan"\n    }\n\n    public enum Trash {\n        public static let select = "trash.select"\n    }\n\n    public static func pill(_ id: String) -> String { id }\n}\n' \
    >"$FIX/$IDS"
  printf 'final class TrashJourneyTests: XCTestCase { let id = AccessibilityID.Trash.select }\n' \
    >"$FIX/UITests/TrashJourneyTests.swift"
  git -C "$FIX" init -q -b main
  git -C "$FIX" config user.email t@example.com
  git -C "$FIX" config user.name t
  git -C "$FIX" add -A
  git -C "$FIX" commit -qm base
  git -C "$FIX" switch -qc work
  cd "$FIX"
}

TRASH="$(printf 'FilingCabinetSnapshotTests/TrashSnapshotTests\nFilingCabinetUITests/CleanupJourneyTests\nFilingCabinetUITests/FavoritesJourneyTests\nFilingCabinetUITests/TrashJourneyTests\nScreensTests')"

# The fixture catalog's four keys, with these comments: Empty Trash, Gone, "%lld scans · %@" (in code as an
# interpolation) and "%@ default" (in no code).
keys() {
  printf '"Empty Trash" : { "comment" : "%s" }, "Gone" : { "comment" : "%s" }, ' "$1" "$2"
  printf '"%%lld scans · %%@" : { "comment" : "%s" }, "%%@ default" : { "comment" : "%s" }' "$3" "$4"
}
catalog() { printf '{ "sourceLanguage" : "en", "strings" : { %s }, "version" : "1.0" }\n' "$1"; }

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
  [[ "$stderr" == *"Screens/Trash/TrashView.swift → ScreensTests TrashJourneyTests TrashSnapshotTests CleanupJourneyTests"* ]]
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

@test "a copy change runs the classes of the screens that use it" {
  catalog "$(keys b a a a)" >"$STRINGS"
  git commit -qam copy
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "$TRASH" ]
}

@test "a changed format string finds the interpolation that uses it" {
  catalog "$(keys a a b a)" >"$STRINGS"
  git commit -qam copy
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "$TRASH" ]
}

@test "a changed string no code names runs everything" {
  catalog "$(keys a a a b)" >"$STRINGS"
  git commit -qam copy
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "ALL" ]
  [[ "$stderr" == *"%@ default"* ]]
}

@test "a removed string no code uses runs nothing" {
  printf '{ "sourceLanguage" : "en", "strings" : { %s }, "version" : "1.0" }\n' \
    '"Empty Trash" : { "comment" : "a" }, "%lld scans · %@" : { "comment" : "a" }, "%@ default" : { "comment" : "a" }' \
    >"$STRINGS"
  git commit -qam copy
  run --separate-stderr "$AFFECTED" main
  [ -z "$output" ]
}

@test "an identifier change runs the tests that use its screen's identifiers" {
  sed -i '' 's/"trash.select"/"trash.choose"/' "$IDS"
  git commit -qam ids
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "FilingCabinetUITests/TrashJourneyTests" ]
}

@test "an identifier change no test uses runs nothing" {
  sed -i '' 's/"home.scan"/"home.scanButton"/' "$IDS"
  git commit -qam ids
  run --separate-stderr "$AFFECTED" main
  [ -z "$output" ]
}

@test "an identifier change outside a screen's enum runs everything" {
  sed -i '' 's/-> String { id }/-> String { id + ".pill" }/' "$IDS"
  git commit -qam ids
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "ALL" ]
}

@test "an identifier added between screen enums runs everything" {
  sed -i '' 's/^    }$/    }\
\
    public static func extra() -> String { "x" }/' "$IDS"
  git commit -qam ids
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "ALL" ]
}

@test "a catalog the script can't read runs everything" {
  printf '{ not json\n' >"$STRINGS"
  git commit -qam broken
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "ALL" ]
}

@test "a change to the scans the snapshot tests bundle runs everything" {
  change design/prototype/scans/scan-lease.jpg
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "ALL" ]
}

@test "a ScreensTests change runs ScreensTests" {
  change Packages/FilingCabinetKit/Tests/ScreensTests/TokensTests.swift
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "ScreensTests" ]
}
