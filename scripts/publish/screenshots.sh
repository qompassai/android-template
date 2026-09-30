#!/usr/bin/env bash
# scripts/publish/screenshots.sh — capture real store screenshots on an emulator.
# One task: screenshots. Full pipeline: boot headless emulator (KVM) → install →
# launch → screencap N shots into fastlane/.../images/phoneScreenshots/ → kill emulator.
#
# Env (all optional):
#   APP_ID         — Android applicationId (default {{APP_ID}})
#   APK_PATH       — APK to install (auto-found from build outputs)
#   AVD_NAME       — emulator AVD (default {{SLUG}}-pixel)
#   SHOT_COUNT     — how many screenshots (default 2; Play needs ≥2, recommends 4–8)
#   SHOT_DIR       — output dir (default fastlane/metadata/android/en-US/images/phoneScreenshots)
#   ANDROID_HOME / ANDROID_SDK_ROOT
#   NO_KILL=1      — leave the emulator running when done
#
# Usage: screenshots.sh [count] [--dry-run]
#   --dry-run: validate tools/AVD/APK and print the pipeline. Boots nothing.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

DRY_RUN=0
COUNT=""
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help) awk '/^$/{exit} /^#/{sub(/^# ?/, ""); print}' "$0"; exit 0 ;;
        [0-9]*) COUNT="$arg" ;;
        *) echo "✗ unknown arg: $arg" >&2; exit 2 ;;
    esac
done

APP_ID="${APP_ID:-{{APP_ID}}}"
AVD_NAME="${AVD_NAME:-{{SLUG}}-pixel}"
SHOT_COUNT="${SHOT_COUNT:-${COUNT:-2}}"
SHOT_DIR="${SHOT_DIR:-$ROOT/fastlane/metadata/android/en-US/images/phoneScreenshots}"
: "${ANDROID_HOME:=${ANDROID_SDK_ROOT:-/opt/android-sdk}}"
export ANDROID_HOME ANDROID_SDK_ROOT="$ANDROID_HOME"
ADB="${ADB_BIN:-$ANDROID_HOME/platform-tools/adb}"
EMULATOR_BIN="${EMULATOR_BIN:-$ANDROID_HOME/emulator/emulator}"

fail() { echo "✗ $*" >&2; exit 1; }
step() { echo "→ $*"; }
run() { if [ "$DRY_RUN" -eq 1 ]; then echo "  [dry-run] $*"; else "$@"; fi; }

[ -x "$ADB" ] || fail "adb not found at $ADB"
[ -x "$EMULATOR_BIN" ] || fail "emulator not found at $EMULATOR_BIN"
[ -c /dev/kvm ] || echo "⚠ /dev/kvm missing — emulator will be slow (no hardware accel)"

APK="${APK_PATH:-$(find "$ROOT" -path '*/build/outputs/apk/release/*.apk' -o \
    -path '*/target/release/apk/*.apk' 2>/dev/null | grep -v -- '-unsigned' | head -1)}"
[ -n "$APK" ] && [ -f "$APK" ] || fail "no APK found — run build-android.sh apk first"
"$EMULATOR_BIN" -list-avds 2>/dev/null | grep -qx "$AVD_NAME" \
    || fail "AVD '$AVD_NAME' not found. Create it: avdmanager create avd -n $AVD_NAME -k \"system-images;android-36;google_apis;x86_64\" -d pixel"

step "screenshots: $SHOT_COUNT shot(s) → $SHOT_DIR (dry-run: $DRY_RUN)"
run mkdir -p "$SHOT_DIR"

BOOTED_BY_US=0
if ! "$ADB" devices 2>/dev/null | grep -q $'\tdevice$'; then
    step "booting emulator ($AVD_NAME) headless"
    run bash -c "nohup '$EMULATOR_BIN' -avd '$AVD_NAME' -no-window -no-audio -gpu swiftshader_indirect > /tmp/${AVD_NAME}.log 2>&1 &"
    BOOTED_BY_US=1
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  [dry-run] adb wait-for-device + poll sys.boot_completed"
    else
        "$ADB" wait-for-device
        until "$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' | grep -qx '1'; do sleep 2; done
        step "emulator booted"
    fi
else
    step "using already-attached device"
fi

step "install -r $APK"
run "$ADB" install -r "$APK"
step "launch $APP_ID"
if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] adb shell monkey -p $APP_ID -c android.intent.category.LAUNCHER 1"
else
    "$ADB" shell monkey -p "$APP_ID" -c android.intent.category.LAUNCHER 1 >/dev/null
fi

i=1
while [ "$i" -le "$SHOT_COUNT" ]; do
    OUT="$SHOT_DIR/$i.png"
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  [dry-run] adb exec-out screencap -p > $OUT"
    else
        if [ "$i" -gt 1 ]; then
            echo "→ navigate to the next screen in the app, then press Enter"
            read -r _
        else
            echo "→ navigate to the first screen you want captured, then press Enter"
            read -r _
        fi
        "$ADB" exec-out screencap -p > "$OUT"
        step "saved $OUT ($(stat -c%s "$OUT") bytes)"
    fi
    i=$((i + 1))
done

if [ "$BOOTED_BY_US" -eq 1 ] && [ "${NO_KILL:-0}" != "1" ]; then
    step "stopping emulator"
    run "$ADB" emu kill || true
fi

echo "→ done: $SHOT_COUNT screenshot(s) in $SHOT_DIR"
echo "  F-Droid wants them at fastlane/metadata/android/en-US/images/phoneScreenshots/"
echo "  Play wants ≥2 (recommends 4–8); copy/symlink as needed."
