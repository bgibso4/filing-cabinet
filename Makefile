# The one pinned simulator. Snapshot tests render on this device too.
SIM_DEVICE ?= iPhone 17
SIM_OS     ?= 27.0

PROJECT     := FilingCabinet.xcodeproj
DERIVED     := $(CURDIR)/.build/DerivedData
SIM_DEST    := platform=iOS Simulator,name=$(SIM_DEVICE),OS=$(SIM_OS)
BEAUTIFY    := xcbeautify

.PHONY: setup generate build fast lint format

# Install the git hook and fail loudly, with the install command, when a required tool is missing.
setup:
	@missing=0; for tool in xcodegen swiftlint xcbeautify jq bats periphery; do \
		command -v $$tool >/dev/null || { echo "missing: brew install $$tool"; missing=1; }; \
	done; [ $$missing -eq 0 ] || exit 1
	@hooks="$$(git rev-parse --path-format=absolute --git-path hooks)"; mkdir -p "$$hooks" && ln -sf "$(CURDIR)/scripts/pre-commit" "$$hooks/pre-commit"
	@$(MAKE) --no-print-directory generate

generate:
	@command -v xcodegen >/dev/null || { echo "error: xcodegen is missing. Install it: brew install xcodegen" >&2; exit 1; }
	xcodegen generate --quiet

build: generate
	set -o pipefail; xcodebuild build -project $(PROJECT) -scheme FilingCabinet \
		-destination '$(SIM_DEST)' -derivedDataPath $(DERIVED) | $(BEAUTIFY)

# The Mac-only loop: no simulator. When ScreenModelsTests exists, add it to the Fast scheme
# in project.yml.
fast: generate
	set -o pipefail; xcodebuild test -project $(PROJECT) -scheme Fast \
		-destination 'platform=macOS' -derivedDataPath $(DERIVED) | $(BEAUTIFY)

SWIFT_DIRS := App Packages

# swift-format owns formatting; SwiftLint owns everything else. Both are strict.
lint:
	swiftlint lint --strict --quiet
	swift format lint --strict --recursive $(SWIFT_DIRS)

format:
	swift format format --in-place --recursive $(SWIFT_DIRS)
