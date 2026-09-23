# Studio 3 — iOS and Android store launch guide

**This file is not committed. `docs/` is git-ignored in this repo, and this document was
created on request to stay local-only — do not `git add` or push it.**

Everything below reflects the actual state of this project as of today, not a generic
checklist — file paths, IDs, and what is already done vs still open are all specific to
Studio 3.

---

# Part 1 — iOS

## Current state (verified)

| | |
|---|---|
| Team | `5XVXDNBNKN` — Third Place Studios LLC |
| Bundle ID | `com.studio3.discover` |
| Signing | Automatic; Distribution cert already in this Mac's keychain |
| Provisioning profile | "Studio3 App Store Distribution" |
| Deployment target | iOS 15.0 |
| Push (`aps-environment`) | **Not configured** |
| `GoogleService-Info.plist` | **Missing** — Firebase falls back gracefully (try/catch in `main.dart`), push just stays inert |
| Universal Links | Claims `studio3-backend.onrender.com` and `studio-3.co` — **not `api.studio-3.co`**, the AWS backend |

## 1.1 — Build and upload to TestFlight

Do this every time you want a new build on testers' devices, or before an App Store
submission.

1. **Clean tree**
   ```bash
   cd /Users/sahil/MEGAsync/Freelance/StudioApp/app/studio3
   git status --short   # should be empty
   ```

2. **Bump the build number** — open `pubspec.yaml`:
   ```yaml
   version: 1.0.0+2   →   version: 1.0.0+3
   ```
   Only the number after `+`. App Store Connect refuses a second upload with an unchanged
   build number. Bump the part before `+` only when it's an actual new release, not every
   TestFlight build.

3. **Dependencies and pods**
   ```bash
   flutter pub get
   cd ios && pod install && cd ..
   ```
   If `pod install` misbehaves, check `git status --short -- ios/Podfile.lock` first — an
   unrelated `npm install` elsewhere in this repo has rewritten platform-specific pod files
   before.

4. **Open the workspace** — not the project:
   ```bash
   open ios/Runner.xcworkspace
   ```

5. In Xcode's toolbar, set the destination to **Any iOS Device (arm64)** — not a simulator,
   not your own phone. Archiving only works against this.

6. **Product → Archive.** Several minutes. Xcode Organizer opens automatically when it's
   done.

   If it fails, check in this order: destination really is "Any iOS Device"; `pod install`
   actually completed; Team `5XVXDNBNKN` is still selected under Runner target → Signing &
   Capabilities.

7. In Organizer, with the new archive selected: **Distribute App → App Store Connect →
   Upload → Next** through the remaining screens with defaults → **Upload**.

8. **Wait 5–30 minutes** for Apple's processing (automated checks) before the build is
   selectable in TestFlight. Check at
   **appstoreconnect.apple.com → Studio 3 Discover → TestFlight**.

## 1.2 — Submit to the public App Store

Separate from TestFlight — a build finishing TestFlight processing doesn't submit it for
public release on its own.

1. **App Store Connect → your app → App Store tab** (not TestFlight)
2. **Create a new version** if none is open
3. Fill in the listing (first submission needs all of this; later ones only what changed):
   - Screenshots per required device size (6.7", 6.5", 5.5" iPhone, at minimum)
   - Description, promotional text, keywords, subtitle
   - Support URL — **required**
   - Privacy policy URL — **required**
   - Category
   - Pricing and availability
   - Age rating questionnaire
4. Under the version, **+ next to Build** → select the TestFlight build to ship
5. **App Review Information**
   - Reviewer contact info
   - **Demo account credentials** if login is required — the reviewer needs to get past
     your login screen. Given this is a real marketplace with Stripe payments, also note in
     the review notes whether you want them testing with live or sandboxed payment flows.
   - Notes on anything non-obvious (e.g. "auctions require a saved card before bidding")
6. **Release option**: automatic (live the moment it's approved) or manual (approved, but
   you flip the switch)
7. **Submit for Review** — typically 24–48 hours, sometimes longer
8. **Approved** → live (or waiting on you) · **Rejected** → Resolution Center explains why;
   fix and resubmit without redoing the whole listing

## 1.3 — Push notifications (currently not working on iOS)

Was deliberately deferred earlier in the project. Not required to ship — nothing crashes
without it, push notifications on iOS just never register. Android already has this
working.

1. **Apple Developer portal** (developer.apple.com → Certificates, IDs & Profiles)
   - **Identifiers → `com.studio3.discover`** → enable the **Push Notifications** capability
   - **Keys** → create a new key with **APNs** enabled → download the `.p8` file.
     **Apple only lets you download it once** — save it somewhere durable immediately.

2. **Firebase console** (console.firebase.google.com → project `studio3-ac2cb`)
   - If no iOS app is registered in this project yet: **Add app → iOS**, bundle ID
     `com.studio3.discover`. Download the resulting `GoogleService-Info.plist`.
   - **Project settings → Cloud Messaging tab → APNs Authentication Key** → upload the
     `.p8` from step 1, with its Key ID and Team ID (`5XVXDNBNKN`).

3. **Add the plist to Xcode** — drag `GoogleService-Info.plist` into `ios/Runner/`,
   checking "Copy items if needed" and the **Runner** target membership.

4. **Add the capability in Xcode** — Runner target → Signing & Capabilities →
   **+ Capability → Push Notifications**, and also **Background Modes → Remote
   notifications**. Xcode writes `aps-environment` into `Runner.entitlements` for you when
   added this way — no hand-editing.

5. **Rebuild and re-archive** — can't be patched into an existing build; follow §1.1 again
   with a bumped build number.

6. **Verify** — a device token should register on iOS on next login (check backend logs);
   Firebase console's "Send test message" should land on a **real device** (simulators
   can't receive push).

`aps-environment` will be `development` or `production` depending on which provisioning
profile signs the build — a TestFlight/App Store build needs `production`, which the
Distribution profile already in use should give automatically. Confirm with a real test push
before relying on it.

## 1.4 — Deep links from the AWS backend don't work yet

`Runner.entitlements` claims Universal Links for `studio3-backend.onrender.com` and
`studio-3.co` only. A piece link or event QR generated from the AWS backend
(`api.studio-3.co`) won't open the app until this is added — needs a rebuild to take effect.

Add under `com.apple.developer.associated-domains` in `ios/Runner/Runner.entitlements`:
```xml
<string>applinks:api.studio-3.co</string>
```

## 1.5 — If you'd rather skip Xcode's GUI

`flutter build ipa` produces the same archive from the terminal, but the upload step still
needs either an `ExportOptions.plist` (none exists in this repo) or the Organizer — so for
occasional builds, the Xcode path above is genuinely less to remember, not just the default.
Worth automating with `fastlane` only once uploads happen often enough to be annoying by
hand.

---

# Part 2 — Android

## Current state (verified)

| | |
|---|---|
| Application ID | `com.studio3.discover` |
| `google-services.json` | **Present** — Firebase/push already works on Android |
| Release signing | **Using the debug key** (`android/app/build.gradle.kts:44`) — must be fixed before the first real release |
| Release keystore | **Does not exist anywhere in this project** |
| `ANDROID_CERT_FINGERPRINTS` (backend) | Only the debug keystore's fingerprint — Android App Links will not verify for a Play Store install until the real release fingerprint is added |

## 2.1 — Generate the release keystore (do this once, ever)

```bash
keytool -genkey -v -keystore ~/studio3-release.keystore \
  -alias studio3 -keyalg RSA -keysize 2048 -validity 10000
```

You'll be prompted for a keystore password, a key password, and your name/organization
details. **Back up the resulting file immediately** — Google Play requires every future
update to this app be signed with the same key. Lose it, and the only recovery is
publishing as a brand new app listing, losing all reviews, install counts and the existing
URL.

Get its SHA-256 fingerprint (needed for step 2.4 and later for `ANDROID_CERT_FINGERPRINTS`):
```bash
keytool -list -v -keystore ~/studio3-release.keystore -alias studio3 | grep SHA256
```

## 2.2 — Store the keystore credentials outside git

Create `android/key.properties` (this file must **never** be committed — confirm it's
covered by `.gitignore`, it is not present in the repo today so nothing to check against
yet):

```properties
storePassword=<the keystore password from step 2.1>
keyPassword=<the key password from step 2.1>
keyAlias=studio3
storeFile=/Users/sahil/studio3-release.keystore
```

## 2.3 — Wire it into the release build

`android/app/build.gradle.kts` currently has, near the top:
```kotlin
buildTypes {
    release {
        // TODO: Add your own signing config for the release build.
        // Signing with the debug keys for now, so `flutter run --release` works.
        signingConfig = signingConfigs.getByName("debug")
```

This needs to change to load `key.properties` and define a real `release` signing config,
then point `buildTypes.release.signingConfig` at it instead of `debug`. This is a code
change to a tracked file — **not done as part of this document**; ask for it explicitly
when you're ready, since it needs the keystore from §2.1 to already exist.

## 2.4 — Build the release bundle

Once §2.3 is done:
```bash
flutter build appbundle --release
```
Produces `build/app/outputs/bundle/release/app-release.aab`. Play Store wants the `.aab`
(App Bundle), not a bare `.apk`.

## 2.5 — Play Console setup (first time only)

1. **play.google.com/console → Create app** — name, default language, app/game type,
   free/paid
2. **Store listing** — description, screenshots per device type, feature graphic, app icon,
   category, contact details, **privacy policy URL (required)**
3. **Data safety form** — declares what data is collected and why; Google checks this
   against the app's actual behavior, so keep it accurate rather than conservative
4. **Content rating questionnaire**

## 2.6 — Upload and release

1. **Play Console → Release → Testing → Internal testing** (recommended first pass) or
   **Production** directly
2. **Create new release** → upload the `.aab` from §2.4
3. Review the release notes and rollout percentage, then **Submit for review**
4. Review is typically a few hours to a few days for a first submission; usually faster for
   updates

## 2.7 — After the first upload: fix the deep-link fingerprints

Two SHA-256 fingerprints need to reach `ANDROID_CERT_FINGERPRINTS` (comma-separated) in the
backend's environment, or Android App Links (opening a shared piece/event link directly in
the app) will silently fail for anyone who installed from the Play Store:

- **The release keystore's own fingerprint** — from §2.1
- **Play App Signing's re-signing key** — Google generates this automatically after your
  first upload if Play App Signing is enabled (the default and recommended setting); find
  it under **Play Console → Setup → App integrity → App signing**

Update `ANDROID_CERT_FINGERPRINTS` wherever the backend's production environment is
configured, comma-separated with the existing debug fingerprint if you still need debug
builds to verify too.

---

# Before either submission — worth deciding now

This is a **live marketplace with real Stripe payments**. Both Apple and Google reviewers
may attempt to complete a purchase. Decide, before submitting either:

- Are you submitting with **Stripe test mode still active**, or is this the point where you
  switch to live keys? A reviewer hitting an obvious test-mode checkout can read as broken
  rather than sandboxed.
- If staying in test mode for review, say so explicitly in the App Review notes (iOS) and
  consider a note in Play Console's review section too, so a reviewer isn't confused by
  test card behavior.
