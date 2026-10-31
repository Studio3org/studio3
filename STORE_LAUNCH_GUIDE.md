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
| Release signing | **Done** — real keystore, wired into `android/app/build.gradle.kts`, first Play Console upload was rejected for being debug-signed; rebuilt and re-verified as release-signed |
| Release keystore | `android/app/upload-keystore.jks` (gitignored) — **back this up outside this machine now**, alongside `android/key.properties`. Lose it and there is no recovery: Play Store requires every future update signed with the same key. |
| `ANDROID_CERT_FINGERPRINTS` (backend) | **Still needs updating** — see §2.7. The live value today doesn't match this keystore, the old debug key on this machine, or anything else recognizable; it needs replacing regardless of its origin. |

## 2.1 — Generate the release keystore (do this once, ever) — ✅ done

Keystore: `android/app/upload-keystore.jks`, alias `upload`, RSA 2048, valid until 2056.

SHA-256 fingerprint (needed below and for §2.7):
```
1A:B8:04:3F:1D:FA:2E:66:46:DC:1C:08:C5:7C:5B:0B:52:FF:F6:CC:9C:83:04:86:91:9B:21:CA:36:B6:84:0D
```

**Back up the keystore file and its passwords (in `android/key.properties`) outside this
machine now** — a password manager or encrypted cloud storage. Google Play requires every
future update to this app be signed with the same key; lose it, and the only recovery is
publishing as a brand new app listing, losing all reviews, install counts and the existing
URL.

## 2.2 — Store the keystore credentials outside git — ✅ done

`android/key.properties` exists (gitignored, per `android/.gitignore`) with the store
password, key password (same value — modern PKCS12 keystores require store and key password
to match), alias `upload`, and the relative path to the `.jks` above.

## 2.3 — Wire it into the release build — ✅ done

`android/app/build.gradle.kts` now loads `key.properties` at the top, defines a `release`
signing config from it, and `buildTypes.release.signingConfig` uses it — falling back to
the debug key only if `key.properties` is absent (e.g. a fresh checkout on another machine
that hasn't been given the keystore), so `flutter run --release` still works there too.

## 2.4 — Build the release bundle — ✅ done

```bash
flutter build appbundle --release
```
Produced `build/app/outputs/bundle/release/app-release.aab`. Verified with `jarsigner
-verify -certs` that the embedded certificate is now `CN=Studio3`, not the debug cert.

Building this also surfaced a separate, one-time environment gap on this machine: the
Android SDK's command-line tools weren't installed, which made Flutter's post-build
"strip debug symbols" check fail even though the Gradle build itself succeeded. Fixed by
installing `cmdline-tools` from Google's official repository (checksum-verified) into
the SDK — nothing to redo here, just noting it in case a fresh machine hits the same thing.

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

## 2.7 — After the first upload: fix the deep-link fingerprints — one value ready, one still blocked

Two SHA-256 fingerprints need to reach `ANDROID_CERT_FINGERPRINTS` (comma-separated) in the
backend's environment, or Android App Links (opening a shared piece/event link directly in
the app) will silently fail for anyone who installed from the Play Store:

- **The release keystore's own fingerprint** — ready now, from §2.1:
  ```
  1A:B8:04:3F:1D:FA:2E:66:46:DC:1C:08:C5:7C:5B:0B:52:FF:F6:CC:9C:83:04:86:91:9B:21:CA:36:B6:84:0D
  ```
- **Play App Signing's re-signing key** — not available yet. Google only generates this
  after a *successful* upload with Play App Signing enabled (the default); every upload so
  far was rejected for being debug-signed, so this doesn't exist yet either. Come back for
  it under **Play Console → Setup → App integrity → App signing** once the newly
  release-signed `.aab` has actually been accepted.

The value currently live at `https://api.studio-3.co/.well-known/assetlinks.json` —
`1A:4D:84:7F:C4:FC:98:4C:9B:36:E1:68:DA:C9:B9:0A:23:B5:36:04:C0:42:0C:5A:B2:0F:05:D8:F4:26:01:29`
— matches neither this release key nor the debug key on this machine
(`6C:12:81:34:64:84:B7:00:E1:27:DC:41:0C:52:6E:0F:E9:CC:86:3E:F7:AB:6E:1F:77:8B:BE:68:D0:3F:CE:BD`),
so whatever set it, it needs replacing rather than appending to.

This is a production environment variable (`deploy/config.env` on the server, per
`deploy/config.env.example`), not a value in this repo — nothing here can set it directly.
Update it there once both fingerprints are in hand, comma-separated, plus the debug
fingerprint above if debug builds still need to verify too.

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
