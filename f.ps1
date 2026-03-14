# ─────────────────────────────────────────────────────────────────────────────
#  f.ps1  —  Flutter + mobile-cicd task runner (Windows)
#
#  Platform split:
#    Windows (this script)  →  Android build + deploy, dev, test
#    Mac (f)                →  iOS build + deploy, Android build, dev, test
#
#  Usage (from your Flutter project root in PowerShell):
#    .\f.ps1 setup:workflow   # generate .github/workflows/ci-cd.yml from .env
#    .\f.ps1 dev              # run app on connected device/emulator
#    .\f.ps1 test             # run unit + widget tests
#    .\f.ps1 build:android    # build signed AAB
#
#  If script execution is blocked, run once:
#    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
#
#  Mac users: use f instead.
# ─────────────────────────────────────────────────────────────────────────────

param(
    [Parameter(Position = 0)]
    [string]$Command = "help"
)

$ErrorActionPreference = "Stop"

# ── Helpers ───────────────────────────────────────────────────────────────────

function Invoke-SetupScript {
    param([string]$ScriptUrl, [string]$Label)

    Write-Host "Running $Label..." -ForegroundColor Cyan

    # Prefer native bash (Git for Windows / MSYS2), fall back to WSL
    $bashExe = Get-Command "bash" -ErrorAction SilentlyContinue
    $wslExe  = Get-Command "wsl"  -ErrorAction SilentlyContinue

    if ($bashExe) {
        & bash -c "curl -fsSL $ScriptUrl | bash"
    } elseif ($wslExe) {
        & wsl bash -c "curl -fsSL $ScriptUrl | bash"
    } else {
        Write-Error "bash not found. Install Git for Windows (https://git-scm.com) or WSL (https://aka.ms/wsl) and re-run."
        exit 1
    }
}

function Invoke-NativeSetupWorkflow {
    # Native PowerShell implementation — no bash required.
    # Reads .env, validates required vars, and writes .github/workflows/ci-cd.yml.

    $envFile = Join-Path (Get-Location) ".env"
    if (-not (Test-Path $envFile)) {
        Write-Error ".env not found. Copy .env.example to .env and fill in your values. Then re-run: .\f.ps1 setup:workflow"
        exit 1
    }

    # Parse .env (skip comments and blank lines)
    $envVars = @{}
    Get-Content $envFile | Where-Object { $_ -match "^[A-Za-z_][A-Za-z0-9_]*=" } | ForEach-Object {
        $key, $value = $_ -split "=", 2
        $envVars[$key.Trim()] = $value.Trim()
    }

    $appName        = $envVars["APP_NAME"]
    $flutterVersion = $envVars["FLUTTER_VERSION"]

    $errors = @()
    if (-not $appName) { $errors += "APP_NAME is not set (lowercase app slug, e.g. my-app)" }
    if ($errors.Count -gt 0) {
        Write-Host "Missing required .env values:" -ForegroundColor Red
        $errors | ForEach-Object { Write-Host "  x $_" -ForegroundColor Red }
        Write-Error "Fill in the missing values in .env and re-run."
        exit 1
    }

    $workflowDir  = Join-Path (Get-Location) ".github\workflows"
    $workflowFile = Join-Path $workflowDir "ci-cd.yml"
    New-Item -ItemType Directory -Force -Path $workflowDir | Out-Null

    if (Test-Path $workflowFile) {
        $reply = Read-Host "ci-cd.yml already exists. Overwrite? (y/N)"
        if ($reply -notmatch "^[Yy]$") {
            Write-Host "Skipped — existing file kept." -ForegroundColor Yellow
            return
        }
    }

    $flutterVersionLine = if ($flutterVersion) { "`n      flutter-version: $flutterVersion" } else { "" }

    $yaml = @"
# ─────────────────────────────────────────────────────────────────────────────
# CI/CD — $appName
#
# PIPELINES:
#   Pull request -> flutter analyze + flutter test
#   git tag v*.*.* -> Full Android (AAB) + iOS (IPA) build as artifacts
#
# SECRETS required (Settings -> Secrets and variables -> Actions):
#   APPLE_TEAM_ID              — 10-character Apple Developer Team ID
#   ANDROID_KEYSTORE_BASE64    — base64 of your .jks keystore
#   ANDROID_KEYSTORE_ALIAS     — alias used when generating keystore
#   ANDROID_KEYSTORE_PASSWORD  — keystore password
#   ANDROID_KEY_PASSWORD       — key password
# ─────────────────────────────────────────────────────────────────────────────

name: CI/CD

on:
  push:
    tags: ['v*.*.*']
  pull_request:
    branches: [main]

concurrency:
  group: `${{ github.workflow }}-`${{ github.event.pull_request.head.ref || github.ref }}
  cancel-in-progress: `${{ !startsWith(github.ref, 'refs/tags/') }}

jobs:
  release:
    uses: ayacomputer/mobile-cicd/.github/workflows/release-flutter.yml@main
    with:
      app-name: $appName
      export-options-plist: .github/ios/ExportOptions.plist$flutterVersionLine
    secrets:
      apple-team-id: `${{ secrets.APPLE_TEAM_ID }}
      keystore-base64: `${{ secrets.ANDROID_KEYSTORE_BASE64 }}
      keystore-alias: `${{ secrets.ANDROID_KEYSTORE_ALIAS }}
      keystore-password: `${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
      key-password: `${{ secrets.ANDROID_KEY_PASSWORD }}
"@

    Set-Content -Path $workflowFile -Value $yaml -Encoding UTF8

    Write-Host ""
    Write-Host "Workflow generated!" -ForegroundColor Green
    Write-Host "  Created: .github/workflows/ci-cd.yml" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  1. Add GitHub Secrets to your repo:"
    Write-Host "     https://github.com/$appName -> Settings -> Secrets and variables -> Actions"
    Write-Host "     * APPLE_TEAM_ID"
    Write-Host "     * ANDROID_KEYSTORE_BASE64"
    Write-Host "     * ANDROID_KEYSTORE_ALIAS"
    Write-Host "     * ANDROID_KEYSTORE_PASSWORD"
    Write-Host "     * ANDROID_KEY_PASSWORD"
    Write-Host ""
    Write-Host "  2. Push to trigger your first pipeline:"
    Write-Host "     git add .github/workflows/ci-cd.yml"
    Write-Host "     git commit -m 'ci: add CI/CD workflow'"
    Write-Host "     git push origin main"
    Write-Host ""
}

function Find-AndroidStudio {
    $candidates = @(
        "$env:LOCALAPPDATA\Google\AndroidStudio*\bin\studio64.exe",
        "$env:PROGRAMFILES\Android\Android Studio\bin\studio64.exe",
        "$env:PROGRAMFILES(x86)\Android\Android Studio\bin\studio64.exe"
    )
    $match = $candidates |
        ForEach-Object { Get-Item $_ -ErrorAction SilentlyContinue } |
        Select-Object -First 1

    return if ($match) { $match.FullName } else { $null }
}

# ── Commands ──────────────────────────────────────────────────────────────────

switch ($Command) {

    "setup:workflow" {
        Invoke-NativeSetupWorkflow
    }

    "setup" {
        Invoke-SetupScript `
            -ScriptUrl "https://raw.githubusercontent.com/ayacomputer/mobile-cicd/main/scripts/setup-flutter.sh" `
            -Label "setup-flutter.sh"
    }

    "dev" {
        flutter run
    }

    "test" {
        flutter test
    }

    "test:ios" {
        Write-Error "iOS simulators are not available on Windows. Run './f test:ios' on a Mac."
        exit 1
    }

    "test:android" {
        flutter run -d android
    }

    "build:android" {
        flutter build appbundle
    }

    "build:ios" {
        Write-Error "iOS builds require macOS with Xcode. Run './f build:ios' on a Mac."
        exit 1
    }

    "build:iosc" {
        Write-Error "Xcode Cloud builds require macOS. Run './f build:iosc' on a Mac."
        exit 1
    }

    "build-deploy:android" {
        flutter build appbundle

        $studioExe = Find-AndroidStudio
        if ($studioExe) {
            Start-Process $studioExe -ArgumentList (Resolve-Path "android").Path
        } else {
            Write-Host "Build complete. Open the 'android' folder in Android Studio to submit to the Play Store." -ForegroundColor Yellow
        }
    }

    "build-deploy:ios" {
        Write-Error "iOS deploy requires macOS with Xcode. Run './f build-deploy:ios' on a Mac."
        exit 1
    }

    "build-deploy:iosc" {
        Write-Error "Xcode Cloud deploy requires macOS. Run './f build-deploy:iosc' on a Mac."
        exit 1
    }

    { $_ -in "help", "--help", "-h", "" } {
        Write-Host ""
        Write-Host "Usage: .\f.ps1 <command>"
        Write-Host ""
        Write-Host "Commands (Windows):"
        Write-Host "  setup:workflow         Generate .github/workflows/ci-cd.yml from .env (no bash needed)"
        Write-Host "  setup                  Check tools + install deps (requires Git Bash or WSL)"
        Write-Host "  dev                    Run app on connected device/emulator"
        Write-Host "  test                   Run unit + widget tests"
        Write-Host "  test:android           Run on Android emulator/device"
        Write-Host "  build:android          Build signed AAB"
        Write-Host "  build-deploy:android   Build AAB then open Android Studio to submit"
        Write-Host ""
        Write-Host "Mac-only commands (run on Mac with ./f):"
        Write-Host "  test:ios               Run on iOS simulator/device"
        Write-Host "  build:ios              Build signed IPA (requires Xcode + APPLE_TEAM_ID in .env)"
        Write-Host "  build:iosc             Trigger Xcode Cloud build"
        Write-Host "  build-deploy:ios       Build IPA and upload to App Store Connect"
        Write-Host "  build-deploy:iosc      Trigger Xcode Cloud build and poll until done"
        Write-Host ""
        Write-Host "Mac users: use ./f instead."
        Write-Host ""
    }

    default {
        Write-Error "Unknown command: $Command. Run '.\f.ps1 help' for available commands."
        exit 1
    }
}
