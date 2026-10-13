<!-- scripts/publish/tbr-play-console.md — Google Play Console walkthrough. [TBR] -->
<!-- TBR = to-be-reviewed: a human-gated task. The Play Console is a web UI;
     no script can click through it for you. Work this checklist top to bottom.
     One Google account, one keystore, one service account per publisher. -->
<!-- Creation-form and dashboard behaviour verified against a live app
     creation, 2026-10-13. -->

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
- [ ] Privacy policy hosted and **live** at `{{PRIVACY_POLICY_URL}}`,
      reachable from your site's footer — §3 item 1 pastes it during the
      sitting, and Play fetches it then.

## 1. Create the app

1. [Play Console](https://play.google.com/console) → **All apps → Create app**
2. App name: **{{APP_NAME}}** (it becomes the listing title — ≤30 chars) ·
   Default language: **English (United States)**
3. Package name: **`{{APP_ID}}`** — the creation form asks for it now.
   Click **Check availability** before submitting: that check is the
   Android developer-verification package registration (required for new
   packages since 2026-09-30). The package name is **permanent** — it can
   never be changed or reused — and it must match the built bundle exactly,
   character for character. If availability asks for anything beyond a plain
   "available", stop and resolve it before creating the app.
4. App or game: pick honestly (**Game** if it is one); you can change this
   later in Store settings.
5. Free or paid: **Free** unless the app is genuinely paid. One-way door:
   once a free app is *published* it can never become paid (the choice stays
   editable on the App pricing page until you publish).
6. Automatic protection: leave **ON** — it adds an installer check that
   steers sideloaded copies back to Play; no downside for a normal listing.
   Don't click "Turn off".
7. Declarations: tick **both** boxes — the Developer Program Policies
   confirmation and the US export laws acceptance. (An offline app with no
   cryptography beyond the platform's own has nothing export-controlled;
   accept as written.)

## 2. Service account (for scripted uploads later)

- [ ] In Console: **Users and permissions → Invite new users**
- [ ] Invite the publisher service account as **Release manager** on **this app**.
      (One service-account key can serve every app you publish — invite it
      per-app; the invite is what grants it access to each listing.)
- [ ] Keep the JSON key somewhere safe (password manager, not the repo).
- [ ] The invite is Console-only — the API cannot grant it. Do it in the
      same sitting as app creation; once invited, uploads and listing edits
      can be scripted (Play Developer API / fastlane supply).

## 3. Finish setting up your app — the setup checklist

These are the dashboard's **Finish setting up your game/app** tasks. They
gate everything downstream: **closed testing stays locked until all of them
are complete** ("To start a closed test, finish setting up your game"), so
work them in the creation sitting. The dashboard groups them as "Let us
know about the content of your app" (Policy → App content) and "Manage how
your app is organized and presented" (Store presence / Store settings).

The answers below are for the typical Qompass app — offline, no accounts,
no ads, no networking. If yours differs, answer from the built artifact,
not from habit.

### Let us know about the content of your app

- [ ] **1. Set privacy policy** (App content → Privacy policy). Paste
      `{{PRIVACY_POLICY_URL}}`. It must already be live and footer-reachable
      (see §0): Play fetches it, and a 404 or parked page blocks setup. The
      policy text and the Data Safety answers (item 6) must agree —
      contradictions get listings rejected.
- [ ] **2. Sign in details** (App content → App access). No login, no gated
      areas → **All functionality is available without special access.** If
      any part of the app needs an account or credentials, declare it and
      supply working test credentials — reviewers will try them.
- [ ] **3. Ads** (App content → Ads). Declare **No ads** unless an ad SDK is
      actually in the build. Verify against the artifact (merged manifest,
      dependency list) — never guess. A "no ads" declaration with an ad SDK
      present is a policy violation.
- [ ] **4. Content rating** (App content → Content ratings). Start the IARC
      questionnaire; the rating certificate is issued from your answers and
      arrives by email at the account address. Console-only — there is no
      API path. Answer from the app's actual content; most offline Qompass
      apps rate Everyone.
- [ ] **5. Target audience** (App content → Target audience and content).
      Declare the real audience. If the app is not directed at children,
      select adult age groups (18+) only — that keeps you out of the
      Designed for Families machinery, which applies when children are in
      the audience or the content appeals to them. Never claim an app isn't
      designed to appeal to children if it visibly is.
- [ ] **6. Data safety** (App content → Data safety). Derive the answers
      from the built artifact, not from intention: read the merged
      manifest's permission list and the SDKs in the bundle. A
      zero-permission offline app collects and shares nothing → **No data
      collected, No data shared**. Any permission or SDK that phones home
      changes these answers.
- [ ] **7. Government apps** (App content → Government apps). **No**,
      unless the app genuinely is an official government app.
- [ ] **8. Financial features** (App content → Financial features).
      **None**, unless present — the form lists the feature types
      (banking, payments, crypto, …); tick only what the app actually does.
- [ ] **9. Health** (App content → Health apps). **None**, unless the app
      has health functionality. Declaring health features triggers extra
      review and requirements.

### Manage how your app is organized and presented

- [ ] **10. App category and contact details** (Store settings). Pick the
      category/subcategory that match the app (a game also picks its game
      category and tags). Public contact email: `{{CONTACT_EMAIL}}` — an
      address you actually monitor; it is shown on the listing. Website:
      `{{WEBSITE_URL}}`.
- [ ] **11. Store listing** (Store presence → Main store listing). Title
      ≤30 chars, short description ≤80, full description ≤4000, app icon
      512×512, feature graphic 1024×500, phone screenshots ≥2 — **prepare
      8** (see §0). Field-by-field copy source: §4. After the §2 invite,
      the listing can also be pushed via fastlane supply / the API instead
      of pasted by hand.

## 4. Store listing

Copy from `fastlane/metadata/android/en-US/` (the single source of truth):

- [ ] Title ← `title.txt` (≤30 chars)
- [ ] Short description ← `short_description.txt` (≤80 chars)
- [ ] Full description ← `full_description.txt` (≤4000 chars)
- [ ] App icon (512×512), feature graphic (1024×500), phone screenshots (≥2)
- [ ] Category, contact email, privacy-policy URL

## 5. First release — Internal testing first

Order of operations that works: create the app (§1) → setup tasks (§3–§4) →
invite the service account (§2) → first upload to Internal testing →
closed-track release (§6) → tester opt-ins start the production clock.

- [ ] **Release → Internal testing → Create new release**
- [ ] Upload the signed `.aab` from step 0. **Play App Signing enrollment
      happens at this first upload** — accept the recommended setup: your
      keystore becomes the *upload* key and Google holds the app signing
      key. (A lost upload key is recoverable through Play support; that
      recoverability is the point of enrolling.)
- [ ] Release notes: one line per user-visible change (≤500 chars each is fine)
- [ ] **Save → Review release → Start rollout to Internal testing**
- [ ] Add yourself as a tester, open the testing link on your phone, install,
      and exercise the app end-to-end (launch, core flow, no crashes).
- [ ] After the §2 invite, this and later uploads can run through the API /
      fastlane instead of the Console UI. Doing the first one by hand is
      fine — it proves the pipeline end to end.

## 6. The closed test gate — and promoting to production

The app dashboard's **Production** section tells you whether your account
must run a closed test before production access. For a **new personal
developer account, it does** (verified 2026-10-13). The criteria, as the
dashboard states them:

- Publish a closed testing release
- Have at least 12 testers opted-in to your closed test
- Run your closed test with at least 12 testers, for at least 14 days
- Then **Apply for production**, and answer the questions about your
  closed test

Plan for it as the default:

- [ ] Closed testing is locked until §3 is fully complete — finish the
      setup tasks first, in the creation sitting.
- [ ] Recruit **more than 12 testers — aim for 15+**. A tester who opts
      out and back in restarts their own 14 days, and dropping below 12
      opted-in testers mid-run endangers the whole run.
- [ ] The 14-day clock runs while the closed release is live with testers
      opted in. Every day of setup delay moves the earliest production
      application date by a day.
- [ ] Promote Internal → Closed → (Open, optional) → Production once the
      gate clears. Each new upload needs a **strictly higher
      `versionCode`** than the last — bump it in the Gradle file or
      `Cargo.toml` `[package.metadata.android]`, rebuild, re-upload.

## Troubleshooting

- **AAB rejected (signing)**: `keytool -list` shows the alias; the
  `~/.gradle/gradle.properties` values match; the keystore path is right.
- **Data Safety rejection**: the hosted privacy-policy text and the Console
  answers disagree — diff them line by line.
- **Listing rejected (screenshots)**: screenshots must be of the actual app,
  not mockups. Re-capture with `scripts/publish/screenshots.sh`.
- **Package name unavailable at creation**: check for typos first — you
  cannot take another app's package name, and you cannot change yours
  afterwards. If the name is right, complete whatever registration step
  the availability check asks for; never "fix" it by changing the app's
  real ID once builds exist.
