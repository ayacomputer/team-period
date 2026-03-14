#!/bin/sh
# ci_post_clone.sh — Xcode Cloud post-clone hook
#
# Responsibilities:
#   1. Install Flutter (version pinned in .fvmrc) into $HOME/flutter
#   2. Run `flutter precache --ios` to download prebuilt engine artifacts
#   3. Run `flutter pub get` to resolve Dart dependencies and generate
#      ios/Flutter/Generated.xcconfig (required before pod install)
#   4. Write android/key.properties from Xcode Cloud environment variables
#   4b. Inject Firebase keys as DART_DEFINES into Generated.xcconfig
#   5. Write firebase.env.json from Xcode Cloud environment variables
#   6. Generate GoogleService-Info.plist from Xcode Cloud environment variables
#   7. Run `pod install --deployment` to resolve CocoaPods dependencies
#
# Xcode Cloud cd's into ci_scripts/ before running this script, so pwd
# returns .../ios/ci_scripts — not the repository root. Walk up two levels
# from the script's own location to reliably reach the repository root.
#
# NOTE: shebang is #!/bin/sh — Xcode Cloud runs scripts with /bin/sh, not bash.
# Avoid bash-isms (no [[ ]], no pipefail, no local with assignment).

set -e

FLUTTER_ROOT="$HOME/flutter"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GENERATED_XCCONFIG="${REPO_ROOT}/ios/Flutter/Generated.xcconfig"

# Read the pinned Flutter version from .fvmrc so CI always matches local dev.
FLUTTER_VERSION="$(grep '"flutter"' "${REPO_ROOT}/.fvmrc" | sed 's/.*: *"\(.*\)".*/\1/')"

echo "=== ci_post_clone.sh starting ==="
echo "REPO_ROOT: $REPO_ROOT"
echo "Flutter version: $FLUTTER_VERSION"

# ---------------------------------------------------------------------------
# 1. Install Flutter (pinned version from .fvmrc)
#    --depth 1 gives a shallow clone — fast and sufficient for CI.
#    No need for --filter=blob:none alongside --depth 1: the shallow clone
#    already constrains history to one commit, so all working-tree blobs are
#    fetched at checkout regardless; the blobless filter adds protocol
#    overhead without saving any transfers.
# ---------------------------------------------------------------------------
echo "--- Installing Flutter $FLUTTER_VERSION ---"

if [ -d "$FLUTTER_ROOT" ]; then
  echo "Flutter already at $FLUTTER_ROOT, skipping clone."
else
  git clone https://github.com/flutter/flutter.git \
    --branch "$FLUTTER_VERSION" \
    --depth 1 \
    "$FLUTTER_ROOT"
fi

export PATH="${FLUTTER_ROOT}/bin:$PATH"
flutter --version

# ---------------------------------------------------------------------------
# 2. Precache iOS engine artifacts
#    Downloads prebuilt iOS engine artifacts that pod install needs.
#    Also bootstraps the Dart SDK.
# ---------------------------------------------------------------------------
echo "--- Running flutter precache --ios ---"
flutter precache --ios

# ---------------------------------------------------------------------------
# 3. Resolve Dart dependencies
#    Must run from REPO_ROOT (where pubspec.yaml lives).
#    This writes ios/Flutter/Generated.xcconfig which pod install needs.
# ---------------------------------------------------------------------------
echo "--- Running flutter pub get ---"
cd "$REPO_ROOT"
flutter pub get

# flutter pub get may exit 0 even if iOS codegen is skipped (e.g. wrong CWD
# or malformed pubspec.yaml). Verify the file was produced so pod install
# gets a clear error here rather than a confusing one downstream.
if [ ! -f "$GENERATED_XCCONFIG" ]; then
  echo "ERROR: flutter pub get succeeded but did not produce ${GENERATED_XCCONFIG}." >&2
  echo "ERROR: Verify this is a Flutter project with an ios/ directory and a valid pubspec.yaml." >&2
  exit 1
fi
echo "Generated.xcconfig OK"

# ---------------------------------------------------------------------------
# 4. Write android/key.properties from Xcode Cloud environment variables
#    The file is gitignored (contains secrets) so it must be recreated on CI.
#    build.gradle.kts reads this file to configure release signing.
#    Set all four as Secret environment variables in the Xcode Cloud workflow:
#    App Store Connect → [app] → Xcode Cloud → [workflow] → Edit
#      → Environment → Environment Variables (tick "Secret" for each)
# ---------------------------------------------------------------------------
echo "--- Writing android/key.properties ---"
if [ -n "${ANDROID_KEYSTORE_BASE64:-}" ]; then
    echo "${ANDROID_KEYSTORE_BASE64}" | base64 --decode > "${REPO_ROOT}/android/release.keystore"
    cat > "${REPO_ROOT}/android/key.properties" <<EOF
storePassword=${ANDROID_KEYSTORE_PASSWORD}
keyPassword=${ANDROID_KEY_PASSWORD}
keyAlias=${ANDROID_KEYSTORE_ALIAS}
storeFile=../android/release.keystore
EOF
    echo "android/key.properties written"
else
    echo "ANDROID_KEYSTORE_BASE64 not set — skipping key.properties (iOS-only build or unsigned Android)"
fi

# ---------------------------------------------------------------------------
# 4b. Inject Firebase keys as DART_DEFINES into Generated.xcconfig
#     String.fromEnvironment() values are compile-time constants set via
#     --dart-define. Xcode Cloud runs xcodebuild directly (not flutter build),
#     so --dart-define-from-file is never passed. Writing the encoded defines
#     into Generated.xcconfig is the equivalent that the Flutter Xcode toolchain
#     reads automatically during the archive.
#     Encoding: each key=value pair is base64-encoded, then comma-joined, which
#     matches the format Flutter's build system uses internally.
#
#     Remove this entire step if your app does not use Firebase.
# ---------------------------------------------------------------------------
echo "--- Injecting DART_DEFINES into Generated.xcconfig ---"

encode_define() {
  printf "%s" "$1" | base64
}

DART_DEFINES_VALUE="$(encode_define "FIREBASE_IOS_API_KEY=${FIREBASE_IOS_API_KEY}"),$(encode_define "FIREBASE_IOS_APP_ID=${FIREBASE_IOS_APP_ID}"),$(encode_define "FIREBASE_ANDROID_API_KEY=${FIREBASE_ANDROID_API_KEY}"),$(encode_define "FIREBASE_ANDROID_APP_ID=${FIREBASE_ANDROID_APP_ID}"),$(encode_define "FIREBASE_MESSAGING_SENDER_ID=${FIREBASE_MESSAGING_SENDER_ID}"),$(encode_define "FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID}"),$(encode_define "FIREBASE_STORAGE_BUCKET=${FIREBASE_STORAGE_BUCKET}"),$(encode_define "FIREBASE_IOS_BUNDLE_ID=${FIREBASE_IOS_BUNDLE_ID}")"

# Remove any existing DART_DEFINES line then append the new one
grep -v "^DART_DEFINES=" "$GENERATED_XCCONFIG" > "${GENERATED_XCCONFIG}.tmp" && mv "${GENERATED_XCCONFIG}.tmp" "$GENERATED_XCCONFIG"
echo "DART_DEFINES=${DART_DEFINES_VALUE}" >> "$GENERATED_XCCONFIG"
echo "DART_DEFINES injected into Generated.xcconfig"

# ---------------------------------------------------------------------------
# 5. Write firebase.env.json from Xcode Cloud environment variables
#    Secrets must be set in the Xcode Cloud workflow:
#    App Store Connect → [app] → Xcode Cloud → [workflow] → Edit
#      → Environment → Environment Variables (tick "Secret" for each)
#
#    Remove this step if your app does not use Firebase.
# ---------------------------------------------------------------------------
echo "--- Writing firebase.env.json ---"
cat > "${REPO_ROOT}/firebase.env.json" <<EOF
{
  "FIREBASE_ANDROID_API_KEY": "${FIREBASE_ANDROID_API_KEY}",
  "FIREBASE_ANDROID_APP_ID": "${FIREBASE_ANDROID_APP_ID}",
  "FIREBASE_IOS_API_KEY": "${FIREBASE_IOS_API_KEY}",
  "FIREBASE_IOS_APP_ID": "${FIREBASE_IOS_APP_ID}",
  "FIREBASE_MESSAGING_SENDER_ID": "${FIREBASE_MESSAGING_SENDER_ID}",
  "FIREBASE_PROJECT_ID": "${FIREBASE_PROJECT_ID}",
  "FIREBASE_STORAGE_BUCKET": "${FIREBASE_STORAGE_BUCKET}",
  "FIREBASE_IOS_BUNDLE_ID": "${FIREBASE_IOS_BUNDLE_ID}"
}
EOF
echo "firebase.env.json written"

# ---------------------------------------------------------------------------
# 6. Generate GoogleService-Info.plist from Xcode Cloud environment variables
#    The file is gitignored (contains secrets) so it must be recreated on CI.
#    All values below must be set as Secret environment variables in the
#    Xcode Cloud workflow: App Store Connect → [app] → Xcode Cloud →
#    [workflow] → Edit → Environment → Environment Variables.
#
#    Remove this step if your app does not use Firebase.
# ---------------------------------------------------------------------------
echo "--- Validating required Firebase env vars ---"
for var in FIREBASE_IOS_API_KEY FIREBASE_IOS_APP_ID FIREBASE_MESSAGING_SENDER_ID \
           FIREBASE_PROJECT_ID FIREBASE_STORAGE_BUCKET FIREBASE_IOS_BUNDLE_ID; do
  eval "val=\$$var"
  if [ -z "$val" ]; then
    echo "ERROR: Required env var $var is not set — add it as a Secret in the Xcode Cloud workflow"
    exit 1
  fi
done
echo "All required Firebase env vars present"

echo "--- Generating GoogleService-Info.plist ---"
cat > "${REPO_ROOT}/ios/Runner/GoogleService-Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>API_KEY</key>
	<string>${FIREBASE_IOS_API_KEY}</string>
	<key>GCM_SENDER_ID</key>
	<string>${FIREBASE_MESSAGING_SENDER_ID}</string>
	<key>PLIST_VERSION</key>
	<string>1</string>
	<key>BUNDLE_ID</key>
	<string>${FIREBASE_IOS_BUNDLE_ID}</string>
	<key>PROJECT_ID</key>
	<string>${FIREBASE_PROJECT_ID}</string>
	<key>STORAGE_BUCKET</key>
	<string>${FIREBASE_STORAGE_BUCKET}</string>
	<key>IS_ADS_ENABLED</key>
	<false/>
	<key>IS_ANALYTICS_ENABLED</key>
	<false/>
	<key>IS_APPINVITE_ENABLED</key>
	<true/>
	<key>IS_GCM_ENABLED</key>
	<true/>
	<key>IS_SIGNIN_ENABLED</key>
	<true/>
	<key>GOOGLE_APP_ID</key>
	<string>${FIREBASE_IOS_APP_ID}</string>
</dict>
</plist>
EOF
echo "GoogleService-Info.plist generated"

# ---------------------------------------------------------------------------
# 7. Install CocoaPods dependencies
#    --deployment: installs exactly the versions pinned in Podfile.lock without
#    updating the spec repo. This guarantees Pods/Manifest.lock matches
#    Podfile.lock, preventing the [CP] Check Pods Manifest.lock build phase
#    from failing with exit code 65.
# ---------------------------------------------------------------------------
echo "--- Running pod install ---"
cd "${REPO_ROOT}/ios"
pod install --deployment

echo "=== ci_post_clone.sh done ==="
