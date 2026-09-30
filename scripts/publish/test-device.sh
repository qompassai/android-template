#!/usr/bin/env bash
# scripts/publish/test-device.sh — test the app: unit tests, then on-device smoke.
# One task: test. Build first with build-android.sh.
#
# Env (all optional):
#   APP_ID        — Android applicationId (default {{APP_ID}})
#   APK_PATH      — APK to install (auto-found from build outputs)
#   AVD_NAME      — emulator AVD to boot if none is running (default {{SLUG}}-pixel)
#   ANDROID_HOME / ANDROID_SDK_ROOT
#   SKIP_UNIT=1   — skip cargo test (device smoke only)
#   SKIP_DEVICE=1 — skip device smoke (unit tests only)
#
# Usage: test-device.sh [--dry-run]
#   --dry-run: validate tools/env/APK presence and print what would run. Changes nothing.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PUBLISH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help) awk '/^$/{exit} /^#/{sub(/^# ?/, ""); print}' "$0"; exit 0 ;;
        *) echo "✗ unknown arg: $arg" >&2; exit 2 ;;
    esac
done

APP_ID="${APP_ID:-{{APP_ID}}}"
AVD_NAME="${AVD_NAME:-{{SLUG}}-pixel}"
: "${ANDROID_HOME:=${ANDROID_SDK_ROOT:-/opt/android-sdk}}"
export ANDROID_HOME ANDROID_SDK_ROOT="$ANDROID_HOME"
ADB="${ADB_BIN:-$ANDROID_HOME/platform-tools/adb}"
EMULATOR_BIN="${EMULATOR_BIN:-$ANDROID_HOME/emulator/emulator}"

fail() { echo "✗ $*" >&2; exit 1; }
step() { echo "→ $*"; }
run() { if [ "$DRY_RUN" -eq 1 ]; then echo "  [dry-run] $*"; else "$@"; fi; }

find_apk() {
    if [ -n "${APK_PATH:-}" ]; then echo "$APK_PATH"; return; fi
    find "$ROOT" -path '*/build/outputs/apk/release/*.apk' -o \
                 -path '*/target/release/apk/*.apk' 2>/dev/null \
        | grep -v -- '-unsigned' | head -1
}

echo "→ test-device (dry-run: $DRY_RUN, app: $APP_ID)"

if [ "${SKIP_UNIT:-0}" != "1" ]; then
    step "cargo test --workspace"
    if [ "$DRY_RUN" -eq 1 ]; then
        command -v cargo >/dev/null || fail "cargo not found"
        echo "  [dry-run] cargo test --workspace"
    else
        (cd "$ROOT" && cargo test --workspace)
    fi
else
    step "SKIP_UNIT=1 — skipping cargo tests"
fi

if [ "${SKIP_DEVICE:-0}" != "1" ]; then
    [ -x "$ADB" ] || fail "adb not found at $ADB"
    APK="$(find_apk)"
    [ -n "$APK" ] && [ -f "$APK" ] || fail "no APK found — run build-android.sh apk first"
    step "APK: $APK"

    # Boot an emulator if no device is attached.
    if ! "$ADB" devices 2>/dev/null | grep -q $'\tdevice$'; then
        step "no device attached — booting emulator ($AVD_NAME)"
        [ -x "$EMULATOR_BIN" ] || fail "emulator not found at $EMULATOR_BIN"
        run bash -c "nohup '$EMULATOR_BIN' -avd '$AVD_NAME' -no-window -no-audio -gpu swiftshader_indirect > /tmp/${AVD_NAME}.log 2>&1 &"
        step "waiting for boot (log: /tmp/${AVD_NAME}.log)"
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "  [dry-run] adb wait-for-device + sys.boot_completed poll"
        else
            "$ADB" wait-for-device
            until "$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' | grep -qx '1'; do sleep 2; done
            step "emulator booted"
        fi
    else
        step "device already attached"
    fi

    step "install -r $APK"
    run "$ADB" install -r "$APK"
    step "launch $APP_ID"
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  [dry-run] adb shell monkey -p $APP_ID -c android.intent.category.LAUNCHER 1"
        echo "  [dry-run] then: manually exercise the app, check logcat for crashes"
    else
        "$ADB" shell monkey -p "$APP_ID" -c android.intent.category.LAUNCHER 1 >/dev/null
        echo "  app launched — exercise it now, then check for crashes:"
        echo "    $ADB logcat | grep -i -E 'fatal|crash|exception'"
    fi
else
    step "SKIP_DEVICE=1 — skipping on-device smoke test"
fi

echo "→ done"
