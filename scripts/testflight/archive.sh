#!/usr/bin/env bash
# Archives the app and uploads it to App Store Connect for TestFlight (`make testflight-archive`, the TestFlight
# workflow). Reads ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (the .p8 file) and BUILD_NUMBER, and PROJECT, DERIVED and
# XCB_FLAGS (the Makefile passes them).
#
# The archive is ad-hoc signed and gets no key, so it can't reach Apple and never creates a certificate. The export
# signs the app and its extension with the team's cloud-managed distribution certificate (the key must be Admin) and
# uploads. A new capability or extension needs one automatic-signing build first (`make device`): the export won't
# register app IDs.
#
# Prints the version, the build and the archive path. xcodebuild's output goes to .build/testflight/{archive,export}.log
# (only its errors are shown), and the key is passed by path, never read.
# FC_XCODEBUILD, FC_CODESIGN and FC_BEAUTIFY are seams for the bats tests.
set -euo pipefail
root="$(git rev-parse --show-toplevel)"
cd "$root"
xcodebuild="${FC_XCODEBUILD:-xcodebuild}"
codesign="${FC_CODESIGN:-codesign}"
beautify="${FC_BEAUTIFY:-xcbeautify --quieter}"
options="scripts/testflight/ExportOptions.plist"
address="Packages/FilingCabinetKit/Sources/ScreenModels/Feedback/FeedbackAddress.swift"
out="$root/.build/testflight"
archive="$out/FilingCabinet.xcarchive"

fail() {
	echo "error: $*" >&2
	exit 2
}

missing=""
for name in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH BUILD_NUMBER; do
	[ -n "${!name:-}" ] || missing="$missing $name"
done
[ -z "$missing" ] || fail "not set:$missing"
[ -f "$ASC_KEY_PATH" ] || fail "ASC_KEY_PATH names no file"
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || fail "BUILD_NUMBER must be a positive whole number"

# Feedback from testers goes to FeedbackAddress.value: never ship the placeholder.
string_constant() { sed -nE "s/.*static let $1 = \"([^\"]*)\".*/\1/p" "$address"; }
value="$(string_constant value)"
[ -n "$value" ] && [ "$value" != "$(string_constant placeholder)" ] ||
	fail "FeedbackAddress.value is still the placeholder; set the real address in $address"

team="$(/usr/libexec/PlistBuddy -c 'Print :teamID' "$options")"

# Runs xcodebuild with its output in .build/testflight/<step>.log, showing only errors; on failure, the log's end.
run_xcodebuild() {
	local step="$1"
	shift
	local log="$out/$step.log"
	if ! "$xcodebuild" "$@" 2>&1 | tee "$log" | $beautify; then
		echo "error: $step failed. The end of $log:" >&2
		tail -40 "$log" >&2
		exit 1
	fi
}

rm -rf "$out"
mkdir -p "$out"

# shellcheck disable=SC2086 # XCB_FLAGS is a list of flags.
run_xcodebuild archive archive ${XCB_FLAGS:-} -project "$PROJECT" -scheme FilingCabinet -configuration Release \
	-destination 'generic/platform=iOS' -archivePath "$archive" -derivedDataPath "$DERIVED" \
	CODE_SIGN_IDENTITY=- AD_HOC_CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="$team" \
	CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

# Proof the archive used no certificate: every bundle in it is ad-hoc signed.
app="$archive/Products/Applications/FilingCabinet.app"
[ -d "$app" ] || { echo "error: the archive has no FilingCabinet.app" >&2; exit 1; }
while IFS= read -r bundle; do
	"$codesign" -dv "$bundle" 2>&1 | grep -qx 'Signature=adhoc' ||
		{ echo "error: ${bundle#"$archive/"} is not ad-hoc signed: the archive must not use a certificate" >&2; exit 1; }
done < <(find "$app" \( -name '*.app' -o -name '*.appex' \) -type d)

run_xcodebuild export -exportArchive -archivePath "$archive" -exportPath "$out/export" -exportOptionsPlist "$options" \
	-allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY_PATH" \
	-authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID"

plist="$app/Info.plist"
echo "Version: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")"
echo "Build: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")"
echo "Archive: $archive"
