# Section 19.1 acceptance run — 2026-10-28

The per-screen checks of `NEW_UI_EXECUTION_PLAN.md` section 19.1, run over every built screen.

Two test layers hold them:

- **Every board screen:** `checkAcceptance` (`test/new_ui/golden_harness.dart`) runs right after each board golden (64 of them, in 40 test files), on the board state with the board's data: tap targets ≥ 44 × 44, every tappable thing labelled, text only in theme colours. Run with `NEW_UI_GOLDENS=1 flutter test test/new_ui --plain-name golden`. Dark mode and the 375 / 440 sizes for these screens are in each phase's own QA tests.
- **Phase 13 screens, all set-ups:** `test/new_ui/acceptance_19_1_test.dart`, below, in every run of the suite.

## How it is checked

`acceptance_19_1_test.dart` opens each Phase 13 screen in five set-ups, with reduced motion on
throughout:

| Set-up | What it checks |
|---|---|
| 390 × 844, light | Tap targets ≥ 44 × 44, every tappable thing labelled, text only in theme colours |
| 390 × 844, dark | The same |
| 375 × 667 (SE), light, text 1.4 | Nothing overflows or throws |
| 390 × 844, dark, text 2.0 | Nothing overflows or throws (largest text the screens are held to) |
| 440 × 956 (Pro Max), dark | Nothing overflows or throws |

In every set-up: once settled, nothing keeps animating (reduced motion). A token test checks
text contrast in both themes from the colour values.

Screens: PostCreate, PostPicker, Drafts, SellerPrompt, SellerIntro, SignInFirst, LoginPassword,
LoginReset, EditProfile, SceneViewer, SceneViewerPhoto, ScenePiecesSheet, SceneComments,
PieceCollected (with the collector's card), SeriesPage, BehindTheWork, EvSoldOut (waitlist),
EvWaitlistJoin, EvWaitlistHeld. 96 checks, all passing.

## Results per check

| 19.1 check | Result |
|---|---|
| Note read line by line; built or logged | Done for every Phase 13 screen as it was built; each deviation is a row in plan 0.3 |
| Pixel diff under 2 % (section 0.4) | Measured on layout (decided 2026-10-28): the board's placeholder art and the page it draws behind a sheet are left out of both images (`tool/new_ui/board_masks.mjs`, `compare.py --mask`, `tool/new_ui/layout_diffs.py`). 32 of 88 boards with a golden are under 2 % on layout (15 on the whole frame). The tracker's "Pixel diff %" now reads "layout X% (frame Y%)". Over 2 %: below |
| Screenshot at 390 × 844 next to the board | Done for every board with a golden (side-by-sides in each phase) |
| Light and dark; contrast ≥ 4.5:1 | Pass. Light tertiary darkened from the boards' #8E8E8E to #6D6D6D (decided 2026-10-28; 4.5:1 on page, Surface and Card), so every text token reaches 4.5:1 in both themes except placeholder (#A3A3A3, hints and disabled controls), which is unchanged |
| 375 × 667 and 440 × 956 | Pass (no overflow, nothing hidden) |
| Reduced motion | Pass. Fixed on the way: the picture placeholder's spinner kept turning; it is now still when motion is reduced |
| Largest Dynamic Type | Pass. The app caps system text at 2.0 (decided 2026-10-28; `MediaQuery.withClampedTextScaling` in `main.dart`), and every screen wraps without clipping up to 2.0 |
| Tap targets ≥ 44 × 44; icon-only buttons labelled | Pass on every board screen after the fixes below |
| No hard-coded colours / fonts / radii | Every board screen: text only in theme tokens (or white / Ink on a picture). Fixed: Event confirmed's #555 venue line (now Body), the dark editors' greys (now `StudioColors.onDarkTertiary`, `onDarkOff`, `onDarkChipText`). App-wide, the section 18 clean-up item stays open for non-text colours and the old token files |
| Every action does what it did before | The behaviour tests (603+ in the suite) pass |

## Fixed in this run

- **44 × 44 tap targets without moving anything.** New `StudioTapArea` (`widgets/studio/studio_tap_area.dart`) lets a control answer taps, and VoiceOver / TalkBack, over 44 × 44 while it keeps the board's size. Used by the small button (34, Follow and Edit series everywhere), the filter chips (36), the underline fields (the label, value and underline all focus the field now), the password eye (44 × 32), the artist / host rows on the piece and event pages, the series page's artist, the Scene viewer's photo, Follow, caption and linked-piece line, the comment photo and field, the picker's album name, the sold piece card's step, and "New to Studio 3? Create an account".
- **Text links marked as links** (exempt from the 44 minimum): the commenter's name and Reply, the artist's name in the Scene viewer.
- **Made 44 tall** (they were 36 and 40 on the boards): "Keep waiting for [type]" on the held sheet, "Message Amara" / "See shipping steps" under the delivery card.
- **Labels:** the piece page's picture ("Open the picture"), the comment photo (the commenter's name), the Scene caption; the sheet backdrops on Choose tickets and the waitlist sheets no longer announce an unlabelled tap (the route's barrier says Close); Edit profile's cover leaves it to the labelled "Change cover photo".
- **Picture placeholder** (`FeedPicsumImage`): Surface while loading and when it fails, instead of hard-coded greys and a Material icon; no spinner when motion is reduced.
- **Golden name clash:** the waitlist's sold-out golden had taken `EvSoldOut.png`, the Phase 11 Save bar's; it is `EvSoldOutWaitlist.png` now and both are regenerated.

## Fixed in the second pass (all board screens)

- `StudioTapArea` on the shared search field (`PostPickerSearchField`: Messages, New message, mediums), the materials and Explore search fields, the message composer, `PostTextLink` ("View piece", "View Scene", "Edit"), `HostTextAction`, the host step tabs (42), the host lineup's price and "Link and QR code" (32), the Events tab's Today / This week / This month (32), Your events' button (36), the header actions on Related Scenes, New message and Edit series (43), the size fields when posting, the availability step's Edit, the photo editor's Size / Crop / Adjust tabs, `StudioSwitch` (26), and the feed card's photo.
- Marked as links: the feed card's artist name and title, and "Terms of Service" / "Privacy Policy" in the sign-up sentence.
- Labels: the feed card's picture ("Open the piece"), the series card, the Remember me and Terms checkboxes, the "Made with AI tools" switch.
- Dates in goldens: the screens that show "Today · 2:14 PM", "Mon" or "4h" read `appNow()` (`lib/utils/app_clock.dart`, the device clock) and their tests pin it, so Conversation, ConvMenu, NotifActivity, NotifMessages, Drafts and Main no longer drift with the real date; they and PostListLater and EvConfirmed are regenerated.

## Boards over 2 % on layout

Each differs for a reason already logged in plan 0.3, or because the golden's data is not the board's; the darker tertiary also counts as a colour difference wherever a board has tertiary text.

| Board | Layout | Frame |
|---|---|---|
| BehindTheWork | 47.86 % | 65.31 % |
| HostPieceQR | 44.70 % | 45.34 % |
| BidSheet | 44.08 % | 67.91 % |
| HostArtMode | 32.61 % | 33.55 % |
| HostDate | 27.37 % | 29.23 % |
| SceneViewerPhoto | 26.57 % | 30.70 % |
| ScenePhotoEdit | 24.47 % | 54.64 % |
| ScenePhotoEditSize | 24.37 % | 54.54 % |
| Conversation | 23.54 % | 31.10 % |
| BuyShipping | 22.05 % | 22.05 % |
| EvSoldOut | 18.38 % | 61.45 % |
| EditProfile | 18.26 % | 20.00 % |
| Main | 17.53 % | 73.72 % |
| PostAvailAuction | 15.88 % | 15.88 % |
| PostRelatedScenes | 13.19 % | 36.67 % |
| CollectConfirm | 13.07 % | 29.82 % |
| EvPast | 12.65 % | 69.14 % |
| BuyCheckoutEmpty | 12.21 % | 13.84 % |
| ConvMenu | 11.90 % | 18.86 % |
| SeriesNew | 10.53 % | 10.54 % |
| BidVerify | 10.13 % | 60.97 % |
| HostConflict | 8.60 % | 8.60 % |
| SeriesPage | 8.07 % | 38.81 % |
| PostListLater | 8.04 % | 52.48 % |
| SeriesPicker | 7.88 % | 7.89 % |
| PieceCollectedOwner | 7.78 % | 43.51 % |
| PieceCollected | 7.56 % | 43.28 % |
| PieceCollectedArtist | 7.55 % | 43.28 % |
| BuyAddress | 7.33 % | 7.33 % |
| EvTicket | 7.15 % | 8.59 % |
| SignInFirst | 7.10 % | 7.10 % |
| LoginReset | 6.02 % | 6.02 % |
| EvCheckout | 5.64 % | 6.88 % |
| HostLineup | 5.14 % | 8.36 % |
| NotifSettings | 4.96 % | 4.96 % |
| HostCancel | 4.85 % | 4.85 % |
| NotifActivity | 4.77 % | 8.57 % |
| HostTickets | 4.61 % | 4.61 % |
| HostEditTicket | 4.39 % | 4.39 % |
| EvTab | 4.31 % | 50.00 % |
| EvConfirmed | 3.86 % | 30.95 % |
| HostReview | 3.71 % | 3.71 % |
| EvChooseTickets | 3.65 % | 50.91 % |
| HostLive | 3.54 % | 20.50 % |
| HostManage | 3.35 % | 28.94 % |
| EventNoArtists | 3.19 % | 9.27 % |
| HostDetails | 3.18 % | 9.23 % |
| PostPicker | 3.00 % | 6.72 % |
| PostDetailsProgress | 2.78 % | 2.78 % |
| SeriesEdit | 2.60 % | 4.24 % |
| SignIn3Profile | 2.47 % | 2.47 % |
| EvDetail | 2.31 % | 30.89 % |
| EvMyTickets | 2.17 % | 28.12 % |
| PostReview | 2.15 % | 2.50 % |
| EvWaitlistHeld | 2.10 % | 38.25 % |
| ListDone | 2.05 % | 17.08 % |

## Known, not fixed here

- `StudioTapArea` answers only inside its parent's bounds, as any widget does; where a control sits flush in a tight row, the outer part of the 44 can fall outside. The accessibility area is the full 44 everywhere.
- Flutter's pixel contrast check misreads thin 11–12 px text (dark tertiary "Sold out" measured 2.55:1 where the colours give 5.2:1), so contrast is held by the token test instead.
- **ScenePhotoEdit is a real regression, not a stale image.** Its golden matches the board (a 3:4 frame) but the editor now draws a wide frame on the Adjust step for a portrait photo, and the result depends on how long the photo takes to decode. It already fails on the last commit; it needs a look at `post_edit_page.dart`'s "Original" size once the photo's shape is known.
- Decided 2026-10-28: light tertiary darkened to pass; text capped at 2.0; the pixel rule measures layout regions. Placeholder (#A3A3A3) stays the boards' grey.
