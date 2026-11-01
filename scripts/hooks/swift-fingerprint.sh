#!/usr/bin/env bash
# Content fingerprint of every non-ignored Swift source in this worktree.
#   swift-fingerprint.sh            print the current fingerprint
#   swift-fingerprint.sh current    exit 0 when it equals the recorded green fingerprint
#   swift-fingerprint.sh record FP  record FP as verified green (.build/fc-fast-green)
set -euo pipefail
root="$(git rev-parse --show-toplevel)"
cd "$root"
green=".build/fc-fast-green"

fingerprint() {
	# Hash each file (path + content), then hash the sorted list. Deleted-but-tracked files are skipped.
	git ls-files -co --exclude-standard -z -- '*.swift' | sort -z |
		while IFS= read -r -d '' file; do
			[ -f "$file" ] && printf '%s  %s\n' "$(shasum -a 256 <"$file" | cut -d' ' -f1)" "$file"
		done | shasum -a 256 | cut -d' ' -f1
}

case "${1:-print}" in
print) fingerprint ;;
current) [ "$(cat "$green" 2>/dev/null || true)" = "$(fingerprint)" ] ;;
record)
	mkdir -p .build
	printf '%s\n' "${2:?fingerprint required}" >"$green"
	;;
*) echo "usage: swift-fingerprint.sh [print|current|record FP]" >&2; exit 64 ;;
esac
