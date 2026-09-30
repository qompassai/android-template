#!/usr/bin/env bash
# scripts/publish/tbr-keystore.sh — create the Play upload keystore. [TBR]
#
# TBR = to-be-reviewed: a human-gated task. Only a human runs this for real;
# agents may only run it with --dry-run. The keystore and its passwords are
# NEVER committed — lose the keystore and you can never update the listing again.
#
# Real run: prompts for passwords (no echo), creates ~/.android/<slug>-upload.jks
#   (RSA 4096, 10000 days), appends the credential properties to
#   ~/.gradle/gradle.properties (outside the repo).
# --dry-run: validates the keytool command end-to-end with a THROWAWAY keystore
#   in /tmp (throwaway alias), then deletes it. The real keystore is untouched.
#
# Env (optional): SLUG (default {{SLUG}}), KEYSTORE_DIR (default ~/.android)
set -euo pipefail

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help) awk '/^$/{exit} /^#/{sub(/^# ?/, ""); print}' "$0"; exit 0 ;;
        *) echo "✗ unknown arg: $arg" >&2; exit 2 ;;
    esac
done

SLUG="${SLUG:-{{SLUG}}}"
ALIAS="${SLUG}-upload"
KEYSTORE_DIR="${KEYSTORE_DIR:-$HOME/.android}"
KEYSTORE="$KEYSTORE_DIR/${SLUG}-upload.jks"
KEYTOOL="${KEYTOOL:-/usr/lib/jvm/java-17-openjdk/bin/keytool}"
[ -x "$KEYTOOL" ] || KEYTOOL="$(command -v keytool || true)"
[ -n "$KEYTOOL" ] || { echo "✗ keytool not found" >&2; exit 1; }

echo "→ tbr-keystore (dry-run: $DRY_RUN, keytool: $KEYTOOL)"

if [ "$DRY_RUN" -eq 1 ]; then
    # Prove the exact command line works, with a throwaway artifact.
    TMP_KS="$(mktemp /tmp/tbr-keystore-dryrun-XXXXXX.jks)"
    rm -f "$TMP_KS"
    echo "→ generating throwaway keystore: $TMP_KS"
    "$KEYTOOL" -genkey -v \
        -keystore "$TMP_KS" \
        -alias "dryrun-throwaway" \
        -keyalg RSA -keysize 4096 -validity 10000 \
        -storepass "dryrun-only" -keypass "dryrun-only" \
        -dname "CN=dryrun, OU=dryrun, O=dryrun, L=dryrun, S=dryrun, C=US" \
        >/dev/null 2>&1
    echo "→ verifying throwaway keystore"
    "$KEYTOOL" -list -v -keystore "$TMP_KS" -storepass "dryrun-only" \
        | grep -E "Alias name|Valid from" | head -4
    rm -f "$TMP_KS"
    echo "→ throwaway deleted. Dry-run PASS."
    echo "  Real run would create: $KEYSTORE (alias: $ALIAS)"
    echo "  and append ${SLUG^^}_KEYSTORE* properties to ~/.gradle/gradle.properties"
    exit 0
fi

# --- real run (human only) ---------------------------------------------------
if [ -t 0 ]; then :; else echo "✗ real run needs an interactive terminal" >&2; exit 1; fi
[ -f "$KEYSTORE" ] && { echo "✗ $KEYSTORE already exists — refusing to overwrite" >&2; exit 1; }

read -rsp "Keystore password: " STOREPASS; echo
read -rsp "Key password:      " KEYPASS; echo
[ -n "$STOREPASS" ] && [ -n "$KEYPASS" ] || { echo "✗ passwords cannot be empty" >&2; exit 1; }

mkdir -p "$KEYSTORE_DIR"
"$KEYTOOL" -genkey -v \
    -keystore "$KEYSTORE" \
    -alias "$ALIAS" \
    -keyalg RSA -keysize 4096 -validity 10000 \
    -storepass "$STOREPASS" -keypass "$KEYPASS"

PREFIX="$(echo "$SLUG" | tr 'a-z-' 'A-Z_')"
mkdir -p ~/.gradle
touch ~/.gradle/gradle.properties
chmod 600 ~/.gradle/gradle.properties
if grep -q "^${PREFIX}_KEYSTORE=" ~/.gradle/gradle.properties 2>/dev/null; then
    echo "⚠ ${PREFIX}_KEYSTORE already in ~/.gradle/gradle.properties — not duplicating"
else
    cat >> ~/.gradle/gradle.properties <<EOF

${PREFIX}_KEYSTORE=$KEYSTORE
${PREFIX}_KEY_ALIAS=$ALIAS
${PREFIX}_KEYSTORE_PASS=$STOREPASS
${PREFIX}_KEY_PASS=$KEYPASS
EOF
    echo "→ credentials appended to ~/.gradle/gradle.properties (mode 600)"
fi

echo "→ verifying"
"$KEYTOOL" -list -v -keystore "$KEYSTORE" -storepass "$STOREPASS" | grep -E "Alias name|Valid from" | head -4
echo
echo "✓ keystore created. BACK IT UP NOW — somewhere off this machine."
echo "  Losing it means you can never update this app's Play listing again."
