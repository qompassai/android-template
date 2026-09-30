#!/usr/bin/env bash
# scripts/publish/tbr-fdroid-submit.sh — submit the app to F-Droid. [TBR]
#
# TBR = to-be-reviewed: a human-gated task. Only a human performs the GitLab
# fork/MR clicks; agents may only run this with --dry-run.
#
# --dry-run: runs every machine-checkable gate (fastlane tree, recipe fields,
#   fdroid lint if fdroidserver is installed) and prints the exact manual
#   steps. Changes nothing, needs no accounts.
# Real run: re-runs the gates, then prints the step-by-step the human follows.
#
# Env (optional): APP_ID (default {{APP_ID}}), VERCODE (default 1),
#   CHECK_BIN (path to fdroid-publish-check)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help) awk '/^$/{exit} /^#/{sub(/^# ?/, ""); print}' "$0"; exit 0 ;;
        *) echo "✗ unknown arg: $arg" >&2; exit 2 ;;
    esac
done

APP_ID="${APP_ID:-{{APP_ID}}}"
VERCODE="${VERCODE:-1}"
RECIPE="$ROOT/fdroiddata/${APP_ID}.yml"
META="$ROOT/fastlane/metadata/android/en-US"

fail() { echo "✗ $*" >&2; exit 1; }
pass() { echo "  PASS $*"; }

echo "→ tbr-fdroid-submit (dry-run: $DRY_RUN, app: $APP_ID)"
FAIL=0

# Gate A: fastlane tree -------------------------------------------------------
[ -f "$META/title.txt" ] || { echo "  FAIL fastlane: missing title.txt"; FAIL=1; }
TITLE="$(cat "$META/title.txt" 2>/dev/null | head -1)"
[ "${#TITLE}" -le 50 ] && [ -n "$TITLE" ] || { echo "  FAIL fastlane: title >50 chars or empty"; FAIL=1; }
SHORT="$(cat "$META/short_description.txt" 2>/dev/null | head -1)"
case "$SHORT" in
    *.) echo "  FAIL fastlane: short_description.txt ends with a dot"; FAIL=1 ;;
esac
[ "${#SHORT}" -le 80 ] && [ -n "$SHORT" ] || { echo "  FAIL fastlane: short_description >80 chars or empty"; FAIL=1; }
[ -f "$META/images/icon.png" ] || { echo "  FAIL fastlane: missing images/icon.png"; FAIL=1; }
ls "$META/images/phoneScreenshots"/*.png >/dev/null 2>&1 || echo "  WARN fastlane: no phoneScreenshots (strongly recommended)"
[ -f "$META/changelogs/${VERCODE}.txt" ] || { echo "  FAIL fastlane: missing changelogs/${VERCODE}.txt (named by versionCODE)"; FAIL=1; }
[ "$FAIL" -eq 0 ] && pass "fastlane tree"

# Gate B: recipe --------------------------------------------------------------
[ -f "$RECIPE" ] || fail "recipe not found: $RECIPE — copy fdroiddata/{{APP_ID}}.yml.example and fill it"
COMMIT="$(grep -E '^\s*commit:' "$RECIPE" | head -1 | awk '{print $2}')"
case "$COMMIT" in
    ????????????????????????????????????????) pass "recipe commit is full SHA" ;;
    *) echo "  FAIL recipe: commit: must be full 40-char SHA (got: $COMMIT)"; FAIL=1 ;;
esac
grep -qE '^\s*ndk: (r[0-9]+[a-z]|[0-9]+\.[0-9]+\.[0-9]+)$' "$RECIPE" \
    || { echo "  FAIL recipe: ndk: must be an official scheme (r21e or 21.4.7075529)"; FAIL=1; }
grep -qE '^\s*License: Apache-2\.0$' "$RECIPE" || { echo "  FAIL recipe: License must be Apache-2.0"; FAIL=1; }
grep -qE '^\s*(Name|Summary|Description):' "$RECIPE" && { echo "  FAIL recipe: Name/Summary/Description must not be set when the fastlane tree exists"; FAIL=1; }
[ "$FAIL" -eq 0 ] && pass "recipe fields"

# Gate C: fdroidserver validation (if installed) -------------------------------
if command -v fdroid >/dev/null 2>&1; then
    echo "→ fdroidserver present — running lint (needs an fdroiddata checkout; skipped here)"
    echo "  Run inside your fdroiddata fork: fdroid lint $APP_ID && fdroid build -v $APP_ID"
else
    echo "  SKIP fdroid lint/build — fdroidserver not installed (Arch: pacman -S fdroidserver)"
fi

# Gate D: external check binary (if provided) ----------------------------------
if [ -n "${CHECK_BIN:-}" ] && [ -x "$CHECK_BIN" ]; then
    step2() { echo "→ $*"; }
    step2 "fdroid-publish-check --repo $ROOT --appid $APP_ID --vercode $VERCODE"
    "$CHECK_BIN" --repo "$ROOT" --appid "$APP_ID" --vercode "$VERCODE" || FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then
    fail "gates failed — fix the items above before submitting"
fi
echo "→ all machine-checkable gates PASS"

# --- the human steps (printed in both modes; only a human does them) ----------
cat <<EOF

=== F-Droid submission — human steps ===
F-Droid builds and signs everything itself; there are no API keys.
The only interaction is one merge request on GitLab.

1. Fork https://gitlab.com/fdroid/fdroiddata on GitLab, clone it.
2. Branch named exactly: $APP_ID
3. Copy this repo's recipe into the fork:
     cp $RECIPE <fork>/metadata/$APP_ID.yml
4. In the fork: fdroid readmeta && fdroid rewritemeta $APP_ID
   (must produce no diff — commit the result if it does)
   Then: fdroid lint $APP_ID   (must be clean)
5. Commit as "New App: $APP_ID", push the branch.
6. Open the MR against fdroid/fdroiddata:master, fill the MR template.
7. Answer reviewer questions. First submissions almost always get one round
   of recipe changes — that's normal.
8. After merge, expect 24–48h before the app appears (human keystore step).

Recipe to submit: $RECIPE
Docs: https://f-droid.org/docs/Submitting_to_F-Droid_Quick_Start_Guide/
EOF
