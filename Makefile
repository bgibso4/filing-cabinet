# The pinned simulator: an iPhone 17 on iOS 27.0, named for this project so other projects' runs never share it.
# Snapshot tests render on it too (any iPhone 17 on iOS 27.0 renders the same). CI uses the image's `iPhone 17`.
SIM_DEVICE ?= FC iPhone 17
SIM_MODEL  := iPhone 17
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

.PHONY: setup sim generate build fast lint format snapshots-record full compare run run-fake device test-hooks test-lint unused ci ci-checks ci-sim full-run unused-run check-resolved compare-readers device-perf

# Install the git hook and fail loudly, with the install command, when a required tool is missing.
setup:
	@missing=0; for tool in xcodegen swiftlint xcbeautify jq bats periphery; do \
		command -v $$tool >/dev/null || { echo "missing: brew install $$tool"; missing=1; }; \
	done; [ $$missing -eq 0 ] || exit 1
	@hooks="$$(git rev-parse --path-format=absolute --git-path hooks)"; mkdir -p "$$hooks" && rm -f "$$hooks/pre-commit" && \
		printf '#!/bin/sh\nexec "$$(git rev-parse --show-toplevel)/scripts/pre-commit" "$$@"\n' > "$$hooks/pre-commit" && chmod +x "$$hooks/pre-commit"
	@$(MAKE) --no-print-directory sim generate

# Create the pinned simulator when it is missing.
sim:
	@xcrun simctl list devices 'iOS $(SIM_OS)' | grep -qF '    $(SIM_DEVICE) (' || \
		xcrun simctl create '$(SIM_DEVICE)' '$(SIM_MODEL)' com.apple.CoreSimulator.SimRuntime.iOS-$(subst .,-,$(SIM_OS))

# Narrow a simulator test run: ONLY and SKIP take test identifiers (Target, Target/Class or Target/Class/test).
#   make full ONLY="FilingCabinetUITests/ScanJourneyTests FilingCabinetSnapshotTests/ReviewSnapshotTests"
TEST_ARGS = $(strip $(addprefix -only-testing:,$(ONLY)) $(addprefix -skip-testing:,$(SKIP)))

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

build: sim generate
	set -o pipefail; xcodebuild $(XCB_FLAGS) build -project $(PROJECT) -scheme FilingCabinet \
		-destination '$(SIM_DEST)' -derivedDataPath $(DERIVED) | $(BEAUTIFY)

# The Mac-only loop: no simulator.
fast: generate
	fp="$$(scripts/hooks/swift-fingerprint.sh)"; set -o pipefail; xcodebuild $(XCB_FLAGS) test -project $(PROJECT) -scheme Fast \
		-destination 'platform=macOS' -derivedDataPath $(DERIVED) | $(BEAUTIFY) && \
		scripts/hooks/swift-fingerprint.sh record "$$fp"

SWIFT_DIRS := App Packages/FilingCabinetKit/Sources Packages/FilingCabinetKit/Tests SnapshotTests UITests DeviceTests

# swift-format owns formatting; SwiftLint owns everything else. Both are strict.
lint:
	swiftlint lint --strict --quiet
	swift format lint --strict --recursive $(SWIFT_DIRS)

format:
	swift format format --in-place --recursive $(SWIFT_DIRS)

# Record snapshot references on the pinned simulator. Review the diff before committing.
# A non-zero exit is expected: the library reports recording as a failure. Re-run `make full` to confirm green.
# ONLY narrows it to some snapshot classes.
snapshots-record: sim generate
	set -o pipefail; TEST_RUNNER_SNAPSHOT_TESTING_RECORD=all xcodebuild $(XCB_FLAGS) test -project $(PROJECT) -scheme FilingCabinet \
		-destination '$(SIM_DEST)' -derivedDataPath $(DERIVED) $(or $(TEST_ARGS),-only-testing:FilingCabinetSnapshotTests) \
		| $(BEAUTIFY)

# Everything on the simulator: package tests, snapshot tests and UI tests. ONLY and SKIP narrow it (TEST_ARGS).
full: generate full-run

full-run: sim
	set -o pipefail; xcodebuild $(XCB_FLAGS) test -project $(PROJECT) -scheme FilingCabinet \
		-destination '$(SIM_DEST)' -derivedDataPath $(DERIVED) $(TEST_ARGS) | $(BEAUTIFY)

# Side by side: SCREEN=<design/screens stem> REF=<snapshot png> -> build/compare/<stem>.png
compare:
	@[ -n "$(SCREEN)" ] && [ -n "$(REF)" ] || { echo "usage: make compare SCREEN=<design png stem> REF=<snapshot png>" >&2; exit 1; }
	swift scripts/compare-snapshot.swift "$(SCREEN)" "$(REF)"

# `READER=text|documents` picks the Vision reader for run, run-fake and device (Debug builds only; A12, A15).
READER_ARGS := $(if $(READER),-TextReader $(READER))

# Run on the pinned simulator.
run: build
	xcrun simctl boot '$(SIM_DEVICE)' 2>/dev/null || true
	xcrun simctl install booted '$(APP_PRODUCT)'
	xcrun simctl launch booted $(BUNDLE_ID) $(READER_ARGS)

# Same, with the UI-test launch flags: in-memory library, no animations, the fake camera, 12 seeded scans.
run-fake: build
	xcrun simctl boot '$(SIM_DEVICE)' 2>/dev/null || true
	xcrun simctl install booted '$(APP_PRODUCT)'
	xcrun simctl launch booted $(BUNDLE_ID) -UITest -FakeCamera 1 -SeedScans 12 $(READER_ARGS)

# Build for a connected iPhone and install it. Needs the phone plugged in, unlocked and trusted.
device: generate
	set -o pipefail; xcodebuild $(XCB_FLAGS) build -project $(PROJECT) -scheme FilingCabinet \
		-destination 'generic/platform=iOS' -derivedDataPath $(DERIVED) -allowProvisioningUpdates | $(BEAUTIFY)
	xcrun devicectl device install app --device "$(DEVICE)" '$(DEVICE_PRODUCT)'
	xcrun devicectl device process launch --device "$(DEVICE)" $(BUNDLE_ID) $(READER_ARGS)

# The reader bake-off (A12) on this Mac: both readers on every synthetic scan. A report, not a gate.
compare-readers: generate
	set -o pipefail; xcodebuild $(XCB_FLAGS) test -project $(PROJECT) -scheme ReaderComparison \
		-destination 'platform=macOS' -derivedDataPath $(DERIVED) | $(BEAUTIFY)
	@echo "Report: build/reader-comparison.md"

# Reader timing on a connected iPhone (A12, A14). Not part of `full` or CI. XCTest runs every class of one
# invocation in one process, so each cold-read class gets its own `xcodebuild test` (a fresh app launch) and the
# warm per-page timing runs last. Attachments land in build/device-perf/<class>/.
PERF_DIR     := build/device-perf
PERF_CLASSES := TextReaderColdTests DocumentsReaderColdTests ReaderTimingTests

device-perf: generate
	rm -rf $(PERF_DIR)
	@for class in $(PERF_CLASSES); do \
		set -o pipefail; xcodebuild $(XCB_FLAGS) test -project $(PROJECT) -scheme Device \
			-destination 'platform=iOS,name=$(DEVICE)' -derivedDataPath $(DERIVED) -allowProvisioningUpdates \
			-only-testing:FilingCabinetDeviceTests/$$class -resultBundlePath $(PERF_DIR)/$$class.xcresult \
			| $(BEAUTIFY) || exit 1; \
		xcrun xcresulttool export attachments --path $(PERF_DIR)/$$class.xcresult \
			--output-path $(PERF_DIR)/$$class >/dev/null || exit 1; \
	done
	@echo "Timings:"; for file in $(PERF_DIR)/*/*.txt; do cat "$$file"; echo; done

# Unit tests for the Claude Code hook scripts.
test-hooks:
	bats scripts/hooks/tests

# Fixture tests for the SwiftLint custom rules.
test-lint:
	scripts/test-lint-rules.sh

# Dead-code scan (.periphery.yml, strict). Builds with its own derived data, on the pinned simulator.
unused: generate unused-run

unused-run: sim
	periphery scan -- -destination '$(SIM_DEST)' $(XCB_FLAGS)

# Snapshot references to compare against: origin/main when the remote exists, else the local main.
BASE_REF := $(shell git rev-parse --verify --quiet origin/main >/dev/null && echo origin/main || echo main)

# Everything CI runs. CI runs the same parts as parallel jobs: `ci-checks`, and `ci-sim` once per shard.
ci: ci-checks ci-sim

# Everything except the simulator tests.
# The macOS slice step is build-for-testing: the Fast scheme's only build target is an empty aggregate, so a plain
# `build` has no macOS destination to build for. build-for-testing compiles Core, ScreenModels and their tests.
# Periphery 3.8.0 supports Xcode 27 / this project (verified locally); if a future Xcode breaks it, drop
# `unused-run` from this list, record it as deferred in AGENTS.md and keep the target.
ci-checks: generate
	@test -z "$$(git status --porcelain -- Packages/FilingCabinetKit/Sources/Screens/DesignSystem/Generated Packages/FilingCabinetKit/Sources/Screens/Resources/Tokens.xcassets App/Assets.xcassets)" || { \
		echo "error: generated files differ from the committed ones: run make generate and commit." >&2; exit 1; }
	$(MAKE) --no-print-directory lint test-hooks test-lint
	set -o pipefail; xcodebuild $(XCB_FLAGS) build-for-testing -project $(PROJECT) -scheme Fast -destination 'platform=macOS' \
		-derivedDataPath $(DERIVED) | $(BEAUTIFY)
	$(MAKE) --no-print-directory unused-run
	@echo "Snapshot references changed vs $(BASE_REF):"
	scripts/changed-snapshots.sh $(BASE_REF)
	$(MAKE) --no-print-directory check-resolved

# The simulator suite: whole (SHARD=all, the default) or one CI shard. The scan and browse shards take the two
# longest UI classes, and browse also takes the snapshot tests (it had the shortest tests: about 210 s, against about
# 750 s in main, CI run 42508098398). main skips them rather than listing the rest, so a new test class lands in main.
# CaptureLayerContainmentTests is an extension of ScanJourneyTests, so it runs in the scan shard.
# The scan shard first flaked (4 of 10 CI runs): each read of the screen took 1 to 4 s there, and waits of 2 to 5 s
# ran out. One launch per class (Launch.swift) and one read per check in the tight waits address that (#43).
SHARD             ?= all
SHARD_SCAN        := FilingCabinetUITests/ScanJourneyTests
SHARD_BROWSE      := FilingCabinetUITests/BrowseJourneyTests FilingCabinetSnapshotTests
SHARD_ONLY_scan   := $(SHARD_SCAN)
SHARD_ONLY_browse := $(SHARD_BROWSE)
SHARD_SKIP_main   := $(SHARD_SCAN) $(SHARD_BROWSE)

# Xcode's compilation cache: keyed on each compilation's inputs (not file dates), so CI restores it from earlier runs
# and skips compiling what a change did not touch. ci.yml caches this folder.
CAS_PATH      := $(CURDIR)/.build/CompilationCache
# Timing evidence: xcodebuild's raw output, each line stamped with the time it appeared, appended to .build/xcodebuild.log
# (xcbeautify buffers, so the job log can't say where the time goes). ci.yml uploads it with the build log and results.
STAMP         := perl -MPOSIX -e 'open(my $$log, ">>", ".build/xcodebuild.log") or die; $$log->autoflush(1); while (<STDIN>) { print $$log strftime("%H:%M:%S ", gmtime), $$_; print }'
CI_SIM_FLAGS   = $(XCB_FLAGS) -project $(PROJECT) -scheme FilingCabinet -destination '$(SIM_DEST)' \
	-derivedDataPath $(DERIVED) COMPILATION_CACHE_ENABLE_CACHING=YES COMPILATION_CACHE_CAS_PATH=$(CAS_PATH) $(TEST_ARGS)

ci-sim: ONLY = $(SHARD_ONLY_$(SHARD))
ci-sim: SKIP = $(SHARD_SKIP_$(SHARD))
ci-sim: generate
	@case '$(SHARD)' in all|main|scan|browse) ;; *) echo "error: SHARD must be all, main, scan or browse" >&2; exit 1;; esac
	# The simulator boots while the tests build, and the tests wait until it has finished booting. Left to xcodebuild
	# on a slow CI runner, the UI test runner once started before accessibility had loaded and failed before any
	# test ran (#43). By ID: the CI image has an iPhone 17 for more than one iOS version.
	udid="$$(xcrun simctl list devices 'iOS $(SIM_OS)' | grep -F '    $(SIM_DEVICE) (' | head -1 | grep -oE '[0-9A-F-]{36}')"; \
		[ -n "$$udid" ] || { echo "error: no $(SIM_DEVICE) on iOS $(SIM_OS)" >&2; exit 1; }; \
		mkdir -p .build; xcrun simctl bootstatus "$$udid" -b > .build/boot.log 2>&1 & boot=$$!; \
		set -o pipefail; xcodebuild build-for-testing -showBuildTimingSummary $(CI_SIM_FLAGS) | $(STAMP) | $(BEAUTIFY) || { kill $$boot; exit 1; }; \
		wait $$boot || { tail -20 .build/boot.log >&2; echo "error: the simulator did not boot" >&2; exit 1; }; \
		xcodebuild test-without-building $(CI_SIM_FLAGS) | $(STAMP) | $(BEAUTIFY)
	$(MAKE) --no-print-directory check-resolved

# Fails when Xcode rewrote the resolved packages during the builds (run after them; never depends on generate).
check-resolved:
	@diff -q Package.resolved $(RESOLVED_DEST)/Package.resolved >/dev/null || { \
		echo "error: Xcode changed the resolved packages. Copy $(RESOLVED_DEST)/Package.resolved back to ./Package.resolved and commit it." >&2; exit 1; }
