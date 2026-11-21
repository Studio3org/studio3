# Studio 3: Apple launch checklist

What still has to be built or set before the iOS app can pass App Store review. Built from
"Studio 3 — Launch Checklist and Status" (Sahil Sinha, 17 Nov 2026) and checked against this
repo (`ui/redesign`) on 17 Nov 2026. The guideline numbers are Apple's App Store Review
Guidelines.

Tick a box when the item is done and checked. Items marked **(us)** are app code or repo
work; **(client)** items need the client's accounts or files.

## 1. App fixes we make (us)

Each of these was checked in the code; all are still open.

### 1.1 "Save Image" crashes: add the photo-saving permission text (Guideline 2.1)
- [x] In `ios/Runner/Info.plist`, add `NSPhotoLibraryAddUsageDescription` with:
      "Studio3 saves the QR codes you choose to your photo library." (done 17 Nov)
- [x] iPad: the share sheet needs an anchor there or it doesn't open. The QR codes page and
      "Download all" passed none; `QrImageShare` now falls back to the middle of the screen
      (done 17 Nov).
- [x] Tests: `test/new_ui/ios_launch_checklist_test.dart` checks the Info.plist texts and that one
      code and "Download all" send their PNGs with an anchor (5 tests; they fail without the
      fixes).
- [ ] Build, share a QR code, tap Save Image, and check it saves (needs a Mac and an iPhone).

Found: `Info.plist` had `NSPhotoLibraryUsageDescription` (read) but not the "add" key. "Save
Image" is the iOS share sheet's own option (the QR is shared through `share_plus` in
`lib/utils/qr_image_share.dart`), and iOS stops the app when it writes to Photos without that
key.

### 1.2 Stop the encryption question on every upload
- [x] In `ios/Runner/Info.plist`, add `ITSAppUsesNonExemptEncryption` = `NO` (done 17 Nov).
- [x] Checked it's true: the app's only encryption is HTTPS through iOS, plus the
      `cryptography` package used solely to verify the Ed25519 signature on ticket QR codes
      (`lib/services/offline_check_in.dart`). Authentication and signature checks are exempt;
      nothing is encrypted to keep it secret.
- [x] Test: `test/new_ui/ios_launch_checklist_test.dart` fails if the key goes missing or
      turns true.
- [ ] On the next upload, check App Store Connect no longer asks the encryption question
      for the build. If the app later adds its own encryption of data (not HTTPS, not
      signatures), revisit this.

Found: the key was missing, so every upload asked.

### 1.3 Privacy manifest (`PrivacyInfo.xcprivacy`)
- [x] `ios/Runner/PrivacyInfo.xcprivacy` written and added to the Runner target's Resources
      in `ios/Runner.xcodeproj/project.pbxproj` (done 17 Nov).
- [x] `NSPrivacyTracking` false, no tracking domains (no analytics, ads or tracking SDKs).
- [x] Collected data, all linked to the account, none for tracking, purpose App Functionality:
      name, email, phone, user ID, physical address, precise location (lat/lng is sent in
      full for nearby sellers and events), photos or videos, messages (chat), other user
      content (captions, comments), purchase history, payment info (through Stripe).
- [x] Required-reason APIs. Checked every iOS plugin: all but five ship their own manifest.
      Of those five, two call such APIs, now declared: UserDefaults `CA92.1` (`stripe_ios`)
      and file timestamp `C617.1` (`easy_video_editor` reads a video's creation date).
      `firebase_core`, `printing` and `flutter_wallet_card` call none.
- [x] `flutter_wallet_card` pulls in OpenSSL (on Apple's list of SDKs that need their own
      manifest and signature). Its code never calls OpenSSL; current OpenSSL-Universal 3.x
      ships both. `ios/Podfile.lock` doesn't list it yet, so the next `pod install` fetches it.
- [x] Tests: `test/new_ui/ios_launch_checklist_test.dart` checks the manifest's contents and
      that the Xcode project copies it into the app.
- [ ] On the Mac: `pod install`, then Product → Archive. In Organizer, right-click the
      archive → Generate Privacy Report, and check it lists the app's manifest plus each
      SDK's. Upload, and check Apple sends no "missing privacy manifest" or "missing API
      declaration" email (ITMS-91053 / 91061). If one names an API, add its reason here.
- [ ] When a plugin is added or updated, check whether it ships a manifest; if not, declare
      its required-reason APIs here.

Found: there was no privacy manifest in `ios/Runner/`.

### 1.4 "Privacy Policy" on sign-in must open the real policy (Guideline 5.1.1(i))
- [x] Checked the policy page works (17 Nov): `https://studiosthree.com/privacy` answers 200
      and its site defines a `/privacy` route with the full policy ("Third Place Studios LLC,
      d/b/a Studio 3 · Effective: July 2026"). The page is drawn by JavaScript, so it shows
      in any browser, but a tool that doesn't run scripts sees an empty page. Linked directly;
      no copy in the app.
- [x] One shared opener, `lib/utils/privacy_policy.dart` (`kPrivacyPolicyUrl`,
      `openPrivacyPolicy`): opens the policy in the browser, or shows "Could not open the
      browser." Settings → Privacy now uses it too.
- [x] Sign-up agreement (`AuthTermsCheckbox` in `lib/widgets/auth_ui.dart`): "Privacy Policy"
      opened the in-app Terms; it now opens the policy. Terms of Service still opens the
      in-app Terms, and tapping either link doesn't tick the box.
- [x] Legal line (`AuthLegalLine`, same file): "Privacy Policy" was plain text; now a link.
      Not on any screen today, fixed so it's right if it comes back.
- [x] Guest sign-in prompt (`lib/utils/require_login.dart`): "Privacy Policy" was plain text;
      now a link. The sheet stays open behind the browser.
- [x] Tests: `test/new_ui/privacy_policy_link_test.dart` (6: the URL, each link, Terms
      unchanged, the box untouched, the no-browser message). They fail with the old
      behaviour. The other sign-in, sign-up, settings and guest tests pass (119 + 5).
- [ ] On an iPhone (TestFlight): tap each "Privacy Policy" and check Safari shows the policy.

**Copy on studio-3.co (17 Nov, the user's ask).** studio-3.co is this repo's web app (`app/`,
on Vercel: the live page and assets match `app/dist`).
- [x] `app/public/privacy.html`: the studiosthree.com policy word for word (785 words,
      compared against the site's own source), "Effective: July 2026", contact
      `privacy@studio-3.co`. Plain HTML, no JavaScript, light and dark, the site's logo and font.
- [x] `/privacy` rewrite to `/privacy.html` above the catch-all in `app/vercel.json` and
      `app/vercel.static.json` (the one copied into builds).
- [x] The page and the rewrite also added to the committed builds `app/dist/` and
      `app/.dist/` (not rebuilt, so nothing else on the site changes).
- [ ] Deploy: commit and push to the branch Vercel deploys studio-3.co from, then check
      `https://studio-3.co/privacy` shows the policy (it redirects to www today).
- [ ] Then, if wanted, point the app at it: `kPrivacyPolicyUrl` in
      `lib/utils/privacy_policy.dart`, and the privacy link in App Store Connect.
- [ ] Keep both copies the same when the policy changes on studiosthree.com.
- Careful: the repo clean-up (1.9) removes `app/dist` from git. If Vercel deploys the
  committed `app/dist` (or `.dist`), that breaks the site. Switch Vercel to build from
  `app/` first.

The policy domain is studio**s**three.com; studiothree.com (no second "s") is a different
business.

### 1.5 iPhone and iPad (decided 17 Nov)
- [x] Decision: the app ships for iPhone **and iPad** (the user's call, 17 Nov). It was
      briefly switched to iPhone only the same day, then put back.
- [x] `TARGETED_DEVICE_FAMILY = "1,2"` in `ios/Runner.xcodeproj/project.pbxproj` (all three
      project configurations, which the Runner target inherits).
- [x] `UISupportedInterfaceOrientations~ipad` in `ios/Runner/Info.plist` keeps all four
      orientations, which iPad multitasking needs.
- [x] Tests: `test/new_ui/ios_launch_checklist_test.dart` checks both.
- [x] The QR share sheet opens on iPad (anchor fix, 1.1).
- [x] **iPad layout** (done 17 Nov, the least-work route): on a window wider than 600 pt
      the app keeps to a centred 600 pt column, margins in the page colour
      (`lib/widgets/wide_screen_column.dart`, wrapped around the Navigator in `lib/main.dart`,
      so pages, sheets, dialogs and toasts all sit in it). Inside it the screen size reads
      600 wide, and side safe-area insets inside the margins are dropped. Phones, and iPad
      windows 600 or narrower (Slide Over, narrow Split View), are untouched. The app's
      portrait lock is ignored by iPadOS for multitasking apps, so landscape iPad shows the
      same column, 1024 tall.
  - [x] Tests: `test/new_ui/wide_screen_column_test.dart` (10: phones and narrow windows
        untouched, iPad portrait and landscape column, insets, sheets inside it, margin
        colour in both themes).
  - [x] Every acceptance screen (`acceptance_19_1_test.dart`, 19 boards) now also runs at
        320 × 1024 (iPad Slide Over, narrower than any phone) and 600 × 1024 (the column in
        iPad landscape): nothing overflows or throws (38 runs pass).
  - [ ] Later, if wanted: real iPad layouts (wider grids, side panels). Needs design.
- [ ] Check every screen on an iPad (or the iPad simulator in Xcode): portrait, landscape,
      Split View and Slide Over. The automatic checks cover the 19 acceptance boards only.
      Look for anything that reads the device size directly instead of the layout, and for
      full-screen media (Reels, the image viewer, the code scanner) inside the column.
- [ ] Check the camera flows (posting a photo or video, the event code scanner) on an iPad.
- [ ] iPad screenshots for the listing (4.1).

### 1.6 Review notes for Apple's reviewer (Guideline 2.1)
- [x] Written fresh in `docs/new-ui/APP_REVIEW_NOTES.md` (18 Nov). The old
      `docs/APP_REVIEW_NOTES.md` the source doc names isn't in this repo. Every statement
      was checked in the app and the live server's code; the file lists the source of each.
  - [x] No "hold" line. Auctions: "Your card is checked and saved at your first bid. Nothing
        is charged unless you win." True to the server (auctions v2: a card check at the first
        bid, only the winner charged at close).
  - [x] Sections on event tickets, Apple Wallet, door check-in and shipping, plus payments
        (why not in-app purchase), user content and safety, account deletion, permissions,
        contact.
  - [x] Payments are live; checkout without a real charge: try every step up to the card
        sheet, or buy a $1 test piece that the seller cancels within 24 hours (full refund).
        Ticket test: a $1 refundable ticket the reviewer refunds from the ticket page.
  - [x] 2,865 characters, under App Store Connect's 4,000 limit.
- [ ] Before submitting: set up the $1 test piece and the $1 refundable test event, fill in
      `@[TEST SELLER]`, and remove or keep the Wallet sentence (section 1 of the notes file).
- [ ] Paste the notes into App Store Connect → App Review Information, with the `artist`
      login (password from the password manager, never in the repo) and a contact person.

### 1.7 Build number
- [x] `pubspec.yaml`: `version: 1.0.0+5` raised to `1.0.0+6` (18 Nov). iOS reads it as
      `CFBundleVersion` / `CFBundleShortVersionString` (`$(FLUTTER_BUILD_NUMBER)` /
      `$(FLUTTER_BUILD_NAME)` in `Info.plist`); Android as `versionCode` / `versionName`.
- [x] Checked it flows through: Android's generated `local.properties` now says
      `flutter.versionCode=6` (`flutter build apk --config-only`).
- [x] Test: `test/new_ui/ios_launch_checklist_test.dart` checks `Info.plist` takes both from
      pubspec and that the build number is at least 6.
- [ ] On the Mac, before Product → Archive: `flutter pub get`, `flutter build ios
      --config-only`, then `cd ios && pod install`, so `ios/Flutter/Generated.xcconfig` says
      `FLUTTER_BUILD_NUMBER=6` (it's git-ignored and still says 5 on this PC).
- [ ] If App Store Connect (TestFlight) or Google Play already has a build 6 or higher, raise
      it past the highest there. Each upload needs a new, higher number; the version name
      (1.0.0) can stay until release.

### 1.8 iPhone notifications (after the client sends the file, see 2.3)
- [ ] Add `GoogleService-Info.plist` to `ios/Runner` in Xcode (tick the Runner target).
      Found: not in the repo.
- [ ] Signing & Capabilities: add Push Notifications (puts `aps-environment` in
      `ios/Runner/Runner.entitlements`, which today only has associated domains).
- [ ] Add Background Modes → Remote notifications (`UIBackgroundModes` in `Info.plist`,
      missing today).
- [ ] On a real iPhone, send a test notification from Firebase.

### 1.9 Clean the repo (before anyone clones it for the build)
Found tracked in git: `app/.chrome-pd` 479 files (a browser profile, which may hold saved
passwords), `app/dist` 23, `ios/build` 296, `android/build/reports` 1.
- [ ] The owner of the browser profile changes the passwords saved in it.
- [ ] Back up the repo, then `git filter-repo --path app/.chrome-pd --invert-paths` and
      force-push (pick a time nobody is pushing).
- [ ] `git rm -r --cached ios/build app/dist android/build`, add `/android/build/` and
      `app/dist/` to `.gitignore` (`/ios/build/` and `app/.chrome-pd/` are already there),
      commit and push.
- [ ] Everyone clones the repo again.

### 1.10 Microphone text (check only)
- [ ] No `NSMicrophoneUsageDescription` in `Info.plist`, and no video recording was found in
      `lib/`. Add it only if Apple's upload email asks for it.

## 2. What the client must provide (client)

These block review or the features listed. Steps for each are in the source doc.

### 2.1 Before the first upload
- [x] Accept Apple's latest agreement (done 17 Nov).
- [x] Privacy policy live at `https://studiosthree.com/privacy` (done 17 Nov).
- [ ] Support page at `https://studiosthree.com/support` with `support@studio-3.co`
      (Guideline 1.5: a working support link is required).

### 2.2 Real content for the reviewer (Guideline 2.1, completeness)
The live app has only 2 artworks and none for sale; an empty app is a common rejection.
- [ ] 10 to 20 real pieces listed for sale by real artists.
- [ ] In the `artist` review account: one piece for sale, one running auction, one upcoming
      event with tickets.
- [ ] One order in that account (bought from a second account).
- [ ] As a new visitor, the home feed and Explore don't look empty.

### 2.3 Files and keys that switch features on
- [ ] iPhone notifications: APNs `.p8` key uploaded to Firebase, Push ticked on the app ID,
      `GoogleService-Info.plist` sent to us (then 1.8).
- [ ] Apple Wallet: Pass Type ID `pass.co.studio-3.ticket`, `pass.p12` and its password, Team ID.
- [ ] Website link file: `studio-3.co/.well-known/apple-app-site-association` must not redirect
      to www, and `REPLACE_WITH_TEAM_ID` becomes `5XVXDNBNKN`. Without this, the
      `applinks:studio-3.co` entry in `Runner.entitlements` doesn't open the app.

## 3. Already in line with the guidelines (checked)

- [x] Account deletion inside the app (5.1.1(v)): `lib/screens/delete_account_page.dart`.
- [x] Report and block people and posts (1.2, user content): `report_reason_sheet.dart`,
      `blocked_users_page.dart`.
- [x] Art and tickets paid through Stripe, not in-app purchase (3.1.3(e) and 3.1.5: physical
      goods and real-world events).
- [x] Permission texts present: camera, photo library (read), location while using the app,
      calendars.
- [x] The app builds for release on Flutter 3.50; all automatic tests pass.
- [x] The app uses the live server and live payments; the `artist` review login works.

## 4. App Store Connect listing (Guidelines 2.3 and 5.1.2)

### 4.1 Listing
- [ ] App name, subtitle, description, keywords.
- [ ] Screenshots from a 6.9-inch iPhone (1320 × 2868).
- [ ] Screenshots from a 13-inch iPad (2064 × 2752), since the app supports iPad (1.5).
- [ ] Support link (2.1) and privacy policy link.
- [ ] Age rating: user posts, chat and purchases, so expect 17+.
- [ ] Price Free; United States only (shipping and payouts are US only).
- [ ] Copyright: Third Place Studios LLC.

### 4.2 App Privacy answers
- [ ] Collected: name, email, phone, address, photos and videos, messages, purchases,
      location (only while using the app), payment info through Stripe.
- [ ] Also answer **User ID** and **Other User Content** (captions, comments). The source doc
      leaves these out, but the app collects them and the privacy manifest (1.3) declares
      them.
- [ ] Location: answer **Precise Location**; the app sends exact coordinates.
- [ ] Every type: linked to the user, not used for tracking, purpose App Functionality. Must
      match the privacy manifest (1.3).

## 5. Test the uploaded build on a real iPhone (TestFlight)

- [ ] Sign up, log in, log out, reset the password.
- [ ] Browse the feed and open pieces.
- [ ] Buy a piece; check the shipping price and order tracking.
- [ ] Place a first bid (card and shipping address).
- [ ] Buy an event ticket, open its QR code, refund it.
- [ ] Host an event: ticket types, publish, scan a ticket, reschedule.
- [ ] Accept an invite and approve a piece request.
- [ ] Share a QR code and tap Save Image (1.1).
- [ ] Tap "Don't allow" on each permission once; the app still works.
- [ ] Delete a throwaway account.
- [ ] One small real purchase with the client, then refund it.

## 6. Order

1. Now: app fixes 1.1 to 1.4 and 1.7, the iPad layout work (1.5), the review notes (1.6) and
   the repo clean-up (1.9). In parallel, the client publishes the support page and starts
   adding real artwork (2.1, 2.2).
2. Build and upload: Xcode → Product → Archive → Validate → Distribute to App Store Connect.
3. TestFlight pass (5).
4. Listing and privacy answers (4), then Submit for Review with the review notes and login.
5. When the client's files arrive: notifications (1.8) and Wallet. These can follow in an
   update if they aren't ready.
