#!/bin/bash
# Positive fixtures (scripts/lint-fixtures/<rule>*.swift) each hold exactly one violation; assert
# SwiftLint reports that rule. Negative fixtures (scripts/lint-negatives/<rule>*.swift) must not
# trigger the rule. Fixtures are excluded from normal lint, so each is copied into a temp tree
# (under a Packages/ path, or the module path a rule is scoped to, so path-scoped rules apply) and linted with the repo config alone.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0

lint_fixture() { # file -> swiftlint output
    local name dir
    name="$(basename "$1" .swift)"
    case "$name" in
    *_in_screens) dir="$tmp/$name/Packages/FilingCabinetKit/Sources/Screens" ;;
    no_ui_imports_in_mac_modules*) dir="$tmp/$name/Packages/FilingCabinetKit/Sources/Core" ;;
    *) dir="$tmp/$name/Packages/Fixture/Sources" ;;
    esac
    mkdir -p "$dir"
    cp "$1" "$dir/"
    (cd "$tmp/$name" && swiftlint lint --no-cache --config "$root/.swiftlint.yml" --quiet Packages 2>&1)
}

for rule in no_print try_optional_needs_reason no_shared_in_package localized_needs_bundle disable_needs_reason analytics_token_enum_only no_ui_imports_in_mac_modules; do
    for file in "$root"/scripts/lint-fixtures/"$rule"*.swift; do
        out="$(lint_fixture "$file")"
        if grep -q "($rule)" <<<"$out"; then
            echo "PASS $(basename "$file")"
        else
            echo "FAIL $(basename "$file")"; echo "$out" | sed 's/^/    /'
            fail=1
        fi
    done
    for file in "$root"/scripts/lint-negatives/"$rule"*.swift; do
        [ -e "$file" ] || continue
        out="$(lint_fixture "$file")"
        if grep -q "($rule)" <<<"$out"; then
            echo "FAIL (negative) $(basename "$file")"; echo "$out" | sed 's/^/    /'
            fail=1
        else
            echo "PASS (negative) $(basename "$file")"
        fi
    done
done
exit $fail
