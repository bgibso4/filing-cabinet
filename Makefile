# The one pinned simulator. Snapshot tests render on this device too.
SIM_DEVICE ?= iPhone 17
SIM_OS     ?= 27.0

PROJECT     := FilingCabinet.xcodeproj
DERIVED     := $(CURDIR)/.build/DerivedData
SIM_DEST    := platform=iOS Simulator,name=$(SIM_DEVICE),OS=$(SIM_OS)
BEAUTIFY    := xcbeautify

BUNDLE_ID      := com.cadre.filingcabinet
APP_PRODUCT    := $(DERIVED)/Build/Products/Debug-iphonesimulator/FilingCabinet.app
DEVICE_PRODUCT := $(DERIVED)/Build/Products/Debug-iphoneos/FilingCabinet.app
# Name, UDID or serial of the target iPhone (see `xcrun devicectl list devices`).
DEVICE         ?= iPhone

.PHONY: setup generate build fast lint format snapshots-record full compare run run-fake device test-hooks test-lint unused ci full-run unused-run check-resolved

# Install the git hook and fail loudly, with the install command, when a required tool is missing.
setup:
	@missing=0; for tool in xcodegen swiftlint xcbeautify jq bats periphery; do \
		command -v $$tool >/dev/null || { echo "missing: brew install $$tool"; missing=1; }; \
	done; [ $$missing -eq 0 ] || exit 1
	@hooks="$$(git rev-parse --path-format=absolute --git-path hooks)"; mkdir -p "$$hooks" && rm -f "$$hooks/pre-commit" && \
		printf '#!/bin/sh\nexec "$$(git rev-parse --show-toplevel)/scripts/pre-commit" "$$@"\n' > "$$hooks/pre-commit" && chmod +x "$$hooks/pre-commit"
	@$(MAKE) --no-print-directory generate

# The generated project is gitignored, so the pins for the app's packages (swift-snapshot-testing and its
# dependencies) live in the tracked ./Package.resolved. XcodeGen cannot carry that file, so generate copies it to
# where Xcode reads it; builds then refuse to resolve to anything else (XCB_FLAGS).
RESOLVED_DEST := $(PROJECT)/project.xcworkspace/xcshareddata/swiftpm
# Flags for every xcodebuild call (and Periphery's build).
XCB_FLAGS     := -onlyUsePackageVersionsFromResolvedFile

generate:
	@command -v xcodegen >/dev/null || { echo "error: xcodegen is missing. Install it: brew install xcodegen" >&2; exit 1; }
	swift scripts/generate-tokens.swift
	xcodegen generate --quiet
	mkdir -p $(RESOLVED_DEST) && cp Package.resolved $(RESOLVED_DEST)/Package.resolved

build: generate
	set -o pipefail; xcodebuild $(XCB_FLAGS) build -project $(PROJECT) -scheme FilingCabinet \
		-destination '$(SIM_DEST)' -derivedDataPath $(DERIVED) | $(BEAUTIFY)

# The Mac-only loop: no simulator.
fast: generate
	fp="$$(scripts/hooks/swift-fingerprint.sh)"; set -o pipefail; xcodebuild $(XCB_FLAGS) test -project $(PROJECT) -scheme Fast \
		-destination 'platform=macOS' -derivedDataPath $(DERIVED) | $(BEAUTIFY) && \
		scripts/hooks/swift-fingerprint.sh record "$$fp"

SWIFT_DIRS := App Packages/FilingCabinetKit/Sources Packages/FilingCabinetKit/Tests SnapshotTests UITests

# swift-format owns formatting; SwiftLint owns everything else. Both are strict.
lint:
	swiftlint lint --strict --quiet
	swift format lint --strict --recursive $(SWIFT_DIRS)

format:
	swift format format --in-place --recursive $(SWIFT_DIRS)

# Record snapshot references on the pinned simulator. Review the diff before committing.
# A non-zero exit is expected: the library reports recording as a failure. Re-run `make full` to confirm green.
snapshots-record: generate
	set -o pipefail; TEST_RUNNER_SNAPSHOT_TESTING_RECORD=all xcodebuild $(XCB_FLAGS) test -project $(PROJECT) -scheme FilingCabinet \
		-destination '$(SIM_DEST)' -derivedDataPath $(DERIVED) -only-testing:FilingCabinetSnapshotTests | $(BEAUTIFY)

# Everything on the simulator: package tests, snapshot tests and UI tests.
full: generate full-run

full-run:
	set -o pipefail; xcodebuild $(XCB_FLAGS) test -project $(PROJECT) -scheme FilingCabinet \
		-destination '$(SIM_DEST)' -derivedDataPath $(DERIVED) | $(BEAUTIFY)

# Side by side: SCREEN=<design/screens stem> REF=<snapshot png> -> build/compare/<stem>.png
compare:
	@[ -n "$(SCREEN)" ] && [ -n "$(REF)" ] || { echo "usage: make compare SCREEN=<design png stem> REF=<snapshot png>" >&2; exit 1; }
	swift scripts/compare-snapshot.swift "$(SCREEN)" "$(REF)"

# Run on the pinned simulator.
run: build
	xcrun simctl boot '$(SIM_DEVICE)' 2>/dev/null || true
	xcrun simctl install booted '$(APP_PRODUCT)'
	xcrun simctl launch booted $(BUNDLE_ID)

# Same, with the UI-test launch flags (logged analytics, no animations).
run-fake: build
	xcrun simctl boot '$(SIM_DEVICE)' 2>/dev/null || true
	xcrun simctl install booted '$(APP_PRODUCT)'
	xcrun simctl launch booted $(BUNDLE_ID) -UITest

# Build for a connected iPhone and install it. Needs the phone plugged in, unlocked and trusted.
device: generate
	set -o pipefail; xcodebuild $(XCB_FLAGS) build -project $(PROJECT) -scheme FilingCabinet \
		-destination 'generic/platform=iOS' -derivedDataPath $(DERIVED) -allowProvisioningUpdates | $(BEAUTIFY)
	xcrun devicectl device install app --device "$(DEVICE)" '$(DEVICE_PRODUCT)'
	xcrun devicectl device process launch --device "$(DEVICE)" $(BUNDLE_ID)

# Unit tests for the Claude Code hook scripts.
test-hooks:
	bats scripts/hooks/tests

# Fixture tests for the SwiftLint custom rules.
test-lint:
	scripts/test-lint-rules.sh

# Dead-code scan (.periphery.yml, strict). Builds with its own derived data, on the pinned simulator.
unused: generate unused-run

unused-run:
	periphery scan -- -destination '$(SIM_DEST)' $(XCB_FLAGS)

# Snapshot references to compare against: origin/main when the remote exists, else the local main.
BASE_REF := $(shell git rev-parse --verify --quiet origin/main >/dev/null && echo origin/main || echo main)

# Everything CI runs, in order. CI invokes exactly this.
# The macOS slice step is build-for-testing: the Fast scheme's only build target is an empty aggregate, so a plain
# `build` has no macOS destination to build for. build-for-testing compiles Core, ScreenModels and their tests.
# Periphery 3.8.0 supports Xcode 27 / this project (verified locally); if a future Xcode breaks it, drop
# `unused` from this list, record it as deferred in AGENTS.md and keep the target.
ci: generate
	@test -z "$$(git status --porcelain -- Packages/FilingCabinetKit/Sources/Screens/DesignSystem/Generated Packages/FilingCabinetKit/Sources/Screens/Resources/Tokens.xcassets App/Assets.xcassets)" || { \
		echo "error: generated files differ from the committed ones: run make generate and commit." >&2; exit 1; }
	$(MAKE) --no-print-directory lint test-hooks test-lint
	set -o pipefail; xcodebuild $(XCB_FLAGS) build-for-testing -project $(PROJECT) -scheme Fast -destination 'platform=macOS' \
		-derivedDataPath $(DERIVED) | $(BEAUTIFY)
	$(MAKE) --no-print-directory full-run unused-run
	@echo "Snapshot references changed vs $(BASE_REF):"
	scripts/changed-snapshots.sh $(BASE_REF)
	$(MAKE) --no-print-directory check-resolved

# Fails when Xcode rewrote the resolved packages during the builds (run after them; never depends on generate).
check-resolved:
	@diff -q Package.resolved $(RESOLVED_DEST)/Package.resolved >/dev/null || { \
		echo "error: Xcode changed the resolved packages. Copy $(RESOLVED_DEST)/Package.resolved back to ./Package.resolved and commit it." >&2; exit 1; }
