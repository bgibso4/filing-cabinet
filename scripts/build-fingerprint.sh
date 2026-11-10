#!/usr/bin/env bash
# Content fingerprint of everything that goes into the simulator build, so `make retest` can tell whether the last
# build still matches the sources. Leaves out what the build doesn't read: docs, Markdown, CI and agent config, design
# hand-off files (but not design/tokens.json) and snapshot references (the tests read those from disk at run time).
#   build-fingerprint.sh            print the current fingerprint
#   build-fingerprint.sh current    exit 0 when it equals the one recorded after the last good build
#   build-fingerprint.sh record FP  record FP (.build/fc-test-build)
set -euo pipefail
root="$(git rev-parse --show-toplevel)"
cd "$root"
recorded=".build/fc-test-build"

fingerprint() {
	git ls-files -co --exclude-standard -z | sort -z |
		while IFS= read -r -d '' file; do
			case "$file" in
			design/tokens.json) ;;
			docs/* | .github/* | .claude/* | design/* | SnapshotTests/__Snapshots__/* | *.md) continue ;;
			esac
			[ -f "$file" ] && printf '%s\0' "$file"
		done | xargs -0 shasum -a 256 | shasum -a 256 | cut -d' ' -f1
}

case "${1:-print}" in
print) fingerprint ;;
current) [ "$(cat "$recorded" 2>/dev/null || true)" = "$(fingerprint)" ] ;;
record)
	mkdir -p .build
	printf '%s\n' "${2:?fingerprint required}" >"$recorded"
	;;
*) echo "usage: build-fingerprint.sh [print|current|record FP]" >&2; exit 64 ;;
esac
