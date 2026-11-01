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

.PHONY: setup generate build fast lint format snapshots-record full compare run run-fake device

# Install the git hook and fail loudly, with the install command, when a required tool is missing.
setup:
	@missing=0; for tool in xcodegen swiftlint xcbeautify jq bats periphery; do \
		command -v $$tool >/dev/null || { echo "missing: brew install $$tool"; missing=1; }; \
	done; [ $$missing -eq 0 ] || exit 1
	@hooks="$$(git rev-parse --path-format=absolute --git-path hooks)"; mkdir -p "$$hooks" && rm -f "$$hooks/pre-commit" && \
		printf '#!/bin/sh\nexec "$$(git rev-parse --show-toplevel)/scripts/pre-commit" "$$@"\n' > "$$hooks/pre-commit" && chmod +x "$$hooks/pre-commit"
	@$(MAKE) --no-print-directory generate

generate:
	@command -v xcodegen >/dev/null || { echo "error: xcodegen is missing. Install it: brew install xcodegen" >&2; exit 1; }
	swift scripts/generate-tokens.swift
	xcodegen generate --quiet

build: generate
	set -o pipefail; xcodebuild build -project $(PROJECT) -scheme FilingCabinet \
		-destination '$(SIM_DEST)' -derivedDataPath $(DERIVED) | $(BEAUTIFY)

# The Mac-only loop: no simulator.
fast: generate
	set -o pipefail; xcodebuild test -project $(PROJECT) -scheme Fast \
		-destination 'platform=macOS' -derivedDataPath $(DERIVED) | $(BEAUTIFY)

SWIFT_DIRS := App Packages SnapshotTests

# swift-format owns formatting; SwiftLint owns everything else. Both are strict.
lint:
	swiftlint lint --strict --quiet
	swift format lint --strict --recursive $(SWIFT_DIRS)

format:
	swift format format --in-place --recursive $(SWIFT_DIRS)

# Record snapshot references on the pinned simulator. Review the diff before committing.
snapshots-record: generate
	set -o pipefail; TEST_RUNNER_SNAPSHOT_TESTING_RECORD=all xcodebuild test -project $(PROJECT) -scheme FilingCabinet \
		-destination '$(SIM_DEST)' -derivedDataPath $(DERIVED) -only-testing:FilingCabinetSnapshotTests | $(BEAUTIFY)

# Everything on the simulator: Core, ScreenModels, Screens and the snapshot tests.
full: generate
	set -o pipefail; xcodebuild test -project $(PROJECT) -scheme FilingCabinet \
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
	set -o pipefail; xcodebuild build -project $(PROJECT) -scheme FilingCabinet \
		-destination 'generic/platform=iOS' -derivedDataPath $(DERIVED) -allowProvisioningUpdates | $(BEAUTIFY)
	xcrun devicectl device install app --device "$(DEVICE)" '$(DEVICE_PRODUCT)'
	xcrun devicectl device process launch --device "$(DEVICE)" $(BUNDLE_ID)
