#!/usr/bin/env bash
# scripts/publish/build-android.sh — build the Android release artifacts.
# One task: build. Nothing else. See README.md for the pipeline.
#
# Layouts supported (auto-detected, override with BUILD_LAYOUT):
#   cargo-apk  — pure-Rust app: [package.metadata.android] in Cargo.toml
#                (e.g. Bevy games). Produces target/release/apk/<slug>.apk
#   gradle     — Rust core + Gradle shell: <dir>/android/gradlew present.
#                Builds .so via cargo-ndk, copies into jniLibs, runs Gradle.
#
# Modes: apk (unsigned release, F-Droid) | aab (Play bundle) | both
# Env (all optional, sane defaults; override as needed):
#   JAVA_HOME, ANDROID_HOME / ANDROID_SDK_ROOT, ANDROID_NDK_HOME / ANDROID_NDK_ROOT / NDK_HOME
#   ANDROID_API_LEVEL (minSdk for the native build; default 26)
#   ANDROID_PROJECT_DIR (gradle layout: dir containing gradlew; auto-found)
#   RUST_CRATE (gradle layout: cargo package name; default: crate dir name)
#   LIB_NAME   (gradle layout: cdylib base name without lib/.so; default: RUST_CRATE with - -> _)
#   CARGO_APK_MANIFEST (cargo-apk layout: path to Cargo.toml; auto-found)
#
# Usage: build-android.sh [apk|aab|both] [--dry-run]
#   --dry-run: validate tools/env and print exactly what would run. Changes nothing.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

MODE="apk"
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        apk|aab|both) MODE="$arg" ;;
        --dry-run) DRY_RUN=1 ;;
        -h|--help)
            awk '/^$/{exit} /^#/{sub(/^# ?/, ""); print}' "$0"
            exit 0 ;;
        *) echo "✗ unknown arg: $arg (use: apk | aab | both | --dry-run)" >&2; exit 2 ;;
    esac
done

run() { if [ "$DRY_RUN" -eq 1 ]; then echo "  [dry-run] $*"; else "$@"; fi; }
step() { echo "→ $*"; }

# --- environment -----------------------------------------------------------
: "${ANDROID_HOME:=${ANDROID_SDK_ROOT:-/opt/android-sdk}}"
export ANDROID_HOME ANDROID_SDK_ROOT="$ANDROID_HOME"
if [ -z "${ANDROID_NDK_HOME:-}" ]; then
    for cand in "${ANDROID_NDK_ROOT:-}" "${NDK_HOME:-}"; do
        [ -n "$cand" ] && [ -d "$cand" ] && ANDROID_NDK_HOME="$cand" && break
    done
fi
if [ -z "${ANDROID_NDK_HOME:-}" ]; then
    ANDROID_NDK_HOME="$(ls -d "$ANDROID_HOME"/ndk/* 2>/dev/null | sort -V | tail -n1 || true)"
fi
export ANDROID_NDK_HOME ANDROID_NDK_ROOT="${ANDROID_NDK_ROOT:-${ANDROID_NDK_HOME:-}}" \
       NDK_HOME="${NDK_HOME:-${ANDROID_NDK_HOME:-}}"
if [ -d /usr/lib/jvm/java-17-openjdk ] && [ -z "${JAVA_HOME:-}" ]; then
    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
    export PATH="$JAVA_HOME/bin:$PATH"
fi
API_LEVEL="${ANDROID_API_LEVEL:-26}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$ROOT/target}"
unset RUSTFLAGS CARGO_BUILD_RUSTFLAGS 2>/dev/null || true

fail() { echo "✗ $*" >&2; exit 1; }

# --- layout detection ------------------------------------------------------
detect_layout() {
    if [ -n "${BUILD_LAYOUT:-}" ]; then echo "$BUILD_LAYOUT"; return; fi
    if [ -n "${CARGO_APK_MANIFEST:-}" ] || grep -rl '^\[package\.metadata\.android\]' \
        --include=Cargo.toml "$ROOT" 2>/dev/null | head -1 | grep -q .; then
        echo "cargo-apk"; return
    fi
    if find "$ROOT" -maxdepth 3 -name gradlew -type f 2>/dev/null | grep -q .; then
        echo "gradle"; return
    fi
    echo "unknown"
}

LAYOUT="$(detect_layout)"
step "build mode: $MODE (layout: $LAYOUT, dry-run: $DRY_RUN)"
step "ANDROID_HOME=$ANDROID_HOME"
step "ANDROID_NDK_HOME=${ANDROID_NDK_HOME:-<unset>}"
step "JAVA_HOME=${JAVA_HOME:-<system default>}"
step "API level (min): $API_LEVEL"

need() { command -v "$1" >/dev/null 2>&1 || fail "$1 not found"; }

case "$LAYOUT" in
cargo-apk)
    need cargo
    MANIFEST="${CARGO_APK_MANIFEST:-$(grep -rl '^\[package\.metadata\.android\]' \
        --include=Cargo.toml "$ROOT" 2>/dev/null | head -1)}"
    [ -n "$MANIFEST" ] || fail "cargo-apk layout but no [package.metadata.android] found"
    command -v cargo-apk >/dev/null 2>&1 || {
        step "cargo-apk missing — would install: cargo install cargo-apk"
        [ "$DRY_RUN" -eq 1 ] || cargo install cargo-apk
    }
    step "cargo apk build --release --manifest-path $MANIFEST"
    run cargo apk build --release --manifest-path "$MANIFEST"
    APK_DIR="$(dirname "$MANIFEST")/target/release/apk"
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  [dry-run] expect APK at: $APK_DIR/*.apk"
    else
        echo "→ APK(s):"; ls -la "$APK_DIR"/*.apk
    fi
    ;;
gradle)
    need cargo; need cargo-ndk; need rustup
    ANDROID_DIR="${ANDROID_PROJECT_DIR:-$(dirname "$(find "$ROOT" -maxdepth 3 -name gradlew -type f 2>/dev/null | head -1)")}"
    [ -n "$ANDROID_DIR" ] && [ -d "$ANDROID_DIR" ] || fail "gradle layout but no gradlew found"
    RUST_CRATE="${RUST_CRATE:-$(basename "$(dirname "$ANDROID_DIR")")}"
    LIB_NAME="${LIB_NAME:-$(echo "$RUST_CRATE" | tr '-' '_')}"
    step "android project: $ANDROID_DIR (crate: $RUST_CRATE, lib: lib${LIB_NAME}.so)"
    for T in aarch64-linux-android armv7-linux-androideabi; do
        if ! rustup target list --installed 2>/dev/null | grep -qx "$T"; then
            step "rustup target add $T"
            run rustup target add "$T"
        fi
    done
    for TRIPLE in aarch64-linux-android armv7-linux-androideabi; do
        step "cargo ndk -t $TRIPLE -p $API_LEVEL build --release -p $RUST_CRATE"
        run cargo ndk --target "$TRIPLE" --platform "$API_LEVEL" \
            -- build --release -p "$RUST_CRATE"
    done
    if [ "$DRY_RUN" -eq 0 ]; then
        NDK_STRIP="$(find "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt" \
            -maxdepth 3 -name llvm-strip -type f 2>/dev/null | head -n1 || true)"
        [ -x "$NDK_STRIP" ] || fail "llvm-strip not found under $ANDROID_NDK_HOME"
        for PAIR in "arm64-v8a:aarch64-linux-android" "armeabi-v7a:armv7-linux-androideabi"; do
            ABI="${PAIR%%:*}"; TRIPLE="${PAIR##*:}"
            SRC="$CARGO_TARGET_DIR/$TRIPLE/release/lib${LIB_NAME}.so"
            DST="$ANDROID_DIR/app/src/main/jniLibs/$ABI"
            [ -f "$SRC" ] || fail "missing $SRC"
            run mkdir -p "$DST"
            step "$ABI: strip $SRC → $DST"
            run "$NDK_STRIP" --strip-unneeded "$SRC" -o "$DST/lib${LIB_NAME}.so"
        done
    else
        echo "  [dry-run] would strip .so files into $ANDROID_DIR/app/src/main/jniLibs/<abi>/"
    fi
    if [ -x "$ANDROID_DIR/gradlew" ]; then GRADLE="$ANDROID_DIR/gradlew";
    elif command -v gradle >/dev/null; then GRADLE=gradle;
    else fail "neither $ANDROID_DIR/gradlew nor system gradle available"; fi
    TASKS=()
    case "$MODE" in
        aab)  TASKS+=(":app:bundleRelease") ;;
        apk)  TASKS+=(":app:assembleRelease") ;;
        both) TASKS+=(":app:bundleRelease" ":app:assembleRelease") ;;
    esac
    step "gradle tasks: ${TASKS[*]} (in $ANDROID_DIR)"
    run bash -c "cd '$ANDROID_DIR' && '$GRADLE' ${TASKS[*]}"
    if [ "$DRY_RUN" -eq 0 ]; then
        [[ $MODE == aab || $MODE == both ]] && { echo "→ AAB:"; ls -la "$ANDROID_DIR/app/build/outputs/bundle/release/"; }
        [[ $MODE == apk || $MODE == both ]] && { echo "→ APK:"; ls -la "$ANDROID_DIR/app/build/outputs/apk/release/"; }
    fi
    ;;
*)
    fail "cannot detect build layout. Set BUILD_LAYOUT=cargo-apk|gradle, or add [package.metadata.android] / gradlew"
    ;;
esac

step "done (mode: $MODE)"
