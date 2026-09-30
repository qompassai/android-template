<!-- qompassai/android-template/TODO.md -->
<!-- Publication checklist for {{APP_NAME}} ({{APP_ID}}). Work top to bottom.
     "Anyone" steps are scripted in scripts/publish/; [TBR] steps are
     to-be-reviewed — only a human does them. -->

# Publication checklist — {{APP_NAME}}

## 0. Instantiate the template

- [ ] Click **Use this template**, name the repo, clone it
- [ ] Replace every `{{APP_NAME}}`, `{{APP_ID}}`, `{{DESCRIPTION}}`, `{{SLUG}}`
- [ ] Rename `*.example` files (drop the suffix) and fill in real copy
- [ ] Delete the "How to use this template" section from README.md

## 1. App completeness (blocks everything)

- [ ] The game/app is actually complete and playable — no soft-locking levels,
      no stub results screens, no placeholder art you don't have rights to
- [ ] All art/audio/fonts are original, generated, or compatibly licensed,
      with attribution tracked (rights TBD = release blocker)

## 2. Build & test (anyone)

- [ ] `scripts/publish/build-android.sh apk` — unsigned release APK builds clean
- [ ] `scripts/publish/test-device.sh` — `cargo test --workspace` green +
      on-device install/launch smoke passes
- [ ] `scripts/publish/screenshots.sh 4` — ≥2 real phone screenshots captured
      (Play needs ≥2, recommends 4–8)

## 3. F-Droid (anyone, then [TBR])

- [ ] `fastlane/metadata/android/en-US/` complete: title ≤50, short ≤80 with
      **no trailing dot**, full ≤4000, `images/icon.png` 512×512,
      `changelogs/<versionCode>.txt` ≤500 (named by versionCODE)
- [ ] `fdroiddata/{{APP_ID}}.yml`: `commit:` = full 40-char SHA (never a tag),
      `ndk:` in official scheme (`r21e` or `21.4.7075529`), `License: Apache-2.0`,
      no `Name`/`Summary`/`Description` (fastlane tree provides them)
- [ ] No prebuilt `.so`/binaries in git; no Firebase/GMS/proprietary deps
- [ ] Recipe dry-run from a clean checkout (the exact `sudo:`/`init:`/`build:` steps)
- [ ] `tbr-fdroid-submit.sh --dry-run` — all gates PASS
- [ ] [TBR] `tbr-fdroid-submit.sh` real run: fork fdroiddata, MR, answer reviewers

## 4. Google Play ([TBR] human steps)

- [ ] [TBR] `tbr-keystore.sh` real run — upload keystore created **and backed up
      off-machine** (losing it = never updating the listing again)
- [ ] `scripts/publish/build-android.sh aab` — signed AAB builds
- [ ] [TBR] `tbr-play-console.md` — Console app created, service account invited
      as release manager, listing + Data Safety + privacy-policy URL done
- [ ] [TBR] First upload to **Internal testing**, self-test on a real device,
      then promote Internal → Closed → Open → Production

## 5. Windows (decision)

- [ ] Pick the distribution story: **MSIX** vs **Steam** vs **direct download**
- [ ] Build/sign/publish per the chosen story

## 6. After shipping

- [ ] Every new release: bump `versionCode` (strictly higher), new changelog
      file named by the new versionCode, new recipe `Builds:` entry pinned to
      the new release commit SHA
- [ ] Keep `fastlane/` copy and `playstore/` listing in sync (one source of truth)
