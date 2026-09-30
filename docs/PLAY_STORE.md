<!-- qompassai/android-template/docs/PLAY_STORE.md -->
<!-- Google Play runbook for {{APP_NAME}} ({{APP_ID}}). -->

# Google Play runbook — {{APP_NAME}}

## 1. Prerequisites (one-time)

```bash
# Rust Android targets + cargo-ndk (gradle layout) or cargo-apk (pure Rust)
rustup target add aarch64-linux-android armv7-linux-androideabi
cargo install cargo-ndk   # gradle layout
cargo install cargo-apk   # cargo-apk layout

# Android SDK / NDK / JDK 17 (Arch + AUR shown; adapt to your distro)
yay -S android-sdk android-sdk-platform-tools android-sdk-build-tools \
       android-sdk-cmdline-tools-latest android-ndk jdk17-openjdk

# Accept all licenses
yes | /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager --licenses

# Env this template's scripts expect (put in your shell rc):
export ANDROID_HOME=/opt/android-sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
```

## 2. Upload keystore [TBR]

```bash
scripts/publish/tbr-keystore.sh          # human only; prompts for passwords
```

Creates `~/.android/{{SLUG}}-upload.jks` (RSA 4096, 10000 days) and stores
the credentials in `~/.gradle/gradle.properties` — both **outside the repo**.
Validate first without touching anything:

```bash
scripts/publish/tbr-keystore.sh --dry-run
```

Losing the keystore means you can never update the app under the same
listing again. Back it up off-machine the day you create it.

## 3. Build the signed AAB

```bash
scripts/publish/build-android.sh aab
# gradle layout:  <android-dir>/app/build/outputs/bundle/release/app-release.aab
# cargo-apk layout: build the APK, then bundle per cargo-apk docs
```

Verify signatures:

```bash
# AAB:  jarsigner -verify -verbose -certs <file>.aab
# APK:  apksigner verify --print-certs <file>.apk
```

## 4. Test before you ship

```bash
scripts/publish/test-device.sh        # cargo tests + on-device smoke
scripts/publish/screenshots.sh 4      # real screenshots for the listing
```

Play requires ≥2 phone screenshots, recommends 4–8 (1080px shortest side).

## 5. Play Console [TBR]

Work `scripts/publish/tbr-play-console.md` top to bottom: create the app,
invite the service account as release manager, fill in App content
(Data Safety, content rating, target audience), paste the store listing
from `fastlane/metadata/android/en-US/`, upload the signed AAB to
**Internal testing** first, self-test on a real device, then promote
Internal → Closed → Open → Production.

## 6. Subsequent versions

Each upload needs a **strictly higher `versionCode`** than the last. Bump it
in the Gradle file or `Cargo.toml` `[package.metadata.android]`, add a new
`fastlane/.../changelogs/<versionCode>.txt`, rebuild, re-upload — and add the
matching `Builds:` entry to the F-Droid recipe (see `docs/FDROID.md`).

## Troubleshooting

- **License for package … not accepted** — re-run `sdkmanager --licenses`.
- **NDK ABI mismatch** — the NDK version in the Gradle config must match the
  installed one.
- **linker not found** — `cargo install cargo-ndk` and re-run.
- **AAB rejected (signing)** — `keytool -list -v -keystore
  ~/.android/{{SLUG}}-upload.jks` shows the alias and the
  `~/.gradle/gradle.properties` values match.
