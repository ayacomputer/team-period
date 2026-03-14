# teamPeriod

A shared period tracker for couples — real-time sync via Firebase Firestore.
カップル向け生理トラッカー — Firebase Firestore でリアルタイム同期。

---

## Android 開発者向けクイックスタート / Android Developer Quick Start

> **日本語 / Japanese**

### なぜ `firebase.env.json` が必要か

このプロジェクトは Firebase のシークレット（API キー、App ID など）を
ソースコードにハードコードせず、ビルド時に `--dart-define-from-file` で注入しています。
これにより `.gitignore` に登録された `firebase.env.json` だけが秘密情報を保持し、
リポジトリに誤ってコミットされるリスクをなくしています。

`./f` スクリプトのすべての実行コマンド（`dev`・`test:android`・`build:android`）は
自動的に `--dart-define-from-file=firebase.env.json` を渡すため、
**一度ファイルを作成すれば以降は意識する必要はありません。**

### セットアップ手順（Android）

```bash
# 1. 環境変数ファイルをコピーして実際の値を入力
cp .env.example .env
# .env を編集して FIREBASE_ANDROID_* などを埋める

# 2. Firebase シークレットを JSON 形式に変換（初回のみ）
python3 -c "
import re, json
env = {}
with open('.env') as f:
    for line in f:
        m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)=(.*)$', line.strip())
        if m:
            env[m.group(1)] = m.group(2)
keys = [
    'FIREBASE_ANDROID_API_KEY', 'FIREBASE_ANDROID_APP_ID',
    'FIREBASE_IOS_API_KEY',     'FIREBASE_IOS_APP_ID',
    'FIREBASE_MESSAGING_SENDER_ID', 'FIREBASE_PROJECT_ID',
    'FIREBASE_STORAGE_BUCKET',  'FIREBASE_IOS_BUNDLE_ID',
]
with open('firebase.env.json', 'w') as f:
    json.dump({k: env[k] for k in keys if k in env}, f, indent=2)
print('firebase.env.json written')
"

# 3. Android エミュレーターまたは実機で起動
./f test:android

# 4. リリースビルド（AAB）
./f build:android
```

---

> **English**

### Why `firebase.env.json` is required

Firebase secrets (API keys, App IDs, etc.) are **not** hardcoded in source.
They are injected at build time via Flutter's `--dart-define-from-file` flag,
keeping them out of the repository. `firebase.env.json` is git-ignored and
must be generated locally from your `.env` file before first run.

All `./f` commands (`dev`, `test:android`, `build:android`) automatically
pass `--dart-define-from-file=firebase.env.json` — **you only need to
create the file once.**

### Setup steps (Android)

```bash
# 1. Copy the example env file and fill in real values
cp .env.example .env
# Edit .env — fill in FIREBASE_ANDROID_* and other keys

# 2. Generate firebase.env.json from .env (first time only)
python3 -c "
import re, json
env = {}
with open('.env') as f:
    for line in f:
        m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)=(.*)$', line.strip())
        if m:
            env[m.group(1)] = m.group(2)
keys = [
    'FIREBASE_ANDROID_API_KEY', 'FIREBASE_ANDROID_APP_ID',
    'FIREBASE_IOS_API_KEY',     'FIREBASE_IOS_APP_ID',
    'FIREBASE_MESSAGING_SENDER_ID', 'FIREBASE_PROJECT_ID',
    'FIREBASE_STORAGE_BUCKET',  'FIREBASE_IOS_BUNDLE_ID',
]
with open('firebase.env.json', 'w') as f:
    json.dump({k: env[k] for k in keys if k in env}, f, indent=2)
print('firebase.env.json written')
"

# 3. Run on Android emulator or physical device
./f test:android

# 4. Release build (AAB)
./f build:android
```

---

## iOS Quick Start

```bash
# Run on simulator (boots first available)
./f test:ios

# Release build (requires Xcode + APPLE_TEAM_ID in .env)
./f build:ios
```

---

## Available `./f` Commands

| Command | Description |
|---------|-------------|
| `./f dev` | Run on connected device (auto-selects) |
| `./f test` | Run unit + widget tests |
| `./f test:ios` | Run debug build on iOS simulator/device |
| `./f test:android` | Run debug build on Android emulator/device |
| `./f build:android` | Build signed AAB for Play Store |
| `./f build:ios` | Build signed IPA for App Store |
| `./f build-deploy:ios` | Build IPA + upload to App Store Connect |
| `./f setup:workflow` | Generate CI/CD workflow from `.env` |

---

## Project Structure

```
lib/
  main.dart                    # App entry, Firebase init, ThemeData
  models/
    cycle_settings.dart        # CycleSettings (lengths, partner name, notifications)
    cycle_summary.dart         # CycleSummary + CyclePhase enum
    mood_entry.dart            # MoodEntry, Mood enum, condition options
    period_log.dart            # PeriodLog (start/end dates, moods)
  screens/
    home_screen.dart           # Root screen — wires all widgets + Firestore streams
  services/
    couple_id_service.dart     # UUID-based couple ID stored in SharedPreferences
    firestore_service.dart     # Firestore reads/writes at /couples/{id}
    notification_service.dart  # Local push notifications via flutter_local_notifications
  utils/
    cycle_calculations.dart    # Pure functions: phase, next period, ovulation, averages
    kindness_reminders.dart    # Phase-aware daily tip rotation for partner
    phase_theme.dart           # Phase → Color mapping
  widgets/
    cycle_calendar_card.dart   # Hero card: phase badge, countdown, progress bar, date pills
    cycle_history_list.dart    # Sorted list of past cycles with mood chips + delete
    empty_state.dart           # Generic empty state placeholder
    kindness_card.dart         # Phase-aware tips card shown to the partner
    period_logger_card.dart    # Period start/end buttons + mood/condition logger
    settings_panel.dart        # Bottom sheet: lengths, notifications, Couple ID share
```

---

## How Partner Syncing Works

1. Person A opens the app → a **Couple ID** (UUID) is generated and stored locally.
2. Person A shares the Couple ID via Settings → **Copy** → iMessage / WhatsApp / etc.
3. Person B opens the app → Settings → **"Enter partner's ID"** → pastes the ID.
4. Both apps now read and write the **same Firestore document** (`/couples/{coupleId}`).
5. Changes appear in real time on both devices.

---

## Environment Variables (`.env`)

| Variable | Purpose |
|----------|---------|
| `FIREBASE_ANDROID_API_KEY` | Firebase Android API key |
| `FIREBASE_ANDROID_APP_ID` | Firebase Android App ID |
| `FIREBASE_IOS_API_KEY` | Firebase iOS API key |
| `FIREBASE_IOS_APP_ID` | Firebase iOS App ID |
| `FIREBASE_MESSAGING_SENDER_ID` | Firebase Cloud Messaging sender ID |
| `FIREBASE_PROJECT_ID` | Firebase project ID |
| `FIREBASE_STORAGE_BUCKET` | Firebase Storage bucket |
| `FIREBASE_IOS_BUNDLE_ID` | iOS bundle identifier |
| `APPLE_TEAM_ID` | Apple Developer Team ID (iOS builds only) |
| `ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_PRIVATE_KEY_PATH` | App Store Connect API (deploy only) |
