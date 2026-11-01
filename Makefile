# The one pinned simulator. Snapshot tests render on this device too.
SIM_DEVICE ?= iPhone 17
SIM_OS     ?= 27.0

PROJECT     := FilingCabinet.xcodeproj
DERIVED     := $(CURDIR)/.build/DerivedData
SIM_DEST    := platform=iOS Simulator,name=$(SIM_DEVICE),OS=$(SIM_OS)
BEAUTIFY    := xcbeautify

.PHONY: setup generate build fast

# Fail loudly, with the install command, when a required tool is missing.
setup:
	@for tool in xcodegen xcbeautify; do \
		command -v $$tool >/dev/null || { echo "error: $$tool is missing. Install it: brew install $$tool" >&2; exit 1; }; \
	done
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
