#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# scripts/testflight/archive.sh: the env it needs, the feedback address, the ad-hoc archive check and the key.

REPO="$BATS_TEST_DIRNAME/../../.."
ADDRESS="Packages/FilingCabinetKit/Sources/ScreenModels/Feedback/FeedbackAddress.swift"

setup() {
  export TMPDIR="$BATS_TEST_TMPDIR"
  FIX="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FIX/scripts/testflight" "$FIX/$(dirname "$ADDRESS")" "$FIX/bin"
  cp "$REPO/scripts/testflight/archive.sh" "$REPO/scripts/testflight/ExportOptions.plist" "$FIX/scripts/testflight/"
  cp "$REPO/$ADDRESS" "$FIX/$ADDRESS"
  git -C "$FIX" init -q -b main
  cd "$FIX"

  # Stub xcodebuild: echoes its arguments (so a key in them would show) and makes the archive's bundles.
  cat >"$FIX/bin/xcodebuild" <<'STUB'
#!/usr/bin/env bash
echo "xcodebuild $*"
args=("$@")
for i in "${!args[@]}"; do
  if [ "${args[$i]}" = -archivePath ] && [ "${args[0]}" = archive ]; then
    app="${args[$((i + 1))]}/Products/Applications/FilingCabinet.app"
    mkdir -p "$app/PlugIns/FilingCabinetControls.appex"
    plutil -create xml1 "$app/Info.plist"
    plutil -insert CFBundleShortVersionString -string 1.0 "$app/Info.plist"
    plutil -insert CFBundleVersion -string "$BUILD_NUMBER" "$app/Info.plist"
  fi
done
exit "${STUB_STATUS:-0}"
STUB
  # Stub codesign: ad-hoc unless STUB_SIGNATURE says otherwise.
  cat >"$FIX/bin/codesign" <<'STUB'
#!/usr/bin/env bash
echo "Executable=${*: -1}" >&2
echo "Signature=${STUB_SIGNATURE:-adhoc}" >&2
STUB
  chmod +x "$FIX/bin/xcodebuild" "$FIX/bin/codesign"
  export FC_XCODEBUILD="$FIX/bin/xcodebuild" FC_CODESIGN="$FIX/bin/codesign" FC_BEAUTIFY=cat
  export DERIVED="$FIX/.build/DerivedData" PROJECT=P.xcodeproj XCB_FLAGS=""

  printf -- '-----BEGIN PRIVATE KEY-----\nTHEKEYCONTENTS\n-----END PRIVATE KEY-----\n' >"$BATS_TEST_TMPDIR/AuthKey.p8"
  export ASC_KEY_ID=KEYID12345 ASC_ISSUER_ID=issuer-0000 ASC_KEY_PATH="$BATS_TEST_TMPDIR/AuthKey.p8" BUILD_NUMBER=7
}

@test "refuses without the key env" {
  unset ASC_KEY_ID
  run -2 scripts/testflight/archive.sh
  [[ "$output" == *"ASC_KEY_ID"* ]]
  [ ! -d .build/testflight ]
}

@test "refuses a missing key file or a build number that isn't a number" {
  ASC_KEY_PATH="$BATS_TEST_TMPDIR/nope.p8" run -2 scripts/testflight/archive.sh
  [[ "$output" == *"ASC_KEY_PATH"* ]]
  BUILD_NUMBER=7a run -2 scripts/testflight/archive.sh
  [[ "$output" == *"BUILD_NUMBER"* ]]
}

@test "refuses the placeholder address" {
  sed -i '' 's/static let value = ".*"/static let value = "feedback@example.invalid"/' "$ADDRESS"
  run -2 scripts/testflight/archive.sh
  [[ "$output" == *"placeholder"* ]]
  [ ! -d .build/testflight ]
}

@test "archives ad-hoc without the key, then exports and uploads with it" {
  FC_BEAUTIFY="sed -n /error/p" run -0 scripts/testflight/archive.sh
  archive_call="$(grep '^xcodebuild archive ' .build/testflight/archive.log)"
  [[ "$archive_call" == *"CODE_SIGN_IDENTITY=- AD_HOC_CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Automatic"* ]]
  [[ "$archive_call" == *"DEVELOPMENT_TEAM=W6S6K84XVM"* ]]
  [[ "$archive_call" == *"CURRENT_PROJECT_VERSION=7"* ]]
  [[ "$archive_call" != *"allowProvisioning"* && "$archive_call" != *"authenticationKey"* ]]
  export_call="$(grep '^xcodebuild -exportArchive ' .build/testflight/export.log)"
  [[ "$export_call" == *"-allowProvisioningUpdates -authenticationKeyPath $ASC_KEY_PATH"* ]]
  [[ "$export_call" == *"-exportOptionsPlist scripts/testflight/ExportOptions.plist"* ]]
  [ "$output" = "$(printf 'Version: 1.0\nBuild: 7\nArchive: %s/.build/testflight/FilingCabinet.xcarchive' "$(git rev-parse --show-toplevel)")" ]
}

@test "stops before the upload when a bundle in the archive is signed with a certificate" {
  STUB_SIGNATURE=size=1234 run -1 scripts/testflight/archive.sh
  [[ "$output" == *"Products/Applications/FilingCabinet.app is not ad-hoc signed"* ]]
  [ ! -f .build/testflight/export.log ]
}

@test "a failing xcodebuild fails the script and shows the log's end" {
  STUB_STATUS=65 run -1 scripts/testflight/archive.sh
  [[ "$output" == *"archive failed"* ]]
  [[ "$output" == *"xcodebuild archive "* ]]
}

@test "never prints the key" {
  FC_BEAUTIFY=cat run -0 scripts/testflight/archive.sh
  [[ "$output" == *"xcodebuild archive "* ]] # the stub's echo of its arguments got through
  [[ "$output" != *THEKEYCONTENTS* && "$output" != *"PRIVATE KEY"* ]]
  ! grep -rq THEKEYCONTENTS .build/testflight
}
