<!-- scripts/publish/tbr-play-console.md — Google Play Console walkthrough. [TBR] -->
<!-- TBR = to-be-reviewed: a human-gated task. The Play Console is a web UI;
     no script can click through it for you. Work this checklist top to bottom.
     One Google account, one keystore, one service account per publisher. -->

# Play Console walkthrough — {{APP_NAME}} [TBR]

Package: `{{APP_ID}}` · Store listing copy: `fastlane/metadata/android/en-US/`
and `playstore/google-play.json` (if present) — keep the two in sync.

## 0. Before you start

- [ ] Upload keystore created via `tbr-keystore.sh` (real run) and **backed up
      off this machine**. `keytool -list -v -keystore ~/.android/{{SLUG}}-upload.jks`
      shows the alias.
- [ ] Signed AAB built: `scripts/publish/build-android.sh aab`
- [ ] Phone screenshots captured: `scripts/publish/screenshots.sh 4`
      (Play needs ≥2, recommends 4–8; 1080px shortest side, 9:16 or 16:9)
- [ ] Feature graphic ready: 1024×500 PNG/JPG, no alpha
- [ ] App icon 512×512 PNG ready (`fastlane/.../images/icon.png` works)

## 1. Create the app

1. [Play Console](https://play.google.com/console) → **All apps → Create app**
2. App name: **{{APP_NAME}}** · Default language: **English (United States)**
3. Type: **App** · **Free** (no in-app purchases unless you add them later)
4. Accept the declarations.

## 2. Service account (for scripted uploads later)

- [ ] In Console: **Users and permissions → Invite new users**
- [ ] Invite the publisher service account as **Release manager** on **this app**.
      (One service-account key can serve every app you publish — invite it
      per-app; the invite is what grants it access to each listing.)
- [ ] Keep the JSON key somewhere safe (password manager, not the repo).

## 3. App content (Set up your app checklist)

- [ ] **App access**: declare whether there's a login wall. If none, say so.
      (If the app has accounts, supply test credentials.)
- [ ] **Ads**: Yes/No — must match reality; no ad SDK means No.
- [ ] **Content rating**: complete the questionnaire (most Qompass apps: Everyone).
- [ ] **Target audience**: set honestly (many dev tools: 18+).
- [ ] **News / Government / Health apps**: answer each; usually No.
- [ ] **Data Safety**: transcribe from your privacy policy + the permission list
      in the manifest. Every data type collected, its purpose, and whether it
      is shared — the Console rejects listings whose answers contradict the
      hosted privacy policy.
- [ ] **Privacy policy URL**: must be live and hosting the current policy text
      before submission. Play rejects 404s and mismatched text.

## 4. Store listing

Copy from `fastlane/metadata/android/en-US/` (the single source of truth):

- [ ] Title ← `title.txt` (≤50 chars)
- [ ] Short description ← `short_description.txt` (≤80 chars)
- [ ] Full description ← `full_description.txt` (≤4000 chars)
- [ ] App icon (512×512), feature graphic (1024×500), phone screenshots (≥2)
- [ ] Category, contact email, privacy-policy URL

## 5. First release — Internal testing first

- [ ] **Release → Internal testing → Create new release**
- [ ] Upload the signed `.aab` from step 0
- [ ] Release notes: one line per user-visible change (≤500 chars each is fine)
- [ ] **Save → Review release → Start rollout to Internal testing**
- [ ] Add yourself as a tester, open the testing link on your phone, install,
      and exercise the app end-to-end (launch, core flow, no crashes).

## 6. Promote when stable

Internal → Closed → Open → Production, at your own pace. Each new upload
needs a **strictly higher `versionCode`** than the last — bump it in the
Gradle file or `Cargo.toml` `[package.metadata.android]`, rebuild, re-upload.

## Troubleshooting

- **AAB rejected (signing)**: `keytool -list` shows the alias; the
  `~/.gradle/gradle.properties` values match; the keystore path is right.
- **Data Safety rejection**: the hosted privacy-policy text and the Console
  answers disagree — diff them line by line.
- **Listing rejected (screenshots)**: screenshots must be of the actual app,
  not mockups. Re-capture with `scripts/publish/screenshots.sh`.
