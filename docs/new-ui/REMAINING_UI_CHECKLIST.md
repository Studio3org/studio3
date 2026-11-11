# Remaining new UI work: checklist

What is left to bring the app (`ui/redesign`) in line with the Claude Design canvas
(https://claude.ai/artifact/NEtHnqo1pkDKxSnyFCu6xx, version `1793027199-9db5`), its dev notes and
the design rules (`HandoffRules`, `HandoffSizes`). Checked on 2026-10-26 by diffing every board and
note on the canvas against `docs/new-ui/reference/` and the code.

- The local copies in `docs/new-ui/reference/` now match the canvas (98 boards and notes were new
  or changed and have been refreshed).
- Details for each board live in `NEW_UI_EXECUTION_PLAN.md` (these boards are its Phase 13); server work lives in
  `BACKEND_CHANGES.md` (B-numbers below). Tick items here as they land.
- Tags: **[quick]** small change to a built screen · **[build]** new screen or large rework ·
  **[B##]** waits on that backend item · **[decide]** needs a product or design answer first.

---

## 1. Decisions needed first

- [x] **[decide] Sign-in wall.** `HandoffAccount` and `NoteSignInFirst` require an account before anything
      else, and the canvas archived the guest boards. Built 2026-10-26 (section 3.1) behind one switch,
      `kAccountRequired` in `utils/app_routes.dart`, which brings guest browsing back if App Store review
      asks (guideline 5.1.1(v)). `HandoffPipeline` still lists it as a counsel question.
- [x] **[decide] "See fees" link.** Settled by `NotePostAvailFixed` ("a See fees link to the seller terms"):
      it opens the in-app Terms page (2026-10-26). A dedicated fees page can replace it later.
- [ ] **[decide] Edit profile extras.** The app has Pronouns and Pinned banner; `EditProfile` doesn't.
      Keep or drop.
- [ ] **[decide] Events "Near me".** It uses no location (shows everywhere). Filter by the phone's
      position, or rename.
- [ ] **[decide] `NotifAsk`, `NotifBanner`, `MessagePiece`, `CollectedBadge`.** Still parked in plan
      section 20 (flow changes). Confirm they stay out, or schedule them.
- [ ] Close answered questions: D4 (the canvas settles "€1,000 per parcel"), D10 (the insights card
      was dropped from `ProfileOwn`; Insights is its own page). `BuyAddress` button copy is still open
      (Ask Abott).

## 2. Quick fixes on built screens (the canvas changed after they were built)

### Home feed
- [x] `Main` gallery layout (canvas update, done 2026-11-07): pieces inset in the 16 margins, the label
      under each piece (name, title and year; medium and the Available / Collected chip; no photo,
      no price), 52 between posts. Plan 0.3 row "`Main` gallery layout".
- [x] Rounded photo corners (12) for pieces and Scenes, and a top bar that slides away scrolling
      down and back scrolling up (user's call, done 2026-11-08). Plan 0.3 row "Home feed corners and
      top bar".

### Profiles (canvas update, 2026-11-08)
- [x] `ProfileOwn` cover: the Settings gear in place of More, and for a seller the Insights chart
      44 to its left (opens the Insights page Settings › Insights opens). Plan 0.3 row
      "`ProfileOwn` cover icons".
- [x] `ProfilePrivate` / `ProfileRequested`: no zero counts; "N following", the bio and the stats
      only when the server sends them; Follow (or the outlined Requested) fills the row, Message only
      when they take messages from everyone; the new lock panel and its two lines. Plan 0.3 row
      "`ProfilePrivate` / `ProfileRequested`".
- [x] Tabs as the boards (user's call, done 2026-11-08): Pieces, Scenes, Collection for everyone; the
      Series shelf inside Pieces (cards open their series, See all opens all of them); no Series or
      Collect tab; Pieces is the board's layout for everyone; empty tabs show nothing. Plan 0.3 row
      "`ProfileSeller` tabs".
- [x] Collection = what they bought (D9 closed 2026-11-08, BACKEND_CHANGES B37): plain 3:4 tiles,
      title and artist, no price; a collector with no pieces opens on it. Plan 0.3 row
      "`ProfileCollector` Collection tab".
- [x] **[B36]** The locked profile's following count, bio, cover, stats and message setting from the
      server (built 2026-11-08), and the artists stat for collectors.
- [ ] **[build] [backend]** `Insights` page (7 days / 30 days / All time, Earned, saves · new
      followers · collected with changes, Most saved, Events): needs per-period numbers from the
      server; not scheduled.

### The phone's back button
- [x] As on Instagram (user's call, done 2026-11-08): other tabs → Home; on Home the first back goes to
      the top and refreshes, the next closes the app; posting a piece, Scene or event asks before back
      leaves it. Plan 0.3 row "The phone's back button". Recheck on an Android phone.

### Inbox
- [x] No Requests tab (user's call, done 2026-11-08, as on Instagram): Activity and Messages; Follow
      requests is the first row of Activity (the newest photo, a count bubble, "@newest + N others"),
      opening the Follow requests list. Plan 0.3 row "`NotifActivity` tabs".

### Saving and the Scene viewer
- [x] Save as on Instagram everywhere (user's call, done 2026-11-08): saves at once, "Added to
      Collection" with "Save to collection" → the folders and New collection; events in folders
      (BACKEND_CHANGES B35). The Scene viewer's rail is Like, Comments, Save, Share. Plan 0.3 rows
      "`SceneViewer` likes" and "Saving".

### Piece page
- [x] No Like or Comment on a piece (user's call, done 2026-11-07): double tap the image to like or
      unlike, a heart burst, and a "Double tap to like" hint on each visit that fades. Scenes
      unchanged. Plan 0.3 row "Piece page likes and comments".

### Posting and listing
- [x] **[quick]** Iridescent frame (5 px, radius 20, slow shift; still under reduced motion) around
      the preview on `PostSuccess`, `ListDone`, `PostNFSDone`, `ScenePosted`, `ScenePhotoPosted` —
      `widgets/create_flow/post_result_views.dart` (`_FeedPreview`, the Scene preview). Update the
      "Collected chip only" doc on `StudioIridescent`.
- [x] **[quick]** "Not for sale" as plain 13/500 text, never a chip: `screens/piece_detail_page.dart`
      and `post_result_views.dart` (`PieceNotForSale`, `PostNFSDone`).
- [x] **[quick]** `PostError`: the ! ring, the ! and "Couldn't publish" in red (`c.alert`); the
      explanation stays grey.
- [x] **[quick]** Earnings line: "You'll receive $2,880 after the 20% fee. See fees", the account's own
      rate, never "founding artist"; the ⓘ becomes the link — `create_flow/post_availability_step.dart`
      (`_EarningsLine`; used by `ListPricing` and `PostAvailFixed`). Needs the "See fees" decision.
- [x] **[quick]** `PostNFSDetails`: drop "What collectors see on the piece page." when not for sale
      (`listing_details_form.dart`); `PostNFSDone`: drop "Here's how collectors see it in the feed."

### Buying and bidding
- [x] **[quick]** Order summary says "Sales tax" in fixed-price checkout too
      (`piece_detail/collect_piece_sheet.dart`).
- [x] **[quick]** `BidPaymentFailed`: the ! ring, the ! and the title in red (`screens/auction_flow.dart`).

### Events
- [x] **[quick]** Time zone on every event time ("8:00 PM CST"): add it in `eventStartLabel`
      (`widgets/events/event_tickets_sheet.dart`), which feeds the tickets sheet, checkout, You're going,
      the ticket and Your events. (The zone comes from the phone today; from the location is B28.)
- [x] **[quick]** `EvCheckout`: no service fee for buyers — remove the Service fee line and its wording
      (`screens/event_checkout_page.dart`, `models/event_order.dart`); update B22's quote shape.
- [x] **[quick]** `EvChooseTickets`: "tax added at checkout" (was "tax and fees included").
- [x] **[quick]** `EvDetail` bar: "Tickets" with the range ("Free", "Free to $25", "$10 to $25") instead
      of "From" + lowest; compact time range "8:00 – 10:00 PM CST".
- [x] **[quick]** `EvDetail` pieces: "Pickup at the event" or "Ships after the event" on each piece
      (`deliveryMode` is already on `EventLineupItem`).

### Docs to bring up to date (plan section 0.3 and elsewhere)
- [x] Rows contradicted by the canvas, updated 2026-10-26 with 17.1: `BuyPiece` Follow, `PostAvailFixed`
      founding wording, `PostError` "no red", `EvChooseTickets` wording, `EvCheckout` fee, `EvDetail` date line.
- [ ] Rows still to update when their work lands: `ProfileOwn` insights / D10, `SignIn3Profile` steps,
      `SignInFirst` "Look around first", `EvSoldOut` "no waitlist at launch".
- [x] Plan reordered into execution order (2026-10-26): Events and hosting are Phases 11 and 12, the boards
      added to the canvas later are Phase 13, cleanup is Phase 14; Out of scope (section 20) keeps only
      what is still out.
- [x] `TRACKER.csv`: rows for the 20 new boards added and stale "Not started" statuses corrected from the plan (2026-10-26).

## 3. Screens to build or rebuild

### 3.1 Account (Flow 1 updates)
- [x] **[build] [decide]** `SignInFirst` / `SignInFirstDark`: email first; no "Look around first", no legal
      line; a new address → code → profile, a known one → `LoginPassword` — `login_page.dart`,
      `signup_page.dart`, `main.dart` (`AuthGate`).
- [x] **[build]** `SignIn3Profile`: Password (8+, eye) and the unticked Terms and Privacy checkbox on the
      profile step; no confirm field, no marketing switch; Continue grey until both are valid. When and
      which versions were agreed to is stored (B30, 2026-11-07).
- [x] **[build]** Remove guest browsing once the wall is in: the sign-in prompt sheet (`utils/require_login.dart`,
      `SignIn1Sheet`), the guest Saved / Profile placeholder (`ProfileSignedOut`), the signed-out paths in
      `main.dart` (`AuthGate`); the welcome toast (`SignIn5Done`) is kept (decided 2026-10-28, plan 17.9). All three boards are archived.
- [x] **[build] [B30]** `LoginPassword` (built; the code login and the lock built 2026-11-07): "Welcome back", password, Forgot password?, "Email me a login code
      instead", lock after five wrong tries.
- [x] **[build] [B30]** `LoginReset` (the code reset built 2026-11-07; the emailed link stays for a server that can't tell a known email): reset by the 6-digit code on the shared code screen, one "New
      password" field, "Save and log in" — `forgot_password_page.dart`.
- [x] **[build]** `EditProfile` (Mediums waits on B31): Cancel (asks when there are changes) / Save; pencil badges; Bio with a
      Mono "56 / 150" count and 150 limit; "once every 30 days" under Username; Website (already on
      `UserProfile`); Mediums for sellers **[B31]** — `edit_profile_page.dart`.
- [x] **[build] [B31]** `ProfileSeller`: up to three mediums under the username ("Painting · Mixed media"); Edit
      profile's Mediums row for sellers (done 2026-11-08).

### 3.2 Seller setup (Flow 11, `HandoffSeller`) — new
- [x] **[build]** `SellerPrompt` (built 2026-10-27; on events it shows for selling your own piece until paid tickets exist): "Turn on selling first" sheet (Set up seller profile / Post it as not for
      sale instead; the draft is kept) in place of `seller_mode_required_dialog.dart`; also when a paid
      ticket type is added (B22).
- [x] **[build]** `SellerIntro`: "Sell your work on Studio 3" (Stripe, studio, "Selling fees apply",
      seller terms, Get started); also from Settings → Seller profile → Turn on.
- [x] **[build]** `SellerStripe`: board copy over `payout_setup_page.dart`; "Finish later", and a
      "Seller profile: setup not finished" row in Settings.
- [x] **[build] [B31]** `SellerStudio` (built with City only; street / ZIP / notes wait on B31): "Stripe verified", private street / city / ZIP / pickup notes;
      what Stripe still needs.
- [x] **[build]** `SellerDone`: "You can sell now" → Back to your draft (Fixed price or Auction still chosen)
      / Go to your profile.

### 3.3 Posting (Flow 4 / 5 additions)
- [x] **[build]** `PostCreate` (built 2026-10-27): the "What are you sharing?" sheet on + (Piece "up to 4 angles", Scene
      "Process, studio, or anything else", Drafts row with a count) — `post_share_type_sheet.dart`
      exists but + skips it (`main.dart` `_openPost`).
- [x] **[build]** `PostPicker` (built 2026-10-27): light "New piece" picker, Close / Next, 3 across, numbered picks with an
      Ink outline, Mono "2 of 4 selected", Close asks to discard — `post_gallery_picker.dart`, `post_page.dart`.
- [x] **[build] [B33]** `Drafts` (piece drafts built 2026-10-27; Scene drafts, the edited time and the failed line on every phone built 2026-11-07; reopening the posting flow at the step stays out, see plan 0.3): All / Pieces / Scenes, "Didn't publish. Tap to try again." in red, what's
      left, Mono type and time, swipe to delete, resume at the saved step; `PostError` "Go to drafts"
      opens it (piece drafts can ship first; Scene drafts need B33).

### 3.4 Scenes
- [x] **[build]** `SceneViewer` (built 2026-10-27; save count, linked pieces and the Scene's own link built 2026-11-07, B33): no likes; Save and Comments with Mono counts (Scene save count is
      **[B33]**); Share back on; the linked-piece line (thumbnail, title, price, arrow); progress line;
      2-line caption — `widgets/reels/reel_overlay.dart`, `reel_player_page.dart`. Bug: the comment count
      starts at 0 instead of `post.commentCount` (`reel_overlay.dart`).
- [x] **[build]** `SceneViewerPhoto` (built 2026-10-27; photo Scenes now open here): photo Scenes in the viewer, centred over a blurred copy, dots between
      photos, "2 linked pieces" (they open `piece_detail_page.dart` today).
- [x] **[build]** `ScenePiecesSheet` (built 2026-10-27): the linked pieces sheet from the viewer; Follow on the viewer is solid
      white with Ink text.
- [x] **[build]** `SceneComments` (built 2026-10-27; delete and comments off built 2026-11-07, B33): the list sheet over the playing Scene ("Comments 18", Artist label,
      Reply fills "@name", no comment likes, report or delete on long-press) — reuse
      `piece_comment_sheet.dart`; the artist deleting any comment / turning comments off is **[B33]**.

### 3.5 Sold piece page (`PieceCollected*`)
- [x] **[build]** `PieceCollected` (everyone; built 2026-10-27): the full-width iridescent Collected bar and Message the artist;
      no price — `available_piece_detail_page.dart`, `AvailableCollectBar`.
- [x] **[build] [B32]** `PieceCollectedOwner` (collector; built 2026-10-27 from the order in Orders; arrival window, On time and Hide wait on B32): delivery card (arrival window, On time / Delayed,
      4-step tracker), Message, "Hide from my Collection".
- [x] **[build] [B32]** `PieceCollectedArtist` (artist; built 2026-10-27 from the sale; pickup date waits on B32): "Your work", pickup card ("Pickup Nov 5 · In 3 days"),
      Pack it for pickup, See shipping steps.

### 3.6 Browse
- [x] **[build]** `SeriesPage` (built 2026-10-27): the series page to the board (`series_view_page.dart` is in the earlier look;
      Home's series row opens it).
- [x] **[build]** `BehindTheWork` (built 2026-10-27): the See all page for Explore's Behind the work shelf.
- [x] **[build] [B27]** Explore "Upcoming shows" shelf and the profile "Upcoming show" card (built 2026-11-07,
      with the server side; Home also takes its event card from the feed).
      `flow_discover_test.dart`, `flow_profiles_test.dart`, `home_feed_flow_test.dart`.
- [x] **[B29]** (built 2026-11-07) Home: photo dots and series rows from the real feed; the series card's Available chip and
      photo count; a personalised order; a server-side Available filter.

### 3.7 Events
- [x] **[build] [B22]** Waitlist (app side built 2026-10-27; switches on when B22 sends `waitlist`): `EvSoldOut` bar "Tickets: Sold out" + Join waitlist / "You're on the
      waitlist"; `EvWaitlistJoin` (grey sold-out cards, "Want" − / +, no prices); `EvWaitlistHeld` (red Mono
      countdown, Continue to payment, "Keep waiting for [type]"); "On waitlist" in Your events; the host's
      waitlist count. Rules (`EvWaitlistRules`: 2 h / 30 m / 10 m holds, first come first served, closes at
      the start) go into B22.
- [ ] **[build] [B22]** Paid tickets: ticket types and prices, checkout with Stripe, refunds, per-ticket codes
      (`EvChooseTickets`, `EvCheckout`, `EvTicket`, `HostTickets`, `HostEditTicket`).
- [ ] **[B28]** `HostConflict` is archived: the "already listed" question moves to the artist's `ArtistPieceRequest`.
      Until B28, `showHostConflictDialog` stays for a host selling their own listed piece.
- [ ] **[build] [B28]** `HostAge` and the "21+ · Bring your ID" lines; `HostReschedule`; `HostScanner`
      (also B22); `ArtistInvite`, `ArtistPieceRequest`; time zone from the event's location.
- [ ] **[build] [B25]** Add to Apple Wallet on the ticket.

### 3.8 Bidding
- [ ] **[build] [B20]** `BidSecondChance` ("Accept and pay" now charges the saved card right
      away). Auction details in lists ("Bid $1,300 · 6h left") are B21.
- [x] **[build] [B38]** The artist's own auction (canvas update 2026-11-09):
      `ArtistAuctionLive` (YOUR AUCTION, the bids as Bidder N, Share auction, End auction
      early; More holds Edit piece and Cancel auction before the first bid),
      `ArtistAuctionEnd` (End this auction?), `ArtistAuctionPayment` (the winner's deadline and
      the next bid), `ArtistAuctionUnsold` (why, the interest, Relist as an auction / Sell at a
      fixed price / Keep it as not for sale). `widgets/auction/artist_auction.dart`,
      `artist_auction_test.dart`
- [x] **[quick]** Copy from the same update: `BidVerify` "Before you bid" with the card boxed and
      Ship to (a saved address) in place of the ZIP; `BidSheet` and `PostAvailAuction` shorter
      reserve tooltips; `BidReserveNotMet` "Bids didn't reach the artist's minimum. Nothing was
      charged."; `BidPaymentFailed` "Still yours. Update your card in time or it goes to the
      next bidder." (no hour count: the server's window is 48 hours, the design's 12)
- [ ] **[on hold, payments]** Winners charged automatically with no checkout, Apple Pay on the
      card sheet, the new fine print, 12 hours to fix, second chance: B20's second table

### 3.9 Settings (Flow 12, `HandoffSettings`) — new, added 2026-11-06

Plan section 17.10; server needs in BACKEND_CHANGES B34 (payment and shipping parts on hold).

- [x] `Settings` (2026-11-06): rebuild `profile_settings_page.dart` to the board (Account, Selling, Buying,
      App, Help; Log out and red Delete account; app version); Start selling for non-sellers
- [x] `SettingsAccount` (2026-11-06): name, email (code first), phone, password, log out of all devices
- [x] `SettingsSelling` (2026-11-06; address waits on B31): seller profile on, studio address (B31, on hold), seller terms, turn off
      seller profile (B34)
- [x] `SettingsSales` (2026-11-06; chips and tickets wait on B22): All / Art / Tickets, next step in red when it's the seller's move
      (tickets: B22, on hold)
- [x] `SettingsPurchases` (2026-11-06; chips and tickets wait on B22): the same for orders, auction wins and tickets (tickets: B22, on hold)
- [x] `SettingsPayment` (2026-11-06; default card on hold): saved cards and default, shipping addresses and default (default card:
      on hold)
- [x] `SettingsPrivacy` (2026-11-06; Private Collection B34, Hidden pieces B32): private account, follow requests, who can message you, Private
      Collection (B34), see your profile as others do, hidden pieces (B32), blocked accounts
- [x] `SettingsFollowRequests` (2026-11-06; going public approves from the app until B34): approve and decline; going public approves everyone (B34)
- [x] `SettingsDelete` (2026-11-06; list built in the app until B34): what's in progress, grey until done, type DELETE (B34)

## 4. Cleanup and release (plan section 18, Phase 14)

- [ ] Old token files deleted (`auth_palette`, `home_feed_tokens`, `explore_tokens`, `collect_detail_tokens`,
      `chat_tokens`); `follow_button.dart` still uses `home_feed_tokens` and Inter — move it to `StudioButton`.
- [ ] Restored-but-unused files (plan 12.2 list): delete or keep; `event_lineup_section.dart` is unused.
- [ ] Hard-coded colours outside theme files (about 100 files still match; many are allowed).
- [ ] `git rm -r --cached app/.chrome-pd ios/build` (needs your go-ahead).
- [ ] Theme switch QA (plan Phase 2) and the backend theme field deployed before review.
- [ ] Store screenshots refreshed; release signing (`android/key.properties`) on the build machine.
- [ ] `flutter analyze` clean (2026-10-28: no errors; 4 old warnings, the unused "Ask about this piece" code
      in `piece_detail_page.dart` and `available_piece_detail_page.dart`) and the full suite green
      (2026-10-28: 715 passed, 102 golden tests skipped).

## 4b. Per-screen acceptance (plan 19.1)

- [x] Every board screen checked (2026-10-28): `checkAcceptance` after each of the 64 goldens (tap targets
      44 × 44, labels, text only in theme colours), and the Phase 13 screens in every size, theme and text
      set-up (`acceptance_19_1_test.dart`). Write-up: `ACCEPTANCE_19_1.md`. All passing.
- [x] Fixed: `StudioTapArea` (44 × 44 without moving anything) across shared buttons, chips, fields, links,
      tabs and switches; inline links marked as links; missing labels; two off-palette text colours; the
      picture placeholder; date-dependent goldens pinned with `appNow()`; the waitlist golden renamed.
- [x] Light tertiary darkened to #6D6D6D so it reaches 4.5:1 (decided 2026-10-28); goldens regenerated.
- [x] System text capped at 2.0 (decided 2026-10-28, `main.dart`); every screen wraps up to 2.0.
- [x] Pixel rule measured on layout (decided 2026-10-28): 32 of 88 boards with a golden under 2 %;
      the tracker reads "layout X% (frame Y%)". `node tool/new_ui/board_masks.mjs` then
      `python -I tool/new_ui/layout_diffs.py` re-measures.
- [ ] Boards still over 2 % on layout (list in `ACCEPTANCE_19_1.md`): bring the goldens' data in line with
      the boards where the difference is data, not design.
- [ ] ScenePhotoEdit: the Adjust step draws a wide frame for a portrait photo (a regression from before
      this run).

## 4c. Backend entries built in both repos

- [x] B6 piece title and picture in notifications; B7 bundled saves and follows with the daily
      summary and its setting; B8 mute a conversation; B9 the piece a chat started from
      (2026-10-28; backend `6009f82` and `e58fc34` on development). Details and the open deploy
      boxes (integration run on `studio3_test`, migrations 043 and 044, redeploy Celery beat) in
      `BACKEND_CHANGES.md`.
- [x] B10 search message text (2026-10-28; backend `3709eef`, app `0fbfe5d`):
      `GET /api/conversations/search` and the Messages search using it.
- [x] B11 video messages (2026-10-29; backend `d0f59a1`, `2d32975`): videos with a poster in
      chats, the size limits held at presign, the video bubble and full-screen player. Migration
      045 and the `AWS_REGION` check before deploy (`BACKEND_CHANGES.md`).
- [x] B12 saved pieces and artists you follow (2026-11-01; backend `44e09cd`, app `40a0d5f`): the
      four notification types, the two Settings switches and their Activity rows.
- [x] B14 buyer and seller types, shipping types, event reminders (2026-11-01; backend `1afc3dc`, app `18f9079`):
      `sale`, `order_shipped` / `order_delivered`, `event_reminder`, in their Settings switches.
      Migration 046 and a Celery beat redeploy before deploy (`BACKEND_CHANGES.md`).
- [x] B15 delete a series (2026-11-02; backend `f4d55dc`, app `734774f`): `DELETE /api/series/<id>`
      and Delete series on Edit series, asking first; the pieces stay on the profile.
- [x] B16 the auction follows PATCH (2026-11-05; backend `eb1d20b`, app `bef2731`): created, its
      terms updated, opened and cancelled with the listing; List later offers Auction.
- [x] B17 save count on your own piece (2026-11-05; backend `fbe306d`, app `7e8e51f`): Saved by on
      the owner's bar, "[N] people saved this" line, and `ListDone`'s "We let the [N] people who
      saved it know."
- [x] B18 the viewer's own bid (2026-11-05; backend `8e793af`, app `3372383`): `myTopBidCents` /
      `myBidStatus` on piece detail, before and after the close; Outbid and "Your top bid" from any
      phone.
- [x] B21 auction fields in lists (2026-11-05; backend `683bb40`, app `bcfe4f9`): bid, bid count
      and end time on feeds, grids, Saved and collections; Saved shows "Auction ends in 6h" and
      "Bid · 6h left".
- [x] B23 Events tab on the server (2026-11-05, not committed): Featured (admin pick), city,
      search and range on browse and list, and the Near me cities. Migration 047.

## 5. Before release: flow regression on a device, in light and dark (plan 19.2)

- [x] Report and block (piece, scene, comment, profile, chat) (automated 2026-11-06: `test/new_ui/flow_report_block_test.dart` and `flow_reels_test.dart`; recheck on a device)
- [x] Piece page → collect → address → shipping → payment → confirmation (automated 2026-11-06: `test/new_ui/flow_collect_test.dart`; recheck on a device, with real payments once Stripe is wired)
- [x] Post a piece (for sale and not for sale) (automated 2026-11-06 in light and dark: `test/new_ui/post_flow_e2e_test.dart`; recheck on a device)
- [x] Post a scene (photo and video) (automated 2026-11-06 in light and dark: `test/new_ui/post_flow_e2e_test.dart`; recheck on a device)
- [x] Saved and collections (automated 2026-11-06 in light and dark: `test/new_ui/flow_saved_test.dart`; recheck on a device)
- [x] Inbox: notifications, follow requests, chats, conversation (automated 2026-11-06 in light and dark: `test/new_ui/flow_inbox_test.dart`; recheck on a device)
- [x] Profiles: own, other, private (automated 2026-11-06 in light and dark: `test/new_ui/flow_profiles_test.dart`; recheck on a device)
- [x] Settings incl. theme switch and delete account (automated 2026-11-06 from light and dark: `test/new_ui/flow_settings_test.dart`; recheck on a device)
- [x] Log out, log back in: theme restored from the account (automated 2026-11-06 both ways: `test/new_ui/flow_logout_theme_test.dart`; recheck on a device)
- [x] Home feed filters and pagination (automated: `test/new_ui/home_feed_flow_test.dart`)
- [x] Events: guest and host flows (automated: `test/new_ui/event_flow_e2e_test.dart`)
- [x] Guest browse → login prompt → login, as the sign-in wall plus the guest path behind `kAccountRequired`
      (automated, light and dark: `test/new_ui/flow_guest_login_test.dart`); recheck on a device
- [x] Sign up (all steps + terms) → onboarding (automated, light and dark: `test/new_ui/flow_sign_up_test.dart`);
      recheck on a device. Fixed: the welcome toast after onboarding never showed
- [x] Terms pop-up for an account created before the terms (automated, light and dark:
      `test/new_ui/flow_terms_prompt_test.dart`); recheck on a device
- [x] Discover search, chips, nearby sellers (automated, light and dark: `test/new_ui/flow_discover_test.dart`);
      recheck on a device
- [x] Reels (automated, light and dark: `test/new_ui/flow_reels_test.dart`, stand-in video player); recheck on a
      device, sound and playback especially. Fixed: Reels and Discover never loaded a second page
- [x] Like / save / comment / follow (automated, light and dark: `test/new_ui/flow_engagement_test.dart`);
      recheck on a device
