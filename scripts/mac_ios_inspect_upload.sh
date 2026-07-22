#!/usr/bin/env bash
set -Eeuo pipefail

# Ancient Secured Vault — inspect or upload the integrated iOS v1.0.1 build.
#
# Inspect only (default):
#   ./mac_ios_inspect_upload.sh
#
# Validate and upload to App Store Connect:
#   ASC_KEY_ID="YOUR_KEY_ID" \
#   ASC_ISSUER_ID="YOUR_ISSUER_ID" \
#   ./mac_ios_inspect_upload.sh upload
#
# If Apple already has build 7, create build 8 without editing pubspec.yaml:
#   IOS_BUILD_NUMBER=8 ASC_KEY_ID="..." ASC_ISSUER_ID="..." \
#   ./mac_ios_inspect_upload.sh upload

MODE="${1:-inspect}"
REPO_URL="${REPO_URL:-https://github.com/Ndeegonelson/ancient-secured-vault.git}"
BRANCH="${BRANCH:-master}"
APP_DIR="${APP_DIR:-$HOME/Developer/ancient-secured-vault}"
EXPECTED_COMMIT="${EXPECTED_COMMIT:-1d6cddd740382a038bd9b711bc1de4f9f6f868fd}"
IOS_VERSION="${IOS_VERSION:-1.0.1}"
SOURCE_BUILD_NUMBER="7"
IOS_BUILD_NUMBER="${IOS_BUILD_NUMBER:-$SOURCE_BUILD_NUMBER}"
BUNDLE_ID="${BUNDLE_ID:-tech.ancientsociety.vault}"
ASC_KEY_ID="${ASC_KEY_ID:-}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-}"
ASC_KEY_FILE="${ASC_KEY_FILE:-}"

fail() {
  printf '\nERROR: %s\n' "$1" >&2
  exit 1
}

step() {
  printf '\n\033[1;32m==> %s\033[0m\n' "$1"
}

case "$MODE" in
  inspect|upload) ;;
  *) fail "Usage: $0 [inspect|upload]" ;;
esac

for command_name in git flutter dart xcodebuild pod plutil codesign security xcrun ditto find; do
  command -v "$command_name" >/dev/null 2>&1 || \
    fail "Missing required command: $command_name"
done

xcode-select -p >/dev/null 2>&1 || \
  fail "Select Xcode first: sudo xcode-select -s /Applications/Xcode.app"

step "Update the clean repository"
if [[ ! -d "$APP_DIR/.git" ]]; then
  mkdir -p "$(dirname "$APP_DIR")"
  git clone --branch "$BRANCH" "$REPO_URL" "$APP_DIR"
else
  [[ -z "$(git -C "$APP_DIR" status --porcelain)" ]] || \
    fail "The repository has uncommitted work. Commit or stash it first."
  git -C "$APP_DIR" fetch --prune --tags origin
  git -C "$APP_DIR" switch "$BRANCH"
  git -C "$APP_DIR" pull --ff-only origin "$BRANCH"
fi

cd "$APP_DIR"
git merge-base --is-ancestor "$EXPECTED_COMMIT" HEAD || \
  fail "Integrated commit $EXPECTED_COMMIT is not present on $BRANCH."

grep -Eq "^version:[[:space:]]+$IOS_VERSION\+$SOURCE_BUILD_NUMBER[[:space:]]*$" pubspec.yaml || \
  fail "Expected integrated source version $IOS_VERSION+$SOURCE_BUILD_NUMBER."
[[ -f ios/Runner/GoogleService-Info.plist ]] || \
  fail "ios/Runner/GoogleService-Info.plist is missing."
[[ -f ios/Configuration.storekit ]] || \
  fail "The StoreKit configuration is missing."
grep -q 'tech.ancientsociety.vault.premium.yearly' ios/Configuration.storekit || \
  fail "The premium yearly StoreKit product is missing."
grep -q 'enableReaderStayAwake' ios/Runner/AppDelegate.swift || \
  fail "The native reader keep-awake channel is missing."
plutil -extract UIBackgroundModes xml1 -o - ios/Runner/Info.plist 2>/dev/null | \
  grep -q '<string>audio</string>' || \
  fail "Background narration is not declared in Info.plist."

printf 'Source: '
git log -1 --oneline
printf 'Building iOS %s (%s)\n' "$IOS_VERSION" "$IOS_BUILD_NUMBER"

step "Inspect the toolchain"
flutter --version
flutter doctor -v
xcodebuild -version
pod --version

step "Resolve dependencies"
flutter clean
flutter pub get
(
  cd ios
  pod install --repo-update
)

step "Analyze and test"
flutter analyze --no-fatal-infos
flutter test --no-pub

step "Compile for the iOS Simulator"
flutter build ios --simulator --debug --no-pub \
  --build-name="$IOS_VERSION" \
  --build-number="$IOS_BUILD_NUMBER"

step "Create the signed App Store archive and IPA"
flutter build ipa --release --no-pub \
  --build-name="$IOS_VERSION" \
  --build-number="$IOS_BUILD_NUMBER"

IPA_PATH="$(find build/ios/ipa -maxdepth 1 -type f -name '*.ipa' -print -quit)"
[[ -n "$IPA_PATH" && -f "$IPA_PATH" ]] || fail "No IPA was produced."
IPA_PATH="$(cd "$(dirname "$IPA_PATH")" && pwd)/$(basename "$IPA_PATH")"
ARCHIVE_PATH="$APP_DIR/build/ios/archive/Runner.xcarchive"

step "Inspect signing and embedded application metadata"
INSPECT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ancient-vault-ios.XXXXXX")"
trap 'rm -rf "$INSPECT_DIR"' EXIT
ditto -x -k "$IPA_PATH" "$INSPECT_DIR"
APP_BUNDLE="$(find "$INSPECT_DIR/Payload" -maxdepth 1 -type d -name '*.app' -print -quit)"
[[ -n "$APP_BUNDLE" ]] || fail "The IPA does not contain an app bundle."

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
ACTUAL_BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw -o - "$APP_BUNDLE/Info.plist")"
ACTUAL_VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$APP_BUNDLE/Info.plist")"
ACTUAL_BUILD="$(plutil -extract CFBundleVersion raw -o - "$APP_BUNDLE/Info.plist")"

[[ "$ACTUAL_BUNDLE_ID" == "$BUNDLE_ID" ]] || \
  fail "IPA bundle ID is $ACTUAL_BUNDLE_ID; expected $BUNDLE_ID."
[[ "$ACTUAL_VERSION" == "$IOS_VERSION" ]] || \
  fail "IPA version is $ACTUAL_VERSION; expected $IOS_VERSION."
[[ "$ACTUAL_BUILD" == "$IOS_BUILD_NUMBER" ]] || \
  fail "IPA build is $ACTUAL_BUILD; expected $IOS_BUILD_NUMBER."

PROFILE_PATH="$APP_BUNDLE/embedded.mobileprovision"
[[ -f "$PROFILE_PATH" ]] || fail "The IPA has no embedded provisioning profile."
security cms -D -i "$PROFILE_PATH" > "$INSPECT_DIR/profile.plist"
PROFILE_NAME="$(plutil -extract Name raw -o - "$INSPECT_DIR/profile.plist")"
TEAM_ID="$(plutil -extract TeamIdentifier.0 raw -o - "$INSPECT_DIR/profile.plist")"
EXPIRATION="$(plutil -extract ExpirationDate raw -o - "$INSPECT_DIR/profile.plist")"

printf '\nIPA inspection passed:\n'
printf '  File: %s\n' "$IPA_PATH"
printf '  Bundle ID: %s\n' "$ACTUAL_BUNDLE_ID"
printf '  Version/build: %s (%s)\n' "$ACTUAL_VERSION" "$ACTUAL_BUILD"
printf '  Provisioning profile: %s\n' "$PROFILE_NAME"
printf '  Apple team: %s\n' "$TEAM_ID"
printf '  Profile expires: %s\n' "$EXPIRATION"

if [[ "$MODE" == "inspect" ]]; then
  printf '\nInspection finished. Nothing was uploaded.\n'
  printf 'Rerun with API-key variables and the upload argument when ready.\n'
  open "$ARCHIVE_PATH"
  exit 0
fi

step "Prepare App Store Connect authentication"
[[ -n "$ASC_KEY_ID" ]] || fail "Set ASC_KEY_ID to a team API key ID."
[[ -n "$ASC_ISSUER_ID" ]] || fail "Set ASC_ISSUER_ID to the key issuer ID."

if [[ -z "$ASC_KEY_FILE" ]]; then
  ASC_KEY_FILE="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
fi
[[ -f "$ASC_KEY_FILE" ]] || \
  fail "API private key not found at $ASC_KEY_FILE"
[[ "$(basename "$ASC_KEY_FILE")" == "AuthKey_${ASC_KEY_ID}.p8" ]] || \
  fail "The key file must be named AuthKey_${ASC_KEY_ID}.p8"

export API_PRIVATE_KEYS_DIR
API_PRIVATE_KEYS_DIR="$(cd "$(dirname "$ASC_KEY_FILE")" && pwd)"

step "Validate the IPA with App Store Connect"
xcrun altool --validate-app \
  --type ios \
  --file "$IPA_PATH" \
  --apiKey "$ASC_KEY_ID" \
  --apiIssuer "$ASC_ISSUER_ID"

printf '\nValidation passed. Type UPLOAD to send %s (%s) to App Store Connect: ' \
  "$IOS_VERSION" "$IOS_BUILD_NUMBER"
read -r confirmation
[[ "$confirmation" == "UPLOAD" ]] || fail "Upload cancelled."

step "Upload the validated IPA"
xcrun altool --upload-app \
  --type ios \
  --file "$IPA_PATH" \
  --apiKey "$ASC_KEY_ID" \
  --apiIssuer "$ASC_ISSUER_ID"

printf '\nUpload accepted by App Store Connect. Apple will now process the build.\n'
printf 'Check App Store Connect → TestFlight → iOS for processing status.\n'
