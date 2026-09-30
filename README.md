<!-- qompassai/android-template/README.md -->
<!-- Replace {{APP_NAME}}, {{APP_ID}}, {{DESCRIPTION}} and {{SLUG}} when you instantiate this template. -->

# {{APP_NAME}}

> {{DESCRIPTION}}

![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)

A Qompass AI Android app — Rust-first, published to Google Play and F-Droid
from this repo's `scripts/` and `docs/`, in the standard Qompass AI layout.

## How to use this template

1. On GitHub, click **Use this template** → **Create a new repository**.
2. Name it after the app (e.g. `qompassai/my-app`).
3. Replace every `{{PLACEHOLDER}}` in this README, `CITATION.cff`,
   `fastlane/` examples, `fdroiddata/` example, and the `scripts/`, then
   delete this section.
4. Rename the `*.example` files (drop the `.example` suffix) and fill them
   with your app's real copy.

Placeholders used in this template:

| Placeholder       | Meaning                                  | Example              |
|-------------------|------------------------------------------|----------------------|
| `{{APP_NAME}}`    | App name, title case                     | Light Show           |
| `{{APP_ID}}`      | Android applicationId (reverse-DNS)      | ai.qompass.lightshow |
| `{{DESCRIPTION}}` | One-line repo description                | Qompass AI on mobile |
| `{{SLUG}}`        | Lowercase, URL-safe app slug             | light-show           |

## The publication pipeline

```
write code → scripts/publish/build-android.sh → scripts/publish/test-device.sh
   → scripts/publish/screenshots.sh → fastlane/ metadata + fdroiddata/ recipe
   → TODO.md checkboxes → Google Play (you) + F-Droid MR (you) → shipped
```

Every publication task is one script under `scripts/publish/` — one script,
one task. Tasks only a human can do (keys, accounts, console clicks) carry
the **TBR** prefix: *to-be-reviewed*. Agents may run TBR scripts with
`--dry-run` only; a human runs them for real.

| Step | Script | Who |
|------|--------|-----|
| Build unsigned APK (F-Droid) or AAB (Play) | `scripts/publish/build-android.sh` | anyone |
| Unit tests + on-device smoke test | `scripts/publish/test-device.sh` | anyone |
| Emulator screenshots for both stores | `scripts/publish/screenshots.sh` | anyone |
| Upload keystore creation | `scripts/publish/tbr-keystore.sh` | **you [TBR]** |
| F-Droid submission walkthrough | `scripts/publish/tbr-fdroid-submit.sh` | **you [TBR]** |
| Play Console: listing, Data Safety, upload | `scripts/publish/tbr-play-console.md` | **you [TBR]** |

The [fdroid-publish skill](https://github.com/qompassai/diver)
is the authority on F-Droid's gates — `docs/FDROID.md` follows it gate
for gate. When in doubt, the skill wins.

## Layout

```text
scripts/publish/    # one script per publication task (TBR = human-gated)
docs/               # FDROID.md + PLAY_STORE.md runbooks
fastlane/metadata/android/en-US/  # store listing copy (*.example → fill in)
fdroiddata/         # F-Droid build recipe ({{APP_ID}}.yml.example → fill in)
.github/            # CI: sanity checks on every push
```

## Rules that travel with every app

- **Apache-2.0 only.** No dual licensing, no GPL — F-Droid and Play both
  accept it, and it keeps the whole catalog consistent.
- **F-Droid builds from source.** No prebuilt `.so` files in git, no
  proprietary SDKs (no Firebase/GMS). If a feature needs them, ship an
  F-Droid flavor without them.
- **Recipe pins SHAs, not tags.** `commit:` in the fdroiddata recipe is
  always the full 40-char SHA. Tags move; SHAs don't.
- **Keys live outside the repo.** The upload keystore and its passwords
  are never committed. Lose the keystore and you can never update the
  listing again.

## License

This project is licensed under the [Apache License, Version 2.0](./LICENSE).

Copyright 2026 Qompass AI.
