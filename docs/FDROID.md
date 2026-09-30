<!-- qompassai/android-template/docs/FDROID.md -->
<!-- F-Droid runbook for {{APP_NAME}} ({{APP_ID}}). Follows the fdroid-publish
     skill gate for gate; when in doubt, the skill wins. -->

# F-Droid runbook — {{APP_NAME}}

F-Droid builds from source on its own infrastructure using a metadata recipe
you submit to the `fdroiddata` repo (GitLab). It signs everything itself —
there are no API keys and no upload credentials. The only interaction is a
single merge request.

## The five gates

### Gate 1 — Eligibility

- Public source repo, Apache-2.0 `LICENSE` (single SPDX id).
- FOSS dependencies only: no Firebase/GMS, no prebuilt proprietary libs.
  **No prebuilt `.so` files in git** — F-Droid's build server must compile
  everything from source. Gitignore `*/jniLibs/` and any `target/` outputs.
- Buildable with FOSS command-line tools (this template: Rust + cargo-ndk /
  cargo-apk + Gradle).

### Gate 2 — Upstream metadata (fastlane tree)

F-Droid renders the listing from this repo. Required layout:

```
fastlane/metadata/android/en-US/
├── title.txt                  # ≤ 50 chars
├── short_description.txt      # ≤ 80 chars, single line, NO trailing dot
├── full_description.txt       # ≤ 4000 chars
├── images/icon.png            # 512x512 PNG
├── images/phoneScreenshots/   # 1.png, 2.png, ... (strongly recommended)
└── changelogs/<versionCode>.txt  # ≤ 500 chars, named by versionCODE
```

Copy the `*.example` files in this template, drop the suffix, fill in real
copy. New screenshots/descriptions are only re-read at the next release.

### Gate 3 — The recipe (`fdroiddata/{{APP_ID}}.yml`)

Copy `fdroiddata/{{APP_ID}}.yml.example`, rename, fill every TODO. Hard rules:

- `commit:` = **full 40-char SHA** of the release commit. Never a tag or branch.
- `ndk:` only in an official scheme: `r21e` or the full revision `21.4.7075529`.
  A bare build number is invalid.
- `License: Apache-2.0` (single SPDX id). `Categories:` verbatim from F-Droid's
  category list — pick the precise one (e.g. `Puzzle Game`, not `Games`).
- `AntiFeatures:` declared honestly (`Tracking`, `NonFreeNet`, ...).
- Never set `Name`/`Summary`/`Description` when the fastlane tree exists —
  they override it.
- `UpdateCheckMode: Tags` + `AutoUpdateMode: Version` unless you have a reason
  not to; versions must be literals (F-Droid extracts with regex only).

Two build flavors are covered in the example recipe — uncomment the one that
matches your layout:

- **cargo-apk** (pure Rust, e.g. Bevy): `cargo install cargo-apk`,
  `cargo apk build --release`, `output: target/release/apk/{{SLUG}}.apk`
- **gradle** (Rust core + Gradle shell): rustup + `cargo-ndk` + Android targets,
  then `scripts/publish/build-android.sh apk`,
  `output: app/build/outputs/apk/release/app-release-unsigned.apk`

### Gate 4 — Local validation

```bash
scripts/publish/tbr-fdroid-submit.sh --dry-run   # all machine-checkable gates
```

With `fdroidserver` installed, inside your fdroiddata fork:

```bash
fdroid readmeta
fdroid rewritemeta {{APP_ID}}   # must produce no diff — commit the result if it does
fdroid lint {{APP_ID}}          # must be clean
fdroid build -v {{APP_ID}}      # the real build, closest to what the farm does
```

Or skip local setup: push the branch to your fork and let fdroiddata's own CI
validate it.

### Gate 5 — Submission [TBR]

Run `scripts/publish/tbr-fdroid-submit.sh` (real run) — it prints the exact
human steps: fork `https://gitlab.com/fdroid/fdroiddata`, branch named
`{{APP_ID}}`, add `metadata/{{APP_ID}}.yml`, commit `New App: {{APP_ID}}`,
open the MR, answer reviewers. Expect 24–48h after merge before the app
appears.

## Versioning going forward

Every release needs a new `Builds:` entry pinned to the new release commit
SHA, plus a new `changelogs/<versionCode>.txt`. F-Droid does not auto-discover
versions from `main`.
