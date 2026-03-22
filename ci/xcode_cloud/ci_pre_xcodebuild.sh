#!/bin/bash
# ci/xcode_cloud/ci_pre_xcodebuild.sh
#
# Xcode Cloud pre-build script.
# - Installs Flutter
# - Generates GoogleService-Info.plist from Xcode Cloud secret env vars
# - Runs flutter pub get and pod install
#
# Required Xcode Cloud secret environment variables (mark each as Secret):
#   FIREBASE_IOS_API_KEY, FIREBASE_IOS_APP_ID, FIREBASE_MESSAGING_SENDER_ID,
#   FIREBASE_PROJECT_ID, FIREBASE_STORAGE_BUCKET, FIREBASE_IOS_BUNDLE_ID,
#   FIREBASE_ANDROID_API_KEY, FIREBASE_ANDROID_APP_ID, FIREBASE_ANDROID_PACKAGE_NAME

set -euo pipefail

FLUTTER_DIR="$HOME/flutter"

# ── 1. Install Flutter ────────────────────────────────────────────────────────
echo "▶ Installing Flutter (stable)..."
if [ ! -d "$FLUTTER_DIR" ]; then
  git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"
flutter --version

# ── 2. Generate GoogleService-Info.plist from env vars ───────────────────────
echo "▶ Generating GoogleService-Info.plist from environment variables..."

# Validate that all required secrets are present before proceeding
REQUIRED_VARS=(
  FIREBASE_IOS_API_KEY
  FIREBASE_IOS_APP_ID
  FIREBASE_MESSAGING_SENDER_ID
  FIREBASE_PROJECT_ID
  FIREBASE_STORAGE_BUCKET
  FIREBASE_IOS_BUNDLE_ID
  FIREBASE_ANDROID_API_KEY
  FIREBASE_ANDROID_APP_ID
  FIREBASE_ANDROID_PACKAGE_NAME
)
for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var:-}" ]; then
    echo "✗ Missing required secret: $var"
    echo "  Add it in App Store Connect → Xcode Cloud → [workflow] → Environment → Environment Variables"
    exit 1
  fi
done

cat > "$SRCROOT/ios/Runner/GoogleService-Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>API_KEY</key>             <string>${FIREBASE_IOS_API_KEY}</string>
  <key>GCM_SENDER_ID</key>      <string>${FIREBASE_MESSAGING_SENDER_ID}</string>
  <key>PLIST_VERSION</key>      <string>1</string>
  <key>BUNDLE_ID</key>          <string>${FIREBASE_IOS_BUNDLE_ID}</string>
  <key>PROJECT_ID</key>         <string>${FIREBASE_PROJECT_ID}</string>
  <key>STORAGE_BUCKET</key>     <string>${FIREBASE_STORAGE_BUCKET}</string>
  <key>GOOGLE_APP_ID</key>      <string>${FIREBASE_IOS_APP_ID}</string>
  <key>IS_ADS_ENABLED</key>     <false/>
  <key>IS_ANALYTICS_ENABLED</key> <false/>
  <key>IS_APPINVITE_ENABLED</key> <true/>
  <key>IS_GCM_ENABLED</key>     <true/>
  <key>IS_SIGNIN_ENABLED</key>  <true/>
</dict>
</plist>
PLIST

echo "✓ GoogleService-Info.plist generated."

# ── 3. Generate google-services.json (Android) ───────────────────────────────
echo "▶ Generating google-services.json from environment variables..."

cat > "$SRCROOT/android/app/google-services.json" <<JSON
{
  "project_info": {
    "project_number": "${FIREBASE_MESSAGING_SENDER_ID}",
    "project_id": "${FIREBASE_PROJECT_ID}",
    "storage_bucket": "${FIREBASE_STORAGE_BUCKET}"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "${FIREBASE_ANDROID_APP_ID}",
        "android_client_info": {
          "package_name": "${FIREBASE_ANDROID_PACKAGE_NAME}"
        }
      },
      "oauth_client": [],
      "api_key": [
        {
          "current_key": "${FIREBASE_ANDROID_API_KEY}"
        }
      ],
      "services": {
        "appinvite_service": {
          "other_platform_oauth_client": []
        }
      }
    }
  ],
  "configuration_version": "1"
}
JSON

echo "✓ google-services.json generated."

# ── 4. Flutter pub get ────────────────────────────────────────────────────────
echo "▶ Running flutter pub get..."
cd "$SRCROOT"
flutter pub get

# ── 5. Pod install ────────────────────────────────────────────────────────────
echo "▶ Running pod install..."
cd "$SRCROOT/ios"
pod install --repo-update

echo "✓ Pre-build complete."
