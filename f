#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  f  —  Flutter + mobile-cicd task runner (Mac / Linux)
#
#  Usage:
#    ./f setup            # check tools + install deps
#    ./f setup:workflow   # generate .github/workflows/ci-cd.yml from .env
#    ./f dev              # run app on connected device/emulator
#    ./f test             # run unit + widget tests
#    ./f build:android    # build signed AAB
#    ./f build:ios        # build signed IPA (requires Xcode + APPLE_TEAM_ID)
#    ./f build-deploy:ios # build IPA and upload to App Store Connect
#
#  Windows users: use f.ps1 instead.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

COMMAND="${1:-help}"
ENV_FILE=".env"
EXPORT_OPTIONS_PLIST_TEMPLATE=".github/ios/ExportOptions.plist"
ASC_API_URL="https://api.appstoreconnect.apple.com/v1"

# ── Helpers ───────────────────────────────────────────────────────────────────

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Error: '$COMMAND' requires macOS with Xcode. Run this on a Mac."
    exit 1
  fi
}

load_env() {
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: .env not found. Copy .env.example to .env and fill in your values."
    exit 1
  fi
  if grep -q $'\xef\xbb\xbf' "$ENV_FILE"; then
    echo "Error: .env file contains a BOM character. Please clean the file."
    exit 1
  fi
  while IFS='=' read -r key value; do
    if [[ $key =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      export "$key=$value"
    fi
  done < <(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$ENV_FILE")
}

require_apple_team_id() {
  load_env
  if [[ -z "${APPLE_TEAM_ID:-}" ]]; then
    echo "Error: APPLE_TEAM_ID is not set in .env"
    echo "  Find it: security find-identity -v -p codesigning"
    exit 1
  fi
}

make_export_options() {
  local tmp
  tmp="$(mktemp /tmp/ExportOptions.XXXXXX.plist)"
  sed "s/__APPLE_TEAM_ID__/${APPLE_TEAM_ID}/" "$EXPORT_OPTIONS_PLIST_TEMPLATE" > "$tmp"
  echo "$tmp"
}

require_xcode_cloud_creds() {
  load_env
  local missing=()
  [[ -z "${ASC_KEY_ID:-}"           ]] && missing+=("ASC_KEY_ID")
  [[ -z "${ASC_ISSUER_ID:-}"        ]] && missing+=("ASC_ISSUER_ID")
  [[ -z "${ASC_PRIVATE_KEY_PATH:-}" ]] && missing+=("ASC_PRIVATE_KEY_PATH")
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Error: Missing App Store Connect API credentials in .env:"
    for var in "${missing[@]}"; do echo "  $var"; done
    exit 1
  fi
  ASC_PRIVATE_KEY_PATH="${ASC_PRIVATE_KEY_PATH/#\~/$HOME}"
  if [[ ! -f "$ASC_PRIVATE_KEY_PATH" ]]; then
    echo "Error: ASC_PRIVATE_KEY_PATH file not found: $ASC_PRIVATE_KEY_PATH"
    exit 1
  fi
}

make_asc_token() {
  local now exp
  now=$(date +%s)
  exp=$(( now + 900 ))
  python3 - <<PYEOF
import base64, json, subprocess, sys

def b64url(data):
    if isinstance(data, str): data = data.encode()
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode()

def der_to_raw_sig(der):
    assert der[0] == 0x30
    idx = 2
    assert der[idx] == 0x02
    r_len = der[idx + 1]
    r = int.from_bytes(der[idx + 2 : idx + 2 + r_len], 'big')
    idx += 2 + r_len
    assert der[idx] == 0x02
    s_len = der[idx + 1]
    s = int.from_bytes(der[idx + 2 : idx + 2 + s_len], 'big')
    return r.to_bytes(32, 'big') + s.to_bytes(32, 'big')

header  = b64url(json.dumps({"alg":"ES256","kid":"${ASC_KEY_ID}","typ":"JWT"}, separators=(',',':')))
payload = b64url(json.dumps({"iss":"${ASC_ISSUER_ID}","iat":${now},"exp":${exp},"aud":"appstoreconnect-v1"}, separators=(',',':')))
message = f"{header}.{payload}"
result  = subprocess.run(["openssl","dgst","-sha256","-sign","${ASC_PRIVATE_KEY_PATH}"],
              input=message.encode(), capture_output=True)
if result.returncode != 0:
    print(result.stderr.decode(), file=sys.stderr); sys.exit(1)
print(f"{header}.{payload}.{b64url(der_to_raw_sig(result.stdout))}", end='')
PYEOF
}

find_xcode_cloud_workflow() {
  local token="$1"
  local response product_id workflow_id
  response=$(curl -sf -H "Authorization: Bearer $token" \
    "${ASC_API_URL}/ciProducts?filter%5BproductType%5D=APP")
  product_id=$(python3 -c "
import sys, json
data = json.loads('''${response}''')
for p in data.get('data', []):
  if p.get('attributes', {}).get('bundleId') == '${IOS_BUNDLE_IDENTIFIER}':
    print(p['id']); break
")
  [[ -z "$product_id" ]] && { echo "Error: No Xcode Cloud product for '${IOS_BUNDLE_IDENTIFIER}'." >&2; exit 1; }
  response=$(curl -sf -H "Authorization: Bearer $token" \
    "${ASC_API_URL}/ciProducts/${product_id}/workflows")
  workflow_id=$(python3 -c "
import sys, json
items = json.loads('''${response}''').get('data', [])
if items: print(items[0]['id'])
")
  [[ -z "$workflow_id" ]] && { echo "Error: No workflows for product '${product_id}'." >&2; exit 1; }
  echo "$workflow_id"
}

trigger_build_run() {
  local token="$1" workflow_id="$2"
  local body="{\"data\":{\"type\":\"ciBuildRuns\",\"relationships\":{\"workflow\":{\"data\":{\"type\":\"ciWorkflows\",\"id\":\"${workflow_id}\"}}}}}"
  curl -sf -X POST -H "Authorization: Bearer $token" -H "Content-Type: application/json" \
    -d "$body" "${ASC_API_URL}/ciBuildRuns" \
    | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['id'])"
}

poll_build_run() {
  local token="$1" run_id="$2" status interval=15
  echo "Polling build run ${run_id} (every ${interval}s)..."
  while true; do
    status=$(curl -sf -H "Authorization: Bearer $token" \
      "${ASC_API_URL}/ciBuildRuns/${run_id}" \
      | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['attributes']['executionProgress'])")
    case "$status" in
      COMPLETE) echo "✓ Build completed."; return 0 ;;
      FAILED|ERRORED|CANCELED|STOPPED) echo "✗ Build ended: $status"; return 1 ;;
      *) echo "  Status: $status — waiting ${interval}s..."; sleep "$interval" ;;
    esac
  done
}

# ── Commands ──────────────────────────────────────────────────────────────────

# Clears Flutter build outputs — safe to call for any platform/command.
flutter_clean() {
  echo "Cleaning Flutter build cache..."
  flutter clean
}

# Clears Flutter build outputs + global Xcode caches.
# Only call this before iOS builds; it is a global operation that affects
# all Xcode projects on the machine and takes time to rebuild.
ios_clean() {
  flutter_clean
  echo "Clearing Xcode DerivedData and caches..."
  rm -rf ~/Library/Developer/Xcode/DerivedData &
  rm -rf ~/Library/Caches/com.apple.dt.Xcode &
  wait
}

case "$COMMAND" in

  setup)
    curl -fsSL https://raw.githubusercontent.com/ayacomputer/mobile-cicd/main/scripts/setup-flutter.sh | bash
    ;;

  setup:workflow)
    curl -fsSL https://raw.githubusercontent.com/ayacomputer/mobile-cicd/main/scripts/setup-workflow.sh | bash
    ;;

  dev)
    flutter_clean
    flutter run --dart-define-from-file=firebase.env.json
    ;;
  test)
    flutter_clean
    flutter test
    ;;
  test:ios)
    require_macos
    # `-d ios` only matches physical devices; pick the booted simulator by ID instead.
    IOS_SIM_ID="$(xcrun simctl list devices booted -j \
      | python3 -c "import sys,json; d=json.load(sys.stdin)['devices']; \
          ids=[dev['udid'] for devs in d.values() for dev in devs if dev.get('state')=='Booted' and 'iPhone' in dev.get('name','')]; \
          print(ids[0] if ids else '')")"
    if [[ -z "$IOS_SIM_ID" ]]; then
      # No booted simulator — boot the first available iPhone sim
      IOS_SIM_ID="$(xcrun simctl list devices available -j \
        | python3 -c "import sys,json; d=json.load(sys.stdin)['devices']; \
            ids=[dev['udid'] for devs in d.values() for dev in devs if 'iPhone' in dev.get('name','')]; \
            print(ids[0] if ids else '')")"
      [[ -z "$IOS_SIM_ID" ]] && { echo "Error: No iOS simulator found."; exit 1; }
      echo "Booting simulator $IOS_SIM_ID..."
      xcrun simctl boot "$IOS_SIM_ID"
      open -a Simulator
      sleep 3
    fi
    echo "Using simulator: $IOS_SIM_ID"
    ios_clean
    flutter run -d "$IOS_SIM_ID" --dart-define-from-file=firebase.env.json
    ;;
  test:android)
    flutter_clean
    flutter run -d android --dart-define-from-file=firebase.env.json
    ;;
  build:android)
    flutter_clean
    flutter build appbundle --dart-define-from-file=firebase.env.json
    ;;

  build:ios)
    require_macos; require_apple_team_id
    ios_clean
    PLIST="$(make_export_options)"; trap 'rm -f "$PLIST"' EXIT
    flutter build ipa --release --dart-define-from-file=firebase.env.json --export-options-plist="$PLIST"
    ;;

  build-deploy:android)
    flutter_clean
    flutter build appbundle
    echo "AAB built. Submit via Android Studio on Windows."
    ;;

  build-deploy:ios)
    require_macos; require_apple_team_id; require_xcode_cloud_creds
    ios_clean
    PLIST="$(make_export_options)"; trap 'rm -f "$PLIST"' EXIT
    VERSION_LINE=$(grep '^version:' pubspec.yaml | tr -d ' ')
    BUILD_NAME="${VERSION_LINE#version:}"; BUILD_NAME="${BUILD_NAME%+*}"
    CURRENT_BUILD="${VERSION_LINE##*+}"; NEXT_BUILD=$(( CURRENT_BUILD + 1 ))
    sed -i '' "s/^version:.*/version: ${BUILD_NAME}+${NEXT_BUILD}/" pubspec.yaml
    echo "Version: ${BUILD_NAME}  Build: ${CURRENT_BUILD} → ${NEXT_BUILD}"
    flutter build ipa --release \
      --build-name="$BUILD_NAME" --build-number="$NEXT_BUILD" \
      --export-options-plist="$PLIST"
    IPA_PATH="$(find build/ios/ipa -name '*.ipa' | head -1)"
    [[ -z "$IPA_PATH" ]] && { echo "Error: No .ipa found."; exit 1; }
    echo "Uploading '${IPA_PATH}'..."
    xcrun altool --upload-app --type ios --file "$IPA_PATH" \
      --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
    echo "✓ Upload complete. Visit https://appstoreconnect.apple.com"
    ;;

  build:iosc)
    require_macos; require_xcode_cloud_creds
    TOKEN="$(make_asc_token)"
    WORKFLOW_ID="$(find_xcode_cloud_workflow "$TOKEN")"
    RUN_ID="$(trigger_build_run "$TOKEN" "$WORKFLOW_ID")"
    echo "✓ Build triggered. Run ID: ${RUN_ID}"
    echo "  View: https://appstoreconnect.apple.com"
    ;;

  build-deploy:iosc)
    require_macos; require_xcode_cloud_creds
    TOKEN="$(make_asc_token)"
    WORKFLOW_ID="$(find_xcode_cloud_workflow "$TOKEN")"
    RUN_ID="$(trigger_build_run "$TOKEN" "$WORKFLOW_ID")"
    echo "✓ Build triggered. Run ID: ${RUN_ID}"
    poll_build_run "$TOKEN" "$RUN_ID"
    ;;

  help|--help|-h)
    echo ""
    echo "Usage: ./f <command>"
    echo ""
    echo "  setup                  Check tools + install deps"
    echo "  setup:workflow         Generate .github/workflows/ci-cd.yml from .env"
    echo "  dev                    Run app on connected device/emulator"
    echo "  test                   Run unit + widget tests"
    echo "  test:ios               Run on iOS simulator/device"
    echo "  test:android           Run on Android emulator/device"
    echo "  build:android          Build signed AAB"
    echo "  build:ios              Build signed IPA"
    echo "  build:iosc             Trigger Xcode Cloud build"
    echo "  build-deploy:android   Build AAB (submit via Android Studio)"
    echo "  build-deploy:ios       Build IPA and upload to App Store Connect"
    echo "  build-deploy:iosc      Trigger Xcode Cloud build and poll until done"
    echo ""
    echo "Windows users: use f.ps1 instead."
    echo ""
    ;;

  *)
    echo "Unknown command: $COMMAND"
    echo "Run './f help' for a list of available commands."
    exit 1
    ;;
esac
