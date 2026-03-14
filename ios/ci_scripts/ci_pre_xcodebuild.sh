#!/bin/bash
# ci_pre_xcodebuild.sh — Xcode Cloud pre-build hook
#
# Runs App Store compliance checks before Xcode begins the archive.
# Any failing check prints a [FAIL] line and sets FAIL=1.
# The script exits with that status, causing Xcode Cloud to abort the build
# and surface the violation in the build log.
#
# Checks:
#   1. ios/Runner/PrivacyInfo.xcprivacy exists
#   2. No hardcoded secrets (AWS keys, Stripe live keys, Google API keys) in lib/
#   3. NSPrivacyTracking is explicitly false in PrivacyInfo.xcprivacy
#   4. No NS*UsageDescription key in Info.plist has an empty string value
#   5. ITSAppUsesNonExemptEncryption is declared in Info.plist
#   6. No unreplaced skeleton placeholders (__APP_TITLE__, __PACKAGE_SLUG__) in Info.plist
#   7. android/key.properties exists (required for signed Android release builds)

set -e

# Xcode Cloud cd's into ci_scripts/ before running this script.
# Walk up two levels to reach the repository root.
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

FAIL=0
PRIVACY_MANIFEST="${REPO_ROOT}/ios/Runner/PrivacyInfo.xcprivacy"
INFO_PLIST="${REPO_ROOT}/ios/Runner/Info.plist"
LIB_DIR="${REPO_ROOT}/lib"

echo "=== App Store Compliance Checks ==="

# ---------------------------------------------------------------------------
# Check 1: Privacy manifest must be present
#   Apple requires an app-level PrivacyInfo.xcprivacy for all new app
#   submissions and updates since Spring 2024.
# ---------------------------------------------------------------------------
if [ ! -f "${PRIVACY_MANIFEST}" ]; then
    echo "[FAIL] Missing ${PRIVACY_MANIFEST} — required for App Store submission"
    FAIL=1
else
    echo "[PASS] PrivacyInfo.xcprivacy found"
fi

# ---------------------------------------------------------------------------
# Check 2: No hardcoded secrets in Dart source
#   Scans lib/ for patterns that look like real credentials:
#     AKIA...  — AWS access key ID
#     sk_live_ — Stripe secret live key
#     AIza...  — Google/Firebase API key
#   CI should inject secrets via environment variables, not source code.
# ---------------------------------------------------------------------------
SECRET_PATTERN="(AKIA[0-9A-Z]{16}|sk_live_[0-9a-zA-Z]{24,}|AIza[0-9A-Za-z_-]{35})"
if grep -rE "${SECRET_PATTERN}" "${LIB_DIR}/" 2>/dev/null; then
    echo "[FAIL] Potential hardcoded secret found in lib/ — use environment variables instead"
    FAIL=1
else
    echo "[PASS] No hardcoded secrets detected in lib/"
fi

# ---------------------------------------------------------------------------
# Check 3: NSPrivacyTracking must be false
#   If the app does not use IDFA or link user data across apps/sites, this
#   key must be false. A missing or true value triggers App Store Review
#   rejection and may violate ATT requirements.
# ---------------------------------------------------------------------------
if [ -f "${PRIVACY_MANIFEST}" ]; then
    TRACKING=$(plutil -extract NSPrivacyTracking raw "${PRIVACY_MANIFEST}" 2>/dev/null || echo "missing")
    if [ "${TRACKING}" != "false" ]; then
        echo "[FAIL] NSPrivacyTracking is '${TRACKING}' in ${PRIVACY_MANIFEST} — must be 'false'"
        FAIL=1
    else
        echo "[PASS] NSPrivacyTracking=false"
    fi
fi

# ---------------------------------------------------------------------------
# Check 4: No NS*UsageDescription key may have an empty value
#   Xcode will build successfully with empty strings, but App Store Review
#   will reject the binary. Catch this early.
# ---------------------------------------------------------------------------
if [ -f "${INFO_PLIST}" ]; then
    # plutil -p prints key/value pairs; grep for UsageDescription lines with ""
    EMPTY_DESCRIPTIONS=$(plutil -p "${INFO_PLIST}" | grep "UsageDescription" | grep '""' || true)
    if [ -n "${EMPTY_DESCRIPTIONS}" ]; then
        echo "[FAIL] Empty NSUsageDescription value(s) found in ${INFO_PLIST}:"
        echo "${EMPTY_DESCRIPTIONS}"
        FAIL=1
    else
        echo "[PASS] All usage descriptions are non-empty"
    fi
else
    echo "[WARN] ${INFO_PLIST} not found — skipping usage description check"
fi

# ---------------------------------------------------------------------------
# Check 5: ITSAppUsesNonExemptEncryption must be declared in Info.plist
#   Apple requires every app to declare its encryption usage on every
#   submission. Setting this key in Info.plist bypasses the App Store Connect
#   questionnaire. A missing key causes a submission error or review delay.
#   Acceptable values:
#     false — app uses only Apple OS encryption (HTTPS/TLS). Most apps.
#     true  — app implements additional/custom cryptography; ERN docs required.
# ---------------------------------------------------------------------------
if [ -f "${INFO_PLIST}" ]; then
    if plutil -extract ITSAppUsesNonExemptEncryption raw "${INFO_PLIST}" 2>/dev/null | grep -qE "^(true|false)$"; then
        ITS_VALUE=$(plutil -extract ITSAppUsesNonExemptEncryption raw "${INFO_PLIST}")
        echo "[PASS] ITSAppUsesNonExemptEncryption=${ITS_VALUE}"
    else
        echo "[FAIL] ITSAppUsesNonExemptEncryption is missing from ${INFO_PLIST}"
        echo "       Add '<key>ITSAppUsesNonExemptEncryption</key><false/>' for standard HTTPS-only apps."
        FAIL=1
    fi
else
    echo "[WARN] ${INFO_PLIST} not found — skipping encryption declaration check"
fi

# ---------------------------------------------------------------------------
# Check 6: No unreplaced skeleton placeholders in Info.plist
#   The skeleton uses __APP_TITLE__ and __PACKAGE_SLUG__ as stand-ins.
#   If they survive into a CI build it means the project was not initialised
#   correctly — the app would appear as "__APP_TITLE__" on device.
# ---------------------------------------------------------------------------
if [ -f "${INFO_PLIST}" ]; then
    if grep -q "__APP_TITLE__\|__PACKAGE_SLUG__" "${INFO_PLIST}"; then
        echo "[FAIL] Unreplaced skeleton placeholder found in ${INFO_PLIST}"
        echo "       Replace __APP_TITLE__ and __PACKAGE_SLUG__ with real values."
        FAIL=1
    else
        echo "[PASS] No skeleton placeholders in Info.plist"
    fi
fi

# ---------------------------------------------------------------------------
# Check 7: android/key.properties must exist for signed release builds
#   ci_post_clone.sh writes this file from Xcode Cloud environment variables.
#   A missing file means release signing will fall back to the debug keystore,
#   producing a build that cannot be submitted to the Play Store.
# ---------------------------------------------------------------------------
KEY_PROPERTIES="${REPO_ROOT}/android/key.properties"
if [ -f "${KEY_PROPERTIES}" ]; then
    echo "[PASS] android/key.properties found"
else
    echo "[FAIL] android/key.properties is missing"
    echo "       Set ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_ALIAS,"
    echo "       ANDROID_KEYSTORE_PASSWORD, and ANDROID_KEY_PASSWORD as Secret"
    echo "       environment variables in the Xcode Cloud workflow."
    FAIL=1
fi

echo "==================================="

exit "${FAIL}"
