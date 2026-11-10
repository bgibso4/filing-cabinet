#!/usr/bin/env bash
# The simulator test classes a branch's changes can affect (`make affected`, `make retest`).
#   affected-tests.sh [BASE]      print the test identifiers to run, one per line (Target/Class), or ALL, or nothing
#   affected-tests.sh --check-map exit 1 when scripts/test-map.txt names a class that doesn't exist, or a test class
#                                 is missing from it
# Changed paths: everything since the merge base with BASE (default origin/main), committed or not, plus untracked
# files. Rules are in scripts/test-map.txt. The reasoning goes to stderr.
set -euo pipefail
export LC_ALL=C
root="$(git rev-parse --show-toplevel)"
cd "$root"
map="scripts/test-map.txt"
test_dirs=(UITests SnapshotTests)

# The map's rules as "prefix<TAB>targets", comments and blank lines dropped.
rules() { awk '!/^[[:space:]]*(#|$)/ { p = $1; $1 = ""; sub(/^ /, ""); print p "\t" $0 }' "$map"; }

# The *Tests types a test source file declares or extends (Swift Testing suites are structs).
types_in_file() {
	[ -f "$1" ] || return 0
	sed -nE 's/^([[:space:]]*@[A-Za-z]+[[:space:]]+)*(final[[:space:]]+)?(class|struct|extension)[[:space:]]+([A-Za-z0-9_]+Tests)([^A-Za-z0-9_].*)?$/\4/p' "$1"
}

# The test target that declares a class, or nothing.
target_of() {
	local dir
	for dir in "${test_dirs[@]}"; do
		if grep -lqE "^([[:space:]]*@[A-Za-z]+[[:space:]]+)*(final[[:space:]]+)?(class|struct)[[:space:]]+$1([^A-Za-z0-9_]|$)" "$dir"/*.swift 2>/dev/null; then
			echo "FilingCabinet$dir"
			return
		fi
	done
}

# Map rules matching one path: prints their targets (classes, ALL or NONE), one per line; nothing when no rule matches.
map_targets() {
	local prefix targets
	while IFS=$'\t' read -r prefix targets; do
		[ "$prefix" = SELF ] && continue
		case "$1" in
		"$prefix"*) ;;
		*) [ "$prefix" = "*.md" ] && [[ "$1" == *.md ]] || continue ;;
		esac
		printf '%s\n' $targets
	done < <(rules)
}

ids_file="Packages/FilingCabinetKit/Sources/Core/Accessibility/AccessibilityID.swift"

# An extended regular expression matching a format key's text in code: each placeholder (%@, %lld, %1$@, %.1f, …)
# as an interpolation, \( … \).
interpolation_pattern() {
	printf '%s' "$1" | sed -E 's/[][\.*^$+?(){}|/]/\\&/g' |
		sed -E 's/%([0-9]+\\\$)?(@|lld|ld|lu|d|f|\\\.[0-9]f)/\\\\\\([^"]*\\)/g'
}

# A string catalog: the changed keys, each through the Swift files that name it. A changed key no code names (a
# format string, built at run time) runs everything; a removed one no code names runs nothing.
string_targets() {
	local path="$1" old changed key present files found=""
	old="$(git show "$merge_base:$path" 2>/dev/null)" && [ -f "$path" ] || { echo ALL; return; }
	changed="$(jq -rn --argjson a "$old" --slurpfile b "$path" '
		($a.strings) as $o | ($b[0].strings) as $n
		| (($o | keys) + ($n | keys) | unique)[] as $k | select($o[$k] != $n[$k]) | "\($k)\t\($n | has($k))"')"
	while IFS=$'\t' read -r key present; do
		[ -n "$key" ] || continue
		files="$(grep -rlF --include='*.swift' -- "\"$key\"" Packages/FilingCabinetKit/Sources App 2>/dev/null || true)"
		# A format key ("%lld scans") is written in code as an interpolation ("\(count) scans").
		if [ -z "$files" ] && [[ "$key" == *%* ]]; then
			files="$(grep -rlE --include='*.swift' -- "\"$(interpolation_pattern "$key")\"" Packages/FilingCabinetKit/Sources App \
				2>/dev/null || true)"
		fi
		if [ -z "$files" ]; then
			[ "$present" = true ] || continue
			echo "no code names the changed string \"$key\": running everything" >&2
			echo ALL
			return
		fi
		for file in $files; do found+="$(targets_for "$file")"$'\n'; done
	done <<<"$changed"
	[ -n "$(echo "$found" | grep .)" ] && echo "$found" | grep . || echo NONE
}

# The screen enums (AccessibilityID.<Screen>) that changed lines of one side of a diff fall in; TOP for a line outside
# them. Reads line numbers on stdin.
namespaces_at() {
	awk 'NR == FNR { want[$1] = 1; next }
		/^    (public )?enum [A-Za-z0-9_]+/ { split($0, w, " "); ns = (w[1] == "public" ? w[3] : w[2]) }
		(FNR in want) && $0 !~ /^[[:space:]]*$/ { print (ns == "" ? "TOP" : ns) }
		/^    }/ { ns = "" }' - "$1"
}

# The identifiers: the test classes that use a changed screen enum's identifiers. A change outside the screen enums,
# or to identifiers UI test support uses, runs everything.
identifier_targets() {
	local path="$1" old ranges namespaces ns files found=""
	old="$(mktemp)"
	git show "$merge_base:$path" >"$old" 2>/dev/null && [ -f "$path" ] || { echo ALL; return; }
	# Hunk headers "@@ -a,b +c,d @@": old lines a..a+b-1 and new lines c..c+d-1 changed.
	ranges="$(git diff -U0 "$merge_base" -- "$path" | sed -nE 's/^@@ -([0-9]+)(,([0-9]+))? \+([0-9]+)(,([0-9]+))? @@.*/\1 \3 \4 \6/p')"
	namespaces="$({
		awk -F, '{ n = ($2 == "" ? 1 : $2); for (i = 0; i < n; i++) print $1 + i }' <<<"$ranges" | namespaces_at "$old"
		awk -F, '{ n = ($4 == "" ? 1 : $4); for (i = 0; i < n; i++) print $3 + i }' <<<"$ranges" | namespaces_at "$path"
	} | sort -u)"
	rm -f "$old"
	if grep -qx TOP <<<"$namespaces"; then
		echo ALL
		return
	fi
	for ns in $namespaces; do
		pattern="AccessibilityID\.$ns([^A-Za-z0-9_]|$)"
		if grep -lqE "$pattern" UITests/Support/*.swift 2>/dev/null; then
			echo ALL
			return
		fi
		files="$(grep -lE "$pattern" UITests/*.swift SnapshotTests/*.swift 2>/dev/null || true)"
		for file in $files; do found+="$(types_in_file "$file")"$'\n'; done
	done
	[ -n "$(echo "$found" | grep .)" ] && echo "$found" | grep . || echo NONE
}

# What one changed path runs: classes, ALL, or nothing.
targets_for() {
	local path="$1" found
	case "$path" in
	*/Localizable.xcstrings) found="$(string_targets "$path")" ;;
	"$ids_file") found="$(identifier_targets "$path")" ;;
	SnapshotTests/__Snapshots__/*)
		found="$(echo "$path" | cut -d/ -f3)"
		;;
	UITests/Support/*) found="" ;;
	UITests/* | SnapshotTests/*)
		found="$(types_in_file "$path")"
		# A deleted test file: its name says which class it held.
		[ -n "$found" ] || [ -f "$path" ] || found="$(basename "$path" .swift | cut -d+ -f1)"
		;;
	*) found="" ;;
	esac
	[ -n "$found" ] || found="$(map_targets "$path")"
	if [ -z "$found" ]; then
		echo "no rule for $path: running everything" >&2
		echo ALL
		return
	fi
	found="$(echo "$found" | awk '!seen[$0]++')"
	local runs
	runs="$(echo "$found" | grep -vx NONE | tr '\n' ' ' | sed 's/ $//')"
	echo "$path → ${runs:-nothing}" >&2
	echo "$found" | grep -vx NONE || true
}

check_map() {
	local status=0 class
	local mapped
	mapped="$(rules | cut -f2 | tr ' ' '\n' | grep -vx -e ALL -e NONE -e '' | sort -u)"
	for class in $mapped; do
		[ -n "$(target_of "$class")" ] || { echo "the map names $class, which no test file declares"; status=1; }
	done
	local declared
	declared="$(for dir in "${test_dirs[@]}"; do for f in "$dir"/*.swift; do types_in_file "$f"; done; done | sort -u)"
	for class in $declared; do
		[ -n "$(target_of "$class")" ] || continue # extensions of classes declared elsewhere
		echo "$mapped" | grep -qx "$class" || { echo "$class is not in the map (scripts/test-map.txt)"; status=1; }
	done
	return $status
}

if [ "${1:-}" = "--check-map" ]; then
	check_map
	exit
fi

base="${1:-origin/main}"
merge_base="$(git merge-base "$base" HEAD)"
changed="$({ git diff --name-only "$merge_base"; git ls-files --others --exclude-standard; } | sort -u)"

all=""
classes=""
while IFS= read -r path; do
	[ -n "$path" ] || continue
	for target in $(targets_for "$path"); do
		if [ "$target" = ALL ]; then
			all=1
		else
			classes+="$target"$'\n'
		fi
	done
done <<<"$changed"

if [ -n "$all" ]; then
	echo ALL
	exit 0
fi
for class in $(echo "$classes" | sort -u); do
	target="$(target_of "$class")"
	if [ -z "$target" ]; then
		echo "no test file declares $class: running everything" >&2
		echo ALL
		exit 0
	fi
	echo "$target/$class"
done | sort
