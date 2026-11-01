#!/bin/bash
# Each fixture holds exactly one violation; assert SwiftLint reports that fixture's rule id.
# Fixtures are excluded from normal lint, so each is copied into a temp tree (under a
# Packages/ path so path-scoped rules apply) and linted with the repo config alone.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0
for rule in no_print try_optional_needs_reason no_shared_in_package localized_needs_bundle disable_needs_reason analytics_token_enum_only; do
    dir="$tmp/$rule/Packages/Fixture/Sources"
    mkdir -p "$dir"
    cp "$root/scripts/lint-fixtures/$rule.swift" "$dir/"
    out="$(cd "$tmp/$rule" && swiftlint lint --no-cache --config "$root/.swiftlint.yml" --quiet Packages 2>&1)"
    if grep -q "($rule)" <<<"$out"; then
        echo "PASS $rule"
    else
        echo "FAIL $rule"; echo "$out" | sed 's/^/    /'
        fail=1
    fi
done
exit $fail
