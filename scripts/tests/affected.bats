#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# scripts/affected-tests.sh: changed paths → the simulator test classes to run.

REPO="$BATS_TEST_DIRNAME/../.."
AFFECTED="$REPO/scripts/affected-tests.sh"

setup() {
  export TMPDIR="$BATS_TEST_TMPDIR"
  FIX="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FIX/scripts" "$FIX/UITests" "$FIX/SnapshotTests" "$FIX/AuditTests" "$FIX/Packages/FilingCabinetKit/Tests/ScreensTests"
  printf 'struct TokensTests {}\n' >"$FIX/Packages/FilingCabinetKit/Tests/ScreensTests/TokensTests.swift"
  cp "$REPO/scripts/test-map.txt" "$FIX/scripts/"
  printf '# The smoke set.\n' >"$FIX/scripts/smoke-tests.txt"
  printf 'schemes:\n  FilingCabinet:\n    test:\n      targets:\n        - package: FilingCabinetKit/CoreTests\n        - package: FilingCabinetKit/ScreensTests\n        - name: FilingCabinetSnapshotTests\n        - name: FilingCabinetUITests\n  Fast:\n    test:\n      targets:\n        - package: FilingCabinetKit/LibraryTests\n' >"$FIX/project.yml"
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

# What a shared change runs, with the fixture's empty smoke list: the FilingCabinet scheme's package tests and the
# snapshot tests.
SHARED="$(printf 'CoreTests\nFilingCabinetSnapshotTests\nScreensTests')"
SMOKE_A="FilingCabinetUITests/ScanJourneyTests/testScanA"
SMOKE_B="FilingCabinetUITests/FavoritesJourneyTests/testFavoriteB"

# Lists the two smoke ids, with the tests they name.
smoke() {
  printf '# The smoke set.\n%s\n%s\n' "$SMOKE_A" "$SMOKE_B" >scripts/smoke-tests.txt
  printf 'final class ScanJourneyTests: XCTestCase { func testScanA() {} }\n' >UITests/ScanJourneyTests.swift
  printf 'final class FavoritesJourneyTests: XCTestCase { func testFavoriteB() {} }\n' >UITests/FavoritesJourneyTests.swift
  git add -A && git commit -qm smoke
  # Part of the base, so the branch's own changes are only what each test changes.
  git branch -qf main HEAD
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

@test "an audit test file change picks its audit class" {
  printf 'final class HomeAuditTests: XCTestCase {}\n' >AuditTests/HomeAuditTests.swift
  change AuditTests/HomeAuditTests.swift
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "FilingCabinetAuditTests/HomeAuditTests" ]
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

@test "a shared change runs snapshots and package tests" {
  change Packages/FilingCabinetKit/Sources/Screens/DesignSystem/Tokens.swift
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "$SHARED" ]
}

@test "an unmapped path runs the shared set" {
  change NewFolder/X.swift
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "$SHARED" ]
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

@test "a changed string no code names runs the shared set" {
  catalog "$(keys a a a b)" >"$STRINGS"
  git commit -qam copy
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "$SHARED" ]
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

@test "an identifier change outside a screen's enum runs the shared set" {
  sed -i '' 's/-> String { id }/-> String { id + ".pill" }/' "$IDS"
  git commit -qam ids
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "$SHARED" ]
}

@test "an identifier added between screen enums runs the shared set" {
  sed -i '' 's/^    }$/    }\
\
    public static func extra() -> String { "x" }/' "$IDS"
  git commit -qam ids
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "$SHARED" ]
}

@test "a catalog the script can't read runs the shared set" {
  printf '{ not json\n' >"$STRINGS"
  git commit -qam broken
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "$SHARED" ]
}

@test "a change to the scans the snapshot tests bundle runs the shared set" {
  change design/prototype/scans/scan-lease.jpg
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "$SHARED" ]
}

@test "a ScreensTests change runs ScreensTests" {
  change Packages/FilingCabinetKit/Tests/ScreensTests/TokensTests.swift
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "ScreensTests" ]
}

@test "a shared change adds the smoke set to snapshots and package tests" {
  smoke
  change Packages/FilingCabinetKit/Sources/Screens/DesignSystem/Tokens.swift
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "$(printf '%s\n%s\n%s\n%s\n%s' CoreTests FilingCabinetSnapshotTests "$SMOKE_B" "$SMOKE_A" ScreensTests)" ]
}

@test "a screen change adds the smoke set" {
  smoke
  change Packages/FilingCabinetKit/Sources/Screens/Trash/TrashView.swift
  run --separate-stderr "$AFFECTED" main
  # Trash's classes include FavoritesJourneyTests, so only SMOKE_A is added.
  [ "$output" = "$(printf '%s\n%s' "$TRASH" "$SMOKE_A" | sort)" ]
}

@test "a smoke id whose class is already picked is left out" {
  smoke
  change "UITests/ScanJourneyTests+EditTrashRestore.swift"
  run --separate-stderr "$AFFECTED" main
  [ "$output" = "$(printf '%s\n%s' "$SMOKE_B" FilingCabinetUITests/ScanJourneyTests)" ]
}

@test "a docs-only diff runs no smoke set" {
  smoke
  change docs/x.md
  run --separate-stderr "$AFFECTED" main
  [ -z "$output" ]
}

@test "a missing smoke list is an error" {
  rm scripts/smoke-tests.txt
  change Packages/FilingCabinetKit/Sources/Screens/Trash/TrashView.swift
  run --separate-stderr "$AFFECTED" main
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"scripts/smoke-tests.txt"* ]]
}

@test "the map check flags a smoke id whose test doesn't exist" {
  smoke
  printf 'FilingCabinetUITests/ScanJourneyTests/testGone\n' >>scripts/smoke-tests.txt
  run "$AFFECTED" --check-map
  [ "$status" -eq 1 ]
  [[ "$output" == *"FilingCabinetUITests/ScanJourneyTests/testGone"* ]]
}

@test "the map check flags a smoke id whose class doesn't exist" {
  smoke
  printf 'FilingCabinetUITests/GhostJourneyTests/testA\n' >>scripts/smoke-tests.txt
  run "$AFFECTED" --check-map
  [ "$status" -eq 1 ]
  [[ "$output" == *"FilingCabinetUITests/GhostJourneyTests/testA"* ]]
}

@test "--shared-set prints the shared set whatever changed" {
  smoke
  run -0 --separate-stderr "$AFFECTED" --shared-set
  [ "$output" = "$(printf '%s\n%s\n%s\n%s\n%s' CoreTests ScreensTests FilingCabinetSnapshotTests "$SMOKE_A" "$SMOKE_B")" ]
}
