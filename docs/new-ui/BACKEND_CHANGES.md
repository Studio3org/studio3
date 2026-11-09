# Backend changes for the new UI: checklist

Server work the app redesign needs, in `Studio3_backend`. The app side does **not** edit the
backend (since 2026-10-23): each need is written here, the app keeps working against the
current server, and the backend is changed separately.

**How to use this list.** Each entry has the boxes to tick as the work lands, the tests that
prove it, and what the app does until then. Tick a box when its commit is on the main branch
and put the commit next to the entry's title. An entry is done when every box in it is ticked.

**2026-10-25: app features restored.** Commit `76f4ef9` had removed a large part of the app
(events, payouts, reports, QR codes, seller auction controls and more). They are back and use
endpoints the server already has; see [Keep deployed](#keep-deployed-restored-app-features).
They need no server work, except B22 for the redesigned event screens.

## Every deploy

- [ ] Deploy the code and its migration together (`alembic upgrade head` runs when the API
      starts). Never ship code without its migration: B4 and B5 add columns, and without them
      every read of `pieces` / `posts` fails.
- [ ] Check the share pages and `/.well-known/` files still answer (link previews and app links).

The app is ahead-compatible: it sends new fields to an older server, which ignores them, so the
app can ship before the backend.

## Overview

| | # | Change | Needed by | Migration |
|---|---|---|---|---|
| [x] | B1 | Terms of Use acceptance (`8cae725`) | Sign-in | `039_user_terms_acceptance` |
| [x] | B2 | Theme preference on the account (`673cf64`) | Profile settings | `040_user_theme_preference` |
| [ ] | B3 | `reducedRate` on the commission quote (`e8810d0`; the 12-month expiry is open) | `PostAvailFixed` earnings line | none (expiry: one column) |
| [x] | B4 | Piece edition, signed, mediums (`e8810d0`) | `PostDetails*`, `PostMedium` | `041_piece_edition_signed_mediums` |
| [x] | B5 | A Scene linked to several pieces (`e8810d0`) | `ScenePhotoDetails`, `SceneDetails` | `042_post_linked_piece_ids` |
| [x] | B6 | Piece title and image in notification payloads (`6009f82`, on development) | `NotifActivity` rows | none |
| [x] | B7 | Bundled saves and follows, daily summary (`6009f82`, on development) | `NotifActivity`, `NotifSettings` | none |
| [x] | B8 | Mute a conversation (`6009f82`, on development) | `NotifMessages`, `ConvMenu` | `043_conversation_muted_at` |
| [x] | B9 | The piece a conversation started from (`e58fc34`, on development) | `NotifMessages` thumbnail, `Conversation` card | `044_conversation_piece_id` |
| [x] | B10 | Search message text (`3709eef`, on development) | `NotifMessages` search | none (index optional) |
| [x] | B11 | Video messages (`d0f59a1`, `2d32975`, on development) | `Conversation` media bubbles | `045_chat_message_video` |
| [x] | B12 | Notifications about saved pieces and followed artists (`44e09cd`, on development) | `NotifSettings`, `NotifActivity` | none |
| [ ] | B13 | Text messages for urgent updates | `NotifSettings` Text messages | consent + phone verified |
| [x] | B14 | Separate buyer / seller notification types, event reminders (`1afc3dc`, on development) | `NotifSettings` switches | `046_event_rsvp_reminded_at` |
| [x] | B15 | Delete a series (`f4d55dc`, on development) | `SeriesEdit` | none |
| [x] | B16 | Open, update and close the auction on PATCH (**bug**; `eb1d20b`, on development) | List later at auction, auction drafts, editing terms | none |
| [x] | B17 | Save count on your own piece (`fbe306d`, on development) | `ListOwnerPiece`, `ListDone` | none |
| [x] | B18 | The viewer's own bid on a piece (`8e793af`, on development) | `BidOutbid`, `BidLost` | none |
| [ ] | B19 | Shipping estimate and insurance before bidding and at checkout | `BidSheet`, `BidCheckout` | maybe (insurance on orders) |
| [ ] | B20 | Auction rules as designed | Flow 7 | yes (offer table) |
| [x] | B21 | Auction fields in feeds, profiles and Saved (`683bb40`, on development) | `SavedFolder`, `SavedAvailable` | none |
| [ ] | B22 | Paid tickets, ticket types and waitlists for events | `EvChooseTickets`, `EvCheckout`, `EvTicket`, `EvSoldOut`, `EvWaitlist*`, `HostTickets` | yes |
| [x] | B23 | Events tab: featured pick, place, search, date range (built 2026-11-05, not committed) | `EvTab` | `047_event_city_featured` |
| [x] | B24 | Event page: host FAQs and the host's follow state (built 2026-11-07, not committed) | `EvDetail` | `048_event_faqs` |
| [ ] | B25 | Wallet passes for tickets | `EvConfirmed` | none (needs B22) |
| [ ] | B26 | Tell savers when tickets open up; "Exhibited" provenance | `EvSoldOut`, `EvPast` | maybe (provenance list) |
| [x] | B27 | Events in the home feed, Explore and on profiles (built 2026-11-07, not committed) | `Main`, `EventNoArtists`, `ProfileSeller` | none |
| [ ] | B28 | Hosting: age limit, visibility, reschedule, artist approval, check-in | `Host*`, `Artist*` | yes |
| [x] | B29 | Home feed: photos and series on pieces, a real For You, an Available filter (built 2026-11-07, not committed) | `Main`, Available tab | none |
| [x] | B30 | Sign-in: email check, login code, reset code, lockout, consent record (built 2026-11-07, not committed) | `SignInFirst`, `LoginPassword`, `LoginReset`, `SignIn3Profile` | `049_user_privacy_version` |
| [ ] | B31 | Seller setup and profile: studio address, profile mediums (mediums built 2026-11-08; the studio address is on hold) | `SellerStudio`, `ProfileSeller`, `EditProfile` | yes (051) |
| [ ] | B32 | Collected piece: viewer's order, delivery window, hide from Collection | `PieceCollected*` | maybe (hidden flag) |
| [x] | B33 | Scenes: save count, comment moderation, failed drafts (built 2026-11-07, not committed) | `SceneViewer`, `SceneComments`, `Drafts` | `050_scene_extras` |
| [ ] | B34 | Settings: Private Collection, going public, turning off selling, deleting with work in progress (Private Collection built 2026-11-08) | `Settings*` (Flow 12) | yes (051) |
| [x] | B35 | Events in collections, for "Save to collection" everywhere (built 2026-11-08, not committed) | Saving anything (the user's call) | none |
| [x] | B36 | A private profile's header for someone who doesn't follow (built 2026-11-08, not committed) | `ProfilePrivate`, `ProfileRequested` | none |
| [x] | B37 | A profile's Collection: the pieces someone bought (built 2026-11-08, not committed) | `ProfileCollector`, `HandoffProfiles` (the user's call) | none |
| [x] | B38 | The artist's own auction: the bids as Bidder N, and the run that ended (built 2026-11-09, not committed) | `ArtistAuctionLive`, `ArtistAuctionEnd`, `ArtistAuctionPayment`, `ArtistAuctionUnsold` (the user's call) | none |
| [ ] | — | [Server bugs found while building auctions](#server-bugs-found-while-building-auctions) (6 besides B16) | Bidding | — |

The server has to be redeployed for B3–B5 to be live.

---

## B1. Terms of Use acceptance — Done (`8cae725`)

- [x] `users.terms_version` (migration 039)
- [x] `POST /api/user/me/accept-terms` records the current version
- [x] The login response and `GET /api/user/me` return `termsVersion` and `currentTermsVersion`

**App.** An onboarded account whose `termsVersion` is missing or behind gets the one-time Terms
pop-up after login (checked in 19.2: `test/new_ui/flow_terms_prompt_test.dart`).

## B2. Theme preference — Done (`673cf64`)

- [x] `users.theme_preference` (migration 040); null = never chosen (the app treats it as light)
- [x] `PATCH /api/user/me` accepts `themePreference: "light" | "dark"` (anything else → 400) and
      returns it on the user
- [x] Test: `tests/api/test_theme_preference.py`

## B3. Founding-artist rate on the commission quote — Done (`e8810d0`), expiry open

**Why.** The listing form says "You'll receive $3,060 after the 15% **founding artist**
commission". The app must not hard-code the standard rate.

- [x] `GET /api/user/me/commission-quote?priceCents=…` also returns `{ "reducedRate": true }`,
      true when the seller's `commission_bps_override` is below the standard rate for that sale
      kind (`src/modules/user/user_controller.py` `commission_quote()`)
- [x] Test: `tests/integration/test_commission.py::test_quote_uses_the_sellers_own_rate`
- [ ] **Open:** the note says founding artists get 15% "for their first 12 months", but the
      override has no end date. Add an expiry (for example `users.commission_override_until`)
      and have `resolve_bps` ignore the override after it

**Until live.** The field is missing, so the app reads false and says "… after the 15%
commission".

## B4. Piece edition, signed and several mediums — Done (`e8810d0`)

**Why.** "Additional details" asks for Edition (pre-filled "1 of 1") and Signed (Yes / No); the
Medium sheet picks several, and the first is shown and filtered on.

- [x] Migration 041: `pieces.edition varchar(32) null` ("1 of 1", "3 of 10"), `pieces.signed
      boolean null` (null = not said), `pieces.mediums varchar[] null` (every pick, in order)
- [x] `POST /api/pieces` and `PATCH /api/pieces/<id>` accept
      `{"mediums": ["oil", "charcoal"], "edition": "1 of 1", "signed": true}`
- [x] With `mediums`, `medium` = its first entry (Explore filters and every `medium` reader keep
      working); `mediums: []` clears the list but leaves `medium`
- [x] Validation (400): `mediums` a list of non-empty strings, trimmed, cut to 100 characters;
      `edition` text ≤ 32 (blank → null); `signed` true, false or null
- [x] Piece JSON returns `edition`, `signed`, `mediums` (older pieces fall back to `[medium]`)
- [x] Code: `_apply_details()` in `src/modules/pieces/pieces_controller.py`; `piece_to_dict` in
      `pieces_dao.py`; `src/shared/models/piece.py`
- [x] Test: `tests/unit/test_piece_details.py` (`pytest tests/unit/test_piece_details.py
      --noconftest`)

**Until live.** The app sends `medium` (the first pick), so the piece shows the right medium;
the extra mediums, edition and signed are not saved.

**Already on the server, now used.** `weightKg` (from lb), `images` (every photo in order, cover
first), `framingMounting`, and create with `status: "draft"` then `PATCH {"status": "live"}` so
a failed publish leaves a draft.

## B5. A Scene linked to several pieces — Done (`e8810d0`)

**Why.** Scene details shows "Linked pieces" with several tiles; a Scene shows on each linked
piece under "The story behind this piece".

- [x] Migration 042: `posts.linked_piece_ids uuid[]`, back-filled from `linked_piece_id`; no
      foreign key on the array (a deleted piece is skipped when read)
- [x] `POST /api/posts` and `PATCH /api/posts/<id>` accept `{"linkedPieceIds": ["<id>", "<id>"]}`:
      ordered, duplicates dropped, every piece the poster's own (404 otherwise)
- [x] `linked_piece_id` stays the first id; the old single `linkedPieceId` still works when
      `linkedPieceIds` is absent
- [x] Post JSON returns `linkedPieceIds` (older posts fall back to `[linkedPieceId]`)
- [x] `list_related_posts(piece_id)` finds a Scene through either column
- [x] Code: `_resolve_linked_pieces()` in `src/modules/posts/posts_controller.py`; `posts_dao.py`;
      `src/shared/models/post.py`
- [x] Test: `tests/integration/test_scene_links.py` (needs the test database)

**Until live.** The app also sends `linkedPieceId` (the first), so the Scene shows on that
piece only.

## B6. Piece title and image in notification payloads — Done 2026-10-28 (`6009f82`, on development)

**Why.** Activity rows show the piece (40 × 53 on the left for orders and auction alerts,
34 × 45 on the right for likes, saves and comments) and name it ("collected **Paper Planes
III**"). Payloads carry names only, and a title only on `purchase`.

- [x] When a notification is about a piece, its `payload` gets `pieceId`, `pieceTitle` and
      `pieceImageUrl`; a Scene adds `postImageUrl` (its thumbnail, or its photo). Read at send
      time; no schema change
- [x] Done once, centrally: `_subject_fields()` in `src/modules/notifications/notifications_dao.py`,
      called by `create_notification` (which `create_and_push` uses). Every notification row is
      made there (chat messages are push-only, no row), so every sender is covered: likes,
      saves, comments (`social_controller`), purchases (`orders_controller`,
      `payments/webhook_handler`), order updates (`admin/disputes_service`, shipments), auction
      notices (`bids/*`), inquiries
- [x] Target `piece` → that piece; `post` → the Scene's picture and its linked piece; `order` →
      its first item's piece; `inquiry` → its piece; `user`, `event` → nothing added
- [x] The picture is the cover; for a video cover, the piece's first photo; none if it has no
      photo (a video URL would not draw as a picture)
- [x] A caller's own payload value wins (the purchase's `pieceTitle`, the inquiry's message)
- [x] Tests: `tests/unit/test_notification_subject.py`, 10 tests, no database (`pytest
      tests/unit/test_notification_subject.py --noconftest`): each target type, a video piece
      with and without a photo, missing rows, the caller winning, `create_and_push` keeping
      `message`. All 52 unit tests pass with `PYTHONUTF8=1` (without it,
      `test_config_contract` fails on Windows reading `report_controller.py`, as before)
- [ ] Integration run against the test database (`studio3_test`) before deploy: not run here,
      there is no local test database
- [x] App: Activity rows name the piece ("Amara Osei liked your piece **Paper Planes III**.")
      and show the sent picture without fetching it; a Scene's row keeps "your Scene" and its
      own picture, not the linked piece's (`notifications_body.dart`; `notif_activity_test.dart`)

**Deploy.** Code only, no migration. Older rows have no fields; the app still fetches their
pictures.

**Before it is deployed** (and for rows made earlier). The app fetches the picture itself, once
per piece per session, and shows a Surface tile until it arrives. Rows read "liked your piece."
without the title.

## B7. Bundled saves and follows — Done 2026-10-28 (`6009f82`, on development)

**Why.** `NoteNotifActivity`: "saves and follows group into one row per piece per day" ("**12
people** saved your piece **Portrait Dream**.", "**Cedric Okafor** and 4 others followed you.").
`NoteNotifSettings`: "Saves and follows default to a daily summary; people can switch to As they
happen." Grouping stays off the client (plan 0.3).

- [x] Bundled when written, so `GET /api/notifications`, the unread count and read state work
      unchanged: a save joins today's row for that piece, a follow joins today's follow row
      (`_add_to_bundle` in `notifications_dao.py`, called from `create_and_push`). No migration
- [x] The row carries `payload.count` (people) and `payload.actors` (the newest 3: `name`,
      `username`, `profilePhotoUrl`); `actor` is the newest person; the row comes back to the top,
      unread, with `message` "12 people saved your piece." / "Cedric Okafor and 4 others followed
      you."
- [x] Bundle key: (user, `save`, target, day) and (user, `follow`, day). The day is UTC: accounts
      have no time zone yet (a per-account zone would make it the person's own day)
- [x] The same person again the same day (unsave and save again) counts once and sends nothing
- [x] "Accepted your follow request" (`follow` with `accepted`) and follow requests stay single rows
- [x] Reading the row reads the bundle (it is one row)
- [x] Rows from before bundling join a new bundle with their own person counted
- [x] Setting `notificationPreferences.savesAndFollowsMode`: `"daily"` (default) | `"instant"`;
      other values → 400 (`update_notification_preferences`). **Kept beside `push`, not in it**:
      installed apps read every `push` value as true / false
- [x] Daily: no push per save or follow; the row is marked for the summary. Instant: a push per
      new person, as before
- [x] Daily summary job `notifications.daily_summary` (`daily_summary.py`), Celery beat at 17:00 UTC:
      one push per person for what is still unread ("12 people saved your work and 3 new people
      followed you."), push data `{"type": "saves_and_follows_summary"}`; kinds turned off in
      `push` are left out; marks are cleared before sending, so a second run sends nothing
- [x] Internal fields (`actorIds`, `summaryPending`) are left out of what the app receives
- [x] Tests: `tests/unit/test_notification_bundles.py`, 15 tests, no database (`--noconftest`)
- [ ] Integration run against `studio3_test` before deploy (not run here: no local test database)
- [ ] Deploy: the Celery **beat** process must be redeployed to pick up the new schedule
- [x] `tests/integration/test_push_payload.py` follow-up (`55c8975`): CI on
      development failed after `6009f82` because the follow push test expected a push that now
      waits for the daily summary. The test's user chooses "As they happen", and the muted-type
      test does too so it still proves the per-type mute
- [x] App: bundled rows ("12 people saved your piece Portrait Dream.", "Cedric Okafor and 4 others
      followed you.") lead with up to three faces (28, 2 px page edge, 12 apart, the middle one
      12 lower, in 48 × 40) and no picture on the right; a bundle that grows replaces its row live;
      Settings shows Daily summary / As they happen under Saves and follows while it is on; the
      summary push opens Activity (`notifications_body.dart`, `notification_preferences_page.dart`,
      `app_destination.dart`, `push_router_service.dart`)

**Behaviour change on deploy.** Daily is the default, so people who get a push for each save and
follow today get one summary a day instead until they pick As they happen.

**Older rows.** Rows from before the deploy have no `count`; the app shows them as single rows.

## B8. Mute a conversation — Done 2026-10-28 (`6009f82`, on development)

**Why.** `NoteConvMenu`: "Mute notifications: a switch. Messages still arrive in Inbox, but no
alerts are sent for this chat. Muted chats show a crossed-out bell in the Messages list."

- [x] Migration `043_conversation_muted_at`: `conversations.participant_one_muted_at` and
      `participant_two_muted_at` (null = not muted), beside the read times
- [x] `PATCH /api/conversations/<id>/mute` with `{"muted": true | false}` → `{"muted": bool}`; for the
      caller only; anything but true / false → 400; someone outside the chat → refused
- [x] Inbox items and `GET /api/conversations/<id>` return `"muted": bool` (the viewer's)
- [x] A muted chat sends the recipient no push (the REST send and the socket send) and is left out
      of `/api/conversations/unread-count`; it still shows unread in the list
- [x] Tests: `tests/unit/test_conversation_mute.py`, 9 tests, no database: one person only,
      the list, the badge, no push, the PATCH and its checks
- [ ] Integration run against `studio3_test` before deploy (not run here)
- [x] App: Mute notifications switch (crossed-out bell, "You will still get messages, just no
      alerts") first in the conversation menu, saved at once and put back with "Could not save.
      Try again." if refused; a muted chat shows the crossed-out bell (16, Placeholder) in
      Messages instead of the unread dot (`content_actions_sheet.dart`,
      `conversation_thread_page.dart`, `chats_body.dart`, `assets/icons/bell_off.svg`)

**Deploy.** Code with migration 043.

## B9. The piece a conversation started from — Done 2026-10-28 (`e58fc34`, on development)

**Why.** `NoteNotifMessages`: "If a conversation started about a piece, its thumbnail shows on
the right." `NoteConversation`: "Pieces only appear in a chat when it is started from a piece
page (the piece card)." The `Conversation` board draws the "About this piece" card.

- [x] Migration `044_conversation_piece_id`: `conversations.piece_id` (nullable FK to `pieces`,
      `ON DELETE SET NULL`)
- [x] `POST /api/conversations` takes an optional `pieceId`. A chat being started (or a closed one
      started again) keeps the piece if it exists, isn't deleted and belongs to one of the two
      people; otherwise the message still goes without it. A chat already under way keeps what it
      began with. A malformed `pieceId` → 400
- [x] Inbox, requests, `with/<username>` and `GET /api/conversations/<id>` return `"piece": {"id",
      "title", "imageUrl", "priceCents" (only while for sale), "artistUsername"}` or null (also
      null once the piece is deleted). `imageUrl` is the same picture as B6 (a video piece's first
      photo)
- [x] Tests: `tests/unit/test_conversation_piece.py`, 9 tests, no database: the summary (price,
      deleted, none), the list, whose piece counts, a new chat, a chat under way, a closed chat
      started again, a malformed id
- [ ] Integration run against `studio3_test` before deploy (not run here)
- [x] App: the "About this piece" card (236 wide, 8 padding, Line border, radius 16 on Card; the
      48 × 64 cover radius 8; "About this piece" 12 Graphite, the title 14/500, the price 13)
      under the first day line, on the side of whoever asked (yours when it is someone else's
      piece), opening the piece; in a new chat it shows under "Message [name]" and the first
      message sends `pieceId`; Messages rows show the piece's 34 × 45 thumbnail (radius 6) on the
      right; the sold piece page's "Message [artist]" starts the chat about that piece
      (`conversation_thread_page.dart`, `chats_body.dart`, `chat_message.dart`, `chat_service.dart`,
      `available_piece_detail_page.dart`)

**Deploy.** Code with migration 044 (after 043).

**Where chats start from a piece today.** Only the sold piece page's "Message [artist]" (the
collector's delivery card). The piece page has no message button (`BuyPiece`), and `MessagePiece`
is out of scope (plan section 20); any future entry passes `aboutPiece`.

## B10. Search message text — Done 2026-10-28 (`3709eef`, on development)

**Why.** `NoteNotifMessages`: "Search messages at the top searches names and message text, and
shows matching conversations with the matched words highlighted."

- [x] `GET /api/conversations/search?q=…` (signed in): the conversations the inbox shows (open,
      plus requests you sent; requests waiting on you stay behind "Message requests") whose other
      person's name or handle, or any message, contains `q`, case-insensitive (`ILIKE`). `%`, `_`
      and `\` in `q` match literally. Empty `q` → no results; over 100 characters → 400
- [x] Rows are the inbox's (`_inbox_item`, now shared by the inbox and requests) plus
      `matchPreview`: the newest matching message, cut to 140 on one line and starting a word or
      two before the match when it is further in, so the match shows; null when only the name
      matched. Newest first, paged with the inbox's cursor
- [ ] Trigram index on `chat_messages.body`: not added; add one (`pg_trgm`, GIN) if search gets slow
- [x] Tests: `tests/unit/test_conversation_search.py` (9, no database: the preview, wildcards, the
      query's scope, the response, paging, empty and long searches);
      `tests/api/test_conversation_search.py` (5, against Postgres in CI: by message text with the
      newest match, by name and by handle, not someone else's chats, not requests waiting on you,
      wildcards, signed out)
- [ ] The API tests run in CI only (no local Postgres here); check them on the next CI run
- [x] App: typing filters the loaded chats at once, then after 300 ms asks the server and shows
      its results, the row's second line showing `matchPreview` with the match in 500 Ink; a
      spinner while it looks with nothing loaded matching; a failed search leaves the filtered
      chats; scrolling pages the results (`chats_body.dart`, `ChatService.searchConversations`,
      `ConversationSummary.matchPreview`)

**Deploy.** Code only.

## B11. Video messages — Done 2026-10-29 (`d0f59a1`, `2d32975`, on development)

**Why.** `NoteConversation`: "Photos and videos send as media bubbles." "+ attaches a photo or
video from the camera roll, nothing else." The board's + is labelled "Attach a photo or video".

- [x] Migration `045_chat_message_video`: `chat_messages.video_url` and `thumbnail_url`; the check
      that a message has something in it (`ck_chat_messages_body_or_image`, now
      `ck_chat_messages_has_content`) counts a video
- [x] `POST /api/conversations`, `POST /api/conversations/<id>/messages` and the socket's
      `message:send` take `videoUrl` and an optional `thumbnailUrl` (its poster). A photo and a
      video together → 400; a poster without a video → 400. Both URLs must be the sender's own
      uploads on the media store (same check as other user media), else 400
- [x] Thread messages (and the live socket ones) return `videoUrl` and `thumbnailUrl`; the inbox
      preview says "Video" and the push says "Sent a video"
- [x] Size limits (20 MB a photo, 100 MB a video, as the app): `/api/media/presign` takes
      `contentLength`; over the limit → 413. A `chat` video must give it (400 without). A given
      size is signed into the S3 URL (SigV4, `ContentLength`), so S3 refuses any other size;
      uploads that give no size are signed as before. The dev-only local upload refuses over 100 MB
- [x] Tests: `tests/unit/test_video_messages.py` (16, no database: what a message attaches, whose
      files, previews and push text, the thread payload, sending one, the limits, the signing);
      `tests/api/test_video_messages.py` (4, against Postgres in CI: a video message round-trips
      through presign, start, thread, inbox and send; oversized or unsized uploads refused;
      someone else's file refused; a photo and a video together refused).
      `test_conversation_piece.py`'s `create_message` stub takes the new keyword arguments
- [ ] The API tests run in CI only (no local Postgres here); check them on the next CI run
- [x] App: + picks a photo or a video (`pickMedia`); a video over 100 MB is turned away before
      uploading ("Videos can be up to 100 MB"); it uploads with its size, then its first frame
      (480 wide JPEG) as the poster (best-effort: it still sends without one), and sends
      `videoUrl` / `thumbnailUrl`. The bubble is the photo tile (180 × 240, the tail corner) with
      the poster and a 44 Scrim circle with a white play; it opens `ChatVideoPage` (black, the
      video at its shape, plays with sound, a tap pauses, Close). Chat uploads say their size to
      presign (`media_service.dart`, `conversation_thread_page.dart`, `chat_video_page.dart`,
      `chat_message.dart`, `chat_service.dart`)

**Deploy.** Code with migration 045 (after 044). Check `AWS_REGION` is the bucket's region: the
sized chat uploads are signed with SigV4, which fails against a bucket in another region (the
other uploads keep their old signing).

**Not changed.** `imageUrl` is still taken as given, without the "your own upload" check the
video now has; adding it would be a separate change.

## B12. Notifications about saved pieces and followed artists — Done 2026-11-01 (`44e09cd`, on development)

**Why.** `NotifSettings` has "Saved pieces" ("Now listed, price changes, auctions starting.")
and "Artists you follow" ("New pieces and Scenes."); `NotifActivity` draws "**Now listed** Paper
Planes III, which you saved, is now available for $950." and "**Amara Osei** posted 3 new
pieces." The server sent neither.

- [x] `saved_piece_listed`, `saved_piece_price`, `saved_piece_auction` to everyone who saved the
      piece (a quick save or a collection), not its artist, no deleted accounts, no blocks either
      way. Listed: it has just become live and for sale at a fixed price (PATCH, or an event
      publishing it). Price: a new price while on sale (payload `priceCents`, `wasPriceCents`).
      Auction: an auction opens on it (relist, an event publishing it; payload `priceCents` = the
      starting bid, `biddingOpen`, `opensAt`). Code: `src/modules/notifications/watchers.py`
- [x] `followed_artist_post` to accepted followers (not pending requests) when an artist posts a
      piece or a Scene: created live, or a draft going live. Payload `pieces`, `scenes`; the target
      is the newest work; `message` "Amara Osei posted 3 new pieces."
- [x] One row a day: a second price change of the same piece, or more posts by the same artist,
      the same (UTC) day update that row (back to the top, unread; a price keeps the first "was")
      without another push, so a batch upload is one push
- [x] All through `create_and_push`, so `push[type]` turns each off; every row carries `message`,
      and B6 adds the piece's title and picture
- [x] Sent after the caller's commit; a failure is logged and never undoes the listing or post
      (as `rsvp_service.notify_attendees`). Hooks: `pieces_controller.create` / `patch`,
      `auction_controller` relist, `events_controller.publish` (via `publish_lineup(changes=)`),
      `posts_controller.create` / `patch`
- [x] Tests: `tests/unit/test_watchers.py` (14, no database: the lines, when savers hear and when
      not, one row a day, a failure not stopping the rest, who counts as a saver or a follower);
      `tests/api/test_watchers.py` (4, against Postgres in CI: savers hear of a listing and a price
      once a day, quick saves and collections alike, not the artist; followers hear of a piece and a
      Scene as one row and one push, not pending requests or strangers; a draft tells nobody until
      it goes up; turned off gets the row, no push)
- [ ] The API tests run in CI only (no local Postgres here); check them on the next CI run
- [x] App: Saved pieces (under Collecting, after Auctions) and Artists you follow (first under
      Following), each switching its types together; Activity rows: Now listed in green over the
      piece, a new price and an auction over the piece without a status word, and the artist's face
      with the newest work on the right for a post (`notification_preferences_page.dart`,
      `notifications_body.dart`)

**Deploy.** Code only, no migration.

**Not in this.** Fan-out runs in the request, one row per person, like event cancellations. Move it
to a Celery task if savers or followers ever number in the thousands. Auctions opened by PATCH
tell savers too since B16; the piece that went to auction from a fresh create has no savers yet.

## B13. Text messages for urgent updates — Pending

**Why.** `NotifSettings` "Text messages: Urgent auction and order updates" ("Outbid in the final
24 hours, won, payment issues. Needs a phone number."), off by default, with its own consent.

- [ ] An SMS provider, and `users.sms_consent_at` (null = off), set only with a verified phone
- [ ] `PATCH /api/user/me/notification-preferences` accepts `{"sms": {"urgent": bool}}`; on
      without a verified phone → 400 with a clear message
- [ ] Send SMS for `outbid` (last 24 hours), `auction_won`, `auction_payment_failed`, and
      `purchase` payment problems
- [ ] Tests: no SMS without consent or a verified phone; a STOP reply turns it off

**Until live.** The Text messages section is not shown.

## B14. Separate buyer and seller notification types, event reminders — Done 2026-11-01 (`1afc3dc`, on development)

**Why.** Settings switches turn off groups of server types (`push[type]`). `purchase` went to
the buyer and the seller with the same type, so one switch controlled both; and there were no
event reminders (only `event_cancelled`).

- [x] The seller's copy is `sale` ("You made a sale!"), the buyer's stays `purchase` ("Order
      confirmed"); both senders (the Stripe webhook and the dev-mode confirm) go through one
      `src/modules/orders/order_notices.notify_paid`. Old seller rows stay `purchase` with
      `totalCents`, and the app still reads those as sales
- [x] `event_reminder` to everyone going (an RSVP until tickets land with B22): an hourly Celery
      beat job (`events.send_reminders`, minute 5) takes published events starting between 1 and
      24 hours from now. Each RSVP is marked `event_rsvps.reminded_at` and committed before
      sending, so a person hears once per event, even after a cancel and re-RSVP or a
      redelivered job. Deleted accounts are skipped. The host is the actor, and the message
      uses the event's own time zone: "Night Market is tomorrow at 7 PM at Cedars Union."
      Without a time zone it says "starts in 7 hours". Code: `src/modules/events/reminders.py`
- [x] Shipping updates existed as `order`; they are now `order_shipped` (to both sides, with
      payload `side`: buyer or seller) and `order_delivered` (to the buyer). `order` stays for
      cancellations, refunds and disputes
- [x] Tests: `tests/unit/test_b14_notification_types.py` (9, no database: the types and
      sides, the reminder wording and time zones, the window, the claim, deleted accounts, a
      failure not stopping the rest); `tests/api/test_b14_notification_types.py` (3, against
      Postgres in CI: buyer and seller get different types for one order, and a seller who
      muted `purchase` still hears `sale`; one reminder per person per event across two runs, not
      for someone who pulled out, a muted person gets the row but no push; events too soon, too
      far or unpublished wait)
- [ ] The API tests run in CI only (no local Postgres here); check them on the next CI run
- [x] App: `sale` under Bids and sales, `event_reminder` under Events, `order_shipped` and
      `order_delivered` under Orders and shipping. The Activity line for a sale is "Jordan Lee
      collected Companion Bloom." An order notification opens My sales for `sale` or `side`
      seller (`isSellerOrderNotice`)

**Deploy.** Migration `046_event_rsvp_reminded_at`, then redeploy Celery beat so the hourly
reminder job runs. Existing RSVPs to events within the next day are reminded on the first run.
A seller who had turned off Orders and shipping will hear about sales again until they turn off
Bids and sales.

## B15. Delete a series — Done 2026-11-02 (`f4d55dc`, on development)

**Why.** `NoteSeriesEdit`: "Delete series asks to confirm; the pieces stay on the profile, just
not grouped." Series routes had no delete.

- [x] `DELETE /api/series/<id>` (owner only): removes the series and its piece links
      (`series_dao.delete_series`); the pieces stay; 404 for someone else's series or one that
      does not exist, as for every other series edit. Returns `{"id", "deleted": true}`
- [x] Tests: `tests/unit/test_series_delete.py` (3, no database: links then the series, the owner
      deletes, someone else's or a missing one is 404 and nothing is deleted);
      `tests/api/test_series_delete.py` (2, against Postgres in CI: the owner deletes, the pieces
      remain and show no series, the series is gone from detail and from My series; another user
      gets 404 and the series stays)
- [ ] The API tests run in CI only (no local Postgres here); check them on the next CI run
- [x] App: "Delete series" on Edit series (14 Graphite, underlined, centred, under "+ Add
      pieces"), asking first ("Delete this series? The pieces stay on your profile, just not
      grouped."). Deleting closes Edit series and the series page; Manage series reloads with a
      toast, the profile reloads (`SeriesService.delete`, `SeriesEditResult`)

**Deploy.** Code only, no migration.

## B16. Open, update and close the auction on PATCH — Done 2026-11-05 (`eb1d20b`, on development)

**Why.** `PATCH /api/pieces/<id>` validates `listingType: "auction"`, `auctionDurationDays` and
`reserveCents` but never touches the Auction row (`pieces_controller.py` ~364–366; `open_auction`
runs only from create, relist and event publish). So:
- List later at auction leaves no Auction: every bid fails with 400 "This piece is not up for
  auction."
- A draft auction taken live keeps its Auction in `draft`: bids get 409 and the closer never runs
- A new starting bid on a no-bid auction changes `price_cents`, but bidding still uses
  `auction.starting_bid_cents`; `reserveCents` and `auctionDurationDays` are dropped
- Auction → fixed leaves the old Auction live; when it expires the closer delists the fixed piece

- [x] New `src/modules/pieces/auction_sync.py`, run by PATCH after the piece's fields and
      status are set and before the commit, so the piece and its Auction change together. When
      the merged listing is an auction it creates the Auction if there is none (in draft)
- [x] Updates its terms while it has no bids: starting bid, reserve and length. A new length
      on a live auction moves `closes_at` to `opens_at` + days; it is refused (400) if that time
      has passed, and (409) once the auction was extended. `reserveCents` is now a listing term
      (`COMMERCIAL_FIELDS`), and a patch that leaves it out keeps the Auction's reserve, so a new
      starting bid is still checked against it
- [x] Opens it when the piece is (or becomes) live. Savers hear it is up for auction (B12)
- [x] When it stops being an auction (fixed price, or not for sale), the running Auction is
      cancelled (`cancelled_reason` `listing_changed`); with bids it is refused, as before. When
      the piece goes off the profile (draft or delisted), the run is cancelled (`unlisted`) and a
      fresh draft with the same terms waits, so going live again starts a new clock. Set live
      again after a run ended, with no new terms, it reuses the last run's terms
- [x] An event's auction belongs to the event: term edits are refused (409, "change its terms
      from the event") and its clock is left alone
- [x] Tests: `tests/unit/test_auction_sync.py` (14, no database: create, open, term edits and
      their refusals, cancel, off the profile and back, event auctions, reusing the last terms);
      `tests/api/test_auction_on_patch.py` (7, against Postgres in CI: not for sale → auction by
      PATCH opens one that takes bids; a draft auction going live opens it; term edits before the
      first bid reach the Auction and a kept reserve is enforced; frozen with bids; auction →
      fixed cancels it; delisted then live starts a new run; an event auction is refused)
- [ ] The API tests run in CI only (no local Postgres here); check them on the next CI run
- [x] App: `kListLaterAuction` on, so List later offers Fixed price or Auction (as the board);
      the listed screen says "Collectors can bid on it now." for an auction

**Deploy.** Code only, no migration. Pieces listed at auction by PATCH before this have no
Auction; setting them live again asks for a length (400 "Auction duration must be between 3 and
14 days") rather than guessing one.

**Not in this.** Posting an auction still creates it live in one call (`PostAvailAuction`); a
draft step there is possible now but was not asked for.

## B17. Save count on your own piece — Done 2026-11-05 (`fbe306d`, on development)

**Why.** `ListOwnerPiece` "Saved by [N] people" and "[N] people saved this. They'll hear if you
list it."; `ListDone` "We let the [N] people who saved it know" (the notifying is B12).

- [x] `savesCount` on piece detail for the owner only: left out for anyone else and signed out
      (not sent as null). Also on the PATCH response, which only the owner can make, for
      `ListDone`. Counted by `watchers.count_savers`, the same people `savers_of` tells (B12):
      quick saves and collections, each person once, not the artist, no deleted accounts, no
      blocks
- [x] Tests: `tests/unit/test_saves_count.py` (3, no database: the count has the same rules as
      `savers_of`; the owner gets it; another viewer and signed out don't);
      `tests/api/test_saves_count.py` (2, against Postgres in CI: three people, one saving twice,
      count 3 for the owner and no field for others; listing returns it)
- [ ] The API tests run in CI only (no local Postgres here); check them on the next CI run
- [x] App: `savesCount` on `PieceSummary` and `FeedPreviewItem`. Your own not-for-sale piece:
      "Saved by / 12 people" over List for sale and edit, and "12 people saved this. They'll hear
      if you list it." (the number in Mono) in place of "Not for sale"; with nobody, no info row
      and "Not for sale" as before. `ListDone`: "We let the 12 people who saved it know." (one:
      "We let the person who saved it know."), else "Collectors can collect it now." / "bid on it"

**Deploy.** Code only, no migration.

## B18. The viewer's own bid on a piece — Done 2026-11-05 (`8e793af`, on development)

**Why.** `BidOutbid` shows Outbid with the next minimum; `BidLost` / `BidReserveNotMet` show "Your
top bid". The bid summary had only `isHighestBidder`, and nothing after a close without a sale.

- [x] On piece detail for a signed-in viewer: `myTopBidCents` and `myBidStatus` (`leading`,
      `outbid`, `won`, `lost`, `none`), also after the auction closes. Top level, not in the bid
      summary, because a closed no-sale auction has no summary on the piece. Left out signed out.
      Code: `src/modules/bids/my_bid.py`. "This run" is the running auction, else the one being
      settled, else the latest: after a relist everyone starts at `none`. `outbid` is also a
      runner-up still held while the winner's payment is chased; `lost` covers someone else
      winning, below the reserve, cancelled, and won-but-not-paid (forfeited)
- [ ] Optional `GET /api/user/me/bids`: not built; the app has no My bids list to use it
- [x] Tests: `tests/unit/test_my_bid.py` (13, no database: each status while open and after the
      close, the top bid, signed out); `tests/api/test_my_bid.py` (4, against Postgres in CI:
      leading, outbid, none and signed out while open; won and lost after a sale; lost with the
      top bid kept below the reserve; none after a relist)
- [ ] The API tests run in CI only (no local Postgres here); check them on the next CI run
- [x] App: `myTopBidCents` / `myBidStatus` on `PieceSummary` and `FeedPreviewItem`. The bar's
      Outbid comes from the server's status when it sends one, else from `BidStore` as before;
      "Your top bid" on `BidLost` / `BidReserveNotMet` is the server's, else this phone's.
      `BidStore` stays as the fallback (signed out, an older server)

**Deploy.** Code only, no migration.

## B19. Shipping estimate and insurance before bidding and at checkout — Pending

**Why.** `HandoffBidding`: before bidding, show estimated shipping from ZIP and size, and
insurance from the bid; `BidCheckout` lists Shipping, Insurance, Sales tax. Today the shipping
quote is fixed per method, there is no insurance, and tax is a flat 8.25 % of the artwork.

- [ ] `GET /api/pieces/<id>/shipping-estimate?zip=75225` → `{city, lowCents, highCents}` from the
      piece's size and weight
- [ ] `insuranceCents` for a given amount (Convelio prices; placeholders until then, per
      `NoteBidCheckout`)
- [ ] Insurance as an option on `auction-checkout` and `collect`, stored as `insuranceCents` on
      the order
- [ ] Real sales tax by address
- [ ] Tests: the estimate changes with ZIP and size; insurance is charged only when chosen; tax
      follows the address

**Until live.** The bid sheet has no estimate box; checkout has no Insurance row.

## B20. Auction rules as designed — Pending

**Why.** `HandoffBidding` and the Bid notes differ from the server:

| Rule | Design | Server today |
| --- | --- | --- |
| Increments | $25 under $500, $50 to $999, $100 to $4,999, $250 to $9,999, $500 above | $5 / $10 / $25 / $100 / $500 bands (`auction_config.py`, "pending sign-off") |
| End time | Fixed; no extensions, no maximum bids | A bid in the last 5 minutes pushes the end 5 minutes, without limit or notice |
| Card | First bid verifies a card (setup intent), no hold; only the winner is charged | Every bid places a manual-capture hold, re-authorised daily |
| Winner | 48 hours to confirm shipping and pay; reminders at 24 and 47 hours | Hammer price captured at close; no deadline, no reminders |
| Card fails | 24 hours to fix with retries, then a second chance offer to the runner-up at their top bid (only if it met the reserve), 24 hours to accept | 48 hours, then the next bidder is charged automatically (up to 3 times), no offer step |

**Canvas update 2026-11-09** (`HandoffBidding`, `NoteBidVerify`, `NoteBidSheet`,
`NoteBidPaymentFailed`, `NoteBidSecondChance`; `BidWon` and `BidCheckout` are archived on the
canvas): the rules above change again, all of them payment work, so they wait with the hold on
payments and shipping (2026-11-05):

| Rule | Design now | Server today |
| --- | --- | --- |
| Winner | Their saved card is charged automatically when the auction ends: bid, shipping, insurance and tax. No checkout after winning | The bid is captured at close; the winner then confirms shipping and pays shipping and tax (`auction-checkout`) |
| First bid | Collects the card **and** a full shipping address (Ship to row), not a ZIP | A card (setup intent with the ZIP) |
| Card form | Stripe's Payment Element with Apple Pay on top; a SetupIntent saved for off-session use | The card field; a setup intent |
| Charge | Off-session PaymentIntent as a destination charge to the artist's connected account, Studio 3's fee as the application fee; a bank check (SCA) counts as a failed payment | Hold at each bid, captured at close |
| Card fails | 12 hours to fix, with automatic retries, then a second chance offer to the next bidder | 48 hours (10 minutes at an event), then the next bidder is charged automatically |
| Second chance | Accept and pay charges the saved card right away and opens the collected screen | No offer step |
| Artist ends early | A cancel: no winner, no charges, bidders told, the piece back to not for sale | The same (`/auction/cancel`) |

- [ ] The rows of this second table (on hold with payments and shipping)

- [ ] **Decide first** (product): align the server with the design, or confirm the server's rules
      so the boards and copy change instead
- [ ] Increments
- [ ] Fixed end time
- [ ] Card check instead of holds
- [ ] 48 hours to pay, with reminders at 24 and 47 hours
- [ ] Second chance: `auction_offers` (bidder, amount, expires_at, status),
      `auction_second_chance` notification, `POST /api/pieces/<id>/auction/offer/accept|decline`
- [ ] Tests for each rule changed

**Until live.** The app follows the server: the minimum next bid comes from the server (quick
picks use the design's steps above it), the end time shows as sent, You won shows "Time to
pay" only with a deadline, and there is no Second chance screen. The seller's Manage auction
sheet uses the server's own extend (once, 1–3 days), cancel and relist.

## B21. Auction fields in feeds, profiles and Saved — Done 2026-11-05 (`683bb40`, on development)

**Why.** `SavedFolder` "Auction ends in 6h", `SavedAvailable` "Bid $1,300 · 6h left". List
payloads used `piece_to_dict` without the bid summary, and the create response had none.

- [x] On list payloads for auction pieces (`listingType` was already there): `auctionId`,
      `auctionStatus`, `startingBidCents`, `highestBidCents` (null before a bid), `bidCount`,
      `minNextBidCents`, `opensAt`, `auctionEndsAt`, `hasReserve`, `reserveMet`, `winningBidCents`;
      the detail's names, so the app reads them the same way. Nothing viewer-specific
      (`isHighestBidder` and the like stay on the detail; lists are shared and cached), never the
      reserve amount. Batched for a whole list in two or three queries
      (`src/modules/bids/auction_list_fields.py`). On: the explore / following / for-you feeds,
      profile grids (`/api/users/<username>/pieces`), saved pieces, collections, series, a Scene's
      linked piece, and the saved pieces in `/api/user/me`. A fixed-price piece gets none of it
- [x] The bid summary in the create response
- [x] Tests: `tests/unit/test_auction_list_fields.py` (6, no database: the fields, no viewer or
      reserve amount, running over settling, the winning bid, fixed price untouched and no
      query); `tests/api/test_auction_list_fields.py` (4, against Postgres in CI: profile grid,
      saved, explore feed and a collection carry them for the auction and not the fixed-price
      piece; create returns the summary)
- [ ] The API tests run in CI only (no local Postgres here); check them on the next CI run
- [x] App: `SavedFolder` "Auction ends in 6h" (12/500, red under 24 hours, else Ink);
      `SavedAvailable` "Bid $1,300 · 6h left" (13/500, red under 24 hours) and live auctions
      ending soonest first, then newest saved (`saved_collection_widgets.dart`)

**Deploy.** Code only, no migration.

## B22. Paid tickets, ticket types and waitlists for events — Pending

**Why.** The event boards sell tickets: host-set types (price, what's included, how many,
per-order limit), several types in one order, a checkout with service fee and tax, one QR code
per ticket that scans once, "Only 3 left" / Sold out, and a waitlist. The server treats every
event as free (`event_card` always `"isFree": true`; an RSVP is a headcount; QR codes are per
piece, not per attendee). Confirm details with the board notes before building.

Tickets
- [ ] `event_ticket_types` (event, name, price_cents, includes, quantity, per_order_limit, sort)
- [ ] An event order (buyer, items per type, totals, payment intent) and `event_tickets` (one row
      per admission, its own code, `scanned_at`)
- [ ] `GET /api/events/<id>` returns `"ticketTypes": [{"id", "name", "priceCents" (0 = free),
      "includes", "left" (null = no cap), "perOrderLimit" (null = none)}]`; `isFree` computed
      (the app already reads this)
- [ ] `POST /api/events/<id>/orders/quote` `{"items": [{"ticketTypeId", "quantity"}]}` →
      `{"serviceFeeCents", "taxCents", "totalCents", "refundPolicy"}` (fee on paid tickets only;
      the app never computes fees or tax)
- [ ] `POST /api/events/<id>/orders` (same body) → `{"id", "clientSecret"}` (no secret when nothing
      is due; free-only orders confirm at once); 409 when a type sold out or went over its limit
- [ ] `GET /api/user/me/tickets?eventId=<id>` → `{"tickets": [{"id", "code", "ticketTypeName",
      "number", "scannedAt"}]}`
- [ ] `ticketCount` on each `scope=going` event ("2 tickets" in Your events)
- [ ] `POST /api/events/<id>/tickets/<code>/scan` for the host's scanner

Waitlist (`EvWaitlistRules`; the app side is built and waits for this)
- [ ] On `GET /api/events/<id>` and the Your events lists: `"waitlist": {"open": bool, "wanted":
      [{"ticketTypeId", "quantity"}], "held": {"items": [...], "until": ISO} | null,
      "waitingCount": int (host only)}`; leave `waitlist` out while there is none
- [ ] `POST /api/events/<id>/waitlist` `{"items": [...]}` joins (free, no card, up to each type's
      per-order limit) and returns `waitlist`; `DELETE` the same path leaves
- [ ] `POST /api/events/<id>/waitlist/hold/release` gives up held tickets, keeps the place for
      other types, returns `waitlist`
- [ ] Orders and RSVPs for held tickets go through while the hold lasts
- [ ] Notifications (target the event): when tickets are held ("2 tickets are held for you until
      9:40 PM CST"), and when a hold ends unused
- [ ] Rules: first come, first served in joining order; a freed ticket is held for the next
      person who asked for that type (up to how many they asked for), any extra to the next
      people at the same time
- [ ] Rules: the hold lasts 2 hours; 30 minutes when the event is under 24 hours away; 10
      minutes under 2 hours; an unused hold passes on and takes them off the waitlist
- [ ] Rules: when the host adds more than the waitlist wants, holds go out first and the rest go
      on sale; free events work the same with Reserve; the waitlist closes quietly when the
      event starts; the host sees how many wait, per type

Tests
- [ ] Per-order limits and sell-out hold under concurrent orders
- [ ] A free-only order needs no payment
- [ ] Each ticket scans once
- [ ] Holds go in joining order and expire on time

**Until live.** The event screens keep the free RSVP ("I'm going"); Choose tickets offers one
free place per person; the paid ticket and waitlist screens wait for this.

## B23. Events tab: featured pick, place, search and date range — Done 2026-11-05 (not committed yet)

**Why.** `EvTab` has a Featured event, "Near me" with a city picker, Search events and Today /
This week / This month. Browse returns today, following, upcoming and categories only; events
have no featured flag or city; `upcoming` is capped, so a month filtered on the phone can miss
events.

- [x] Featured: `events.featured_at`, set by the team with Feature / Unfeature on the admin
      Events page (published events only; audited as `event_featured` / `event_unfeatured`).
      Browse returns `"featured": <event card>` (the soonest featured event in the asked range,
      place and search) or null; cards carry `featured`
- [x] Place: `events.city`, read from the address on create and on PATCH (the part before the
      last, unless it has a digit: a postcode), and filled for existing events by the migration.
      `GET /api/events/cities` → `{"cities": [{"city", "upcomingCount"}]}` (published, still to
      come, grouped case-insensitively); `?city=` (case-insensitive) on browse and list; cards
      carry `city`. Not built: `?near=lat,lng&radiusKm=` (the spec's alternative)
- [x] Search: `?q=` (up to 100 characters) on browse and list, over title, venue, category and
      the host's name and username, case-insensitive, `%` and `_` literal
- [x] Range: `?from=&to=` (ISO times with the viewer's offset; a date alone is UTC midnight) on
      browse and list: an overlap, so a run already open is included. Range, place and search
      apply to browse's today, following, upcoming, featured and category counts, and to the
      list's upcoming, today and following scopes (not saved, hosting or going). `?limit=` sizes
      browse's upcoming (default 20, up to 50)
- [x] Tests: `tests/unit/test_event_tab_filters.py` (11, no database: the city rule, the overlap,
      city and search SQL, nothing added with no filter, city grouping, the query arguments);
      `tests/api/test_event_tab.py` (5, against Postgres in CI: Featured honours the range; a run
      open before `from` is included; city and search combine with category; saving an address
      fills the city and the cities list counts what's coming up; the admin Feature button)
- [ ] The API tests run in CI only (no local Postgres here); check them on the next CI run
- [x] App: the tab asks browse for the range, place and search shown (search after 300 ms of
      no typing; a later answer wins; a failure keeps the cached tab), uses the server's
      Featured pick and Near me's server cities; "See all" passes the same. The local rules stay
      as the fallback: the soonest event in range when nothing is featured, cities from
      addresses when the server has none

**Deploy.** Migration `047_event_city_featured` (fills `city` for existing events).

## B24. Event page: host FAQs and the host's follow state — Done 2026-11-07 (not committed yet)

**Why.** `EvDetail` lists host-written FAQs and has Follow next to "Hosted by". Nothing stores
FAQs, and the detail doesn't say whether the viewer follows the host (the app fetches the host's
profile on every event page for that).

- [x] A JSON `faqs` column on `events` (`[{"question", "answer"}]` in the host's order, null for
      none): they belong to the event, are few, and are only read and written whole
- [x] `POST /api/events` and `PATCH /api/events/<id>` take `faqs: [{question, answer}]`: at most
      10, each trimmed; question required (up to 200 characters), answer optional (up to 1,000);
      a row left wholly blank is dropped; `[]` or null clears them. Anything else is a 400
- [x] Every event detail (`GET /api/events/<id>`, and what create, PATCH, publish and cancel
      return) has `"faqs": [{"question", "answer"}]` in the host's order, `[]` for none
- [x] `"hostIsFollowing"` and `"hostFollowRequested"` on the detail for a signed-in viewer, read
      from the same follow row as `/api/users/<username>/follow` (`accepted` / `pending`); both
      false for the host; left out for a guest
- [x] Tests: `tests/unit/test_event_faqs.py` (16, no database: trimming and order, blank rows,
      every refusal, ten allowed, the follow flags for none / accepted / pending, the host);
      `tests/api/test_event_faqs.py` (4, against Postgres in CI: create → PATCH reorder → detail →
      clear; an answer without a question is refused and nothing is saved; the flags match what
      follow and unfollow return for a public and a private host; a guest gets no flags)
- [ ] The API tests run in CI only (no local Postgres here); check them on the next CI run
- [x] App: the event page takes Follow from the detail's flags and only asks the host's profile
      when they're missing (an older server, or the detail failed); a later refresh doesn't
      overwrite a tap. FAQs show as soon as the event has them (it already read `faqs`)
- [ ] Not built: a step in hosting to write FAQs. The boards have none (plan section 0.3), so
      until one is designed FAQs are set through the API only

**Deploy.** Migration `048_event_faqs`.

## B25. Wallet passes for tickets — Pending (needs B22)

**Why.** `EvConfirmed` leads with "Add to Apple Wallet". A `.pkpass` must be signed with the
team's Pass Type ID certificate, so only the server can make one.

- [ ] A Pass Type ID and certificate in the Apple developer account
- [ ] `GET /api/events/<id>/orders/<orderId>/wallet-pass` → `application/vnd.apple.pkpass` (one
      event ticket pass per ticket, bundled: QR code, event name, date, venue, the flyer as the
      strip image)
- [ ] Optional: update the pass when the event changes or is cancelled (pass web service)
- [ ] Optional (Android): `GET .../wallet-pass?platform=google` → `{"saveUrl"}`
- [ ] `walletPassAvailable: true` on the order (or on `GET /api/user/me/tickets`), so the app shows
      the button only when it works
- [ ] Tests: the pass validates (signature, `passTypeIdentifier`, barcode = ticket code); a
      cancelled order returns 410

**Until live.** No Apple Wallet button; Add to calendar is the main button.

## B26. Events: tell savers when tickets open up; "Exhibited" provenance — Pending

**Why.** `EvSoldOut`: "If the host adds more tickets, everyone who saved it gets a
notification." `EvPast`: tagged pieces stay buyable, "and this is also how the piece gets
Exhibited added to its provenance record." Today only people going are notified, and provenance
is free text.

- [ ] When a full event gets places again (capacity raised, an RSVP cancelled; with B22 more
      tickets or a refund), notify everyone who saved it and isn't going, once per reopening:
      `event_tickets_available`, target the event; debounce a cancel-then-retake
- [ ] When a published event ends, add an "Exhibited" entry to each tagged piece's provenance
      (event title, venue, city, date, linked to the event): a structured list, or at least a
      line appended to the note; show it on the piece
- [ ] Tests: savers (not attendees) get one notification per reopening; ending an event adds one
      Exhibited entry per tagged piece, never twice

**Until live.** Save on a sold-out event saves it; no notification comes. Provenance is unchanged.

## B27. Events in the home feed, in Explore and on profiles — Done 2026-11-07 (not committed yet)

**Why.** `Main` / `EventNoArtists` put one event card in the home feed; `NoteExplore` has an
"Upcoming shows" shelf; `ProfileSeller` / `ProfileOwn` show an "Upcoming show" card. The feed
returns pieces and posts only, and no route calls `events_controller.list_for_host`.

- [x] `GET /api/users/<username>/events?scope=upcoming`: the host's published events that haven't
      ended, soonest first (`?limit=`, default 20, up to 50). Without `scope`, what
      `list_for_host` gave before (published, newest first, plus the host's own drafts for the
      host). 404 to someone blocked either way, 403 on a private account the viewer doesn't
      follow, as the profile's grids. (`list_for_host` imported a function that doesn't exist;
      it had never been routed, so it is fixed here.)
- [x] `"upcomingEvent"` (one event card, or null) on the public profile payload and on
      `GET /api/user/me`: the soonest published event the user hosts that hasn't ended. Not on
      a private profile's locked header
- [x] Feed: one `{"type": "event", "event": <event card>}` item on the **first page** of
      `/api/feed/for-you` and `/api/feed/following`, after the third item (the end of a shorter
      page; none on an empty page). An event starting in the next 14 days and not over, from a
      host the viewer hasn't blocked (or been blocked by): a host they follow first, then one
      within 80 km of the location on their account, then the soonest. **Only when the app
      asks with `?include=events`**: the app as released reads any item it doesn't know as a
      piece and would draw an empty tile. Pieces carry no series yet (B29), so "never right
      after a series row" stays the app's (it moves the card off series rows)
- [x] Explore: `"upcomingShows"` on the first page of `/api/feed/explore` (not with `?medium=`,
      not on For You): up to 5 published shows still to come that have work on their bill,
      soonest first, each an event card with `"pieces"`: up to 12 of its live pieces in bill
      order (`pieceId`, `title`, `mediaUrl`, `mode`, `priceCents`, `artistUsername`,
      `artistName`). The board's shelf is one show's pieces (subtitle: name · venue · date),
      so the pieces come with it. Blocked hosts and artists are left out
- [x] Tests: `tests/unit/test_event_discovery.py` (18, no database: distance, followed → near →
      soonest, the slot, every query is published and not over, empty bills and blocked
      artists left out, `include=events` asked for, one event on the first page only, none on
      an empty page); `tests/api/test_event_discovery.py` (4, against Postgres in CI: a host's
      upcoming list and the profile card on both profile payloads; ended, draft and cancelled
      events never appear anywhere; no card, a private account and a block; the feed's one
      event for an app that asks, a followed host first, none on the second page; Explore's
      shows with their pieces, not with a medium or on For You)
- [ ] The API tests run in CI only (no local Postgres here); check them on the next CI run
- [x] App: Home asks For You with `include=events` and shows the server's card (its lineup from
      the detail); with none (an older server) it still picks one from the Events tab, asked
      only once the feed has answered. Explore shows the Upcoming shows shelf; profiles show
      the Upcoming show card. The app does not call the host events route yet: the profile
      card comes with the profile

**Deploy.** No migration.

## B28. Hosting: age limit, visibility, rescheduling, artist approval and check-in — Pending

**Why.** The hosting boards need event fields and steps the server doesn't have. The app's
hosting flow is built for what exists (free RSVP with a cap, lineup, people, publish, edit,
cancel, guests, piece QR codes).

- [ ] `age_limit` (`all` | `18` | `21`), shown on the event page, Choose tickets and the ticket
      ("Bring your ID")
- [ ] `visibility` (`public` | `link`): link-only events stay out of browse and search but open
      from their link
- [ ] Reschedule (`HostReschedule`): `POST /api/events/<id>/reschedule` with new start, end and an
      optional message; move the event auction's window with it (or refuse only while bids
      exist); notify and email every guest; with B22, tickets refundable until the new start
      (today `PATCH` answers 409 for a published event's dates)
- [ ] Featured artist invites (`ArtistInvite`): participant status (`invited`, `accepted`,
      `declined`); the invite notifies the artist; `POST /api/events/<id>/invite/accept|decline`;
      only accepted artists show; the host sees Invited / Accepted
- [ ] Piece approval (`ArtistPieceRequest`): someone else's piece in a lineup starts `waiting`;
      the artist approves (optionally changing the price) or declines; approval ends the piece's
      own listing or auction (bidders told); host-owned pieces skip this; the host sees Waiting
      for / Approved by
- [ ] Check-in (`HostScanner`, with B22): `POST /api/events/<id>/tickets/<code>/check-in` (once per
      code; "already checked in at 8:14 PM"; "not a valid ticket"); by hand from the guest list;
      enter a code; a check-in count; offline scans sync without letting a code in twice; hosts
      and co-hosts only
- [ ] Co-hosts may edit the event and scan at the door
- [ ] The host picks when bidding ends (at the latest 30 minutes before the event ends, the
      default and today's rule)
- [ ] The event's time zone comes from its location, not the host's phone
- [ ] Tests: link-only events never list; a reschedule notifies guests once; only accepted
      artists and approved pieces show; a code checks in once across two devices

**Until live.** Details has no Age limit or Public; Lineup shows artists and pieces at once; a
published event's date is locked; Manage event offers the guest list instead of check-in.

## B29. Home feed: photos and series on feed pieces, a real For You, an Available filter — Done 2026-11-07 (not committed yet)

**Why.** `Main` / `NoteMain`: a piece with 2+ photos shows dots and swipes; a series row appears
between pieces; the feed is personalised. Today `GET /api/feed/for-you` is the Explore feed
newest first (`"stub": True`), with `images: []` and no `series`; the app's Available tab
filters loaded pages itself.

- [x] Feed pieces (For You, Following and Explore): the media goes to `piece_to_dict` (one query
      per page), so `images` lists every photo in order, the cover first. A piece saved before
      galleries has no media rows and still sends `images: []` (the app shows its cover)
- [x] `series` on pieces in a series: `id`, `name`, `pieceIds` (its public pieces in series
      order) and up to 6 `previewPieces` (`id`, `title`, `mediaUrl`, `listingState`, and
      `imageCount` for the card's photo count). Three queries per page however many series;
      a piece in no series has no `series` key
- [x] For You ranks: someone the viewer follows; then their taste (the piece's medium, mediums,
      or style tags match the onboarding mediums, styles or themes, case-insensitively) or
      someone whose work they liked or saved (their last 200 likes and saves); then the rest.
      Scenes rank by their author only (they carry no medium or tags). Newest first within a
      rank. The cursor carries the rank (`r<rank>|<time>|<id>`), so pages neither repeat nor
      skip across a rank change; an older `time|id` cursor reads as the first rank. A guest, or
      an account with nothing to go on, gets newest first. `"stub"` is now false
- [x] `GET /api/feed/for-you?available=1`: only pieces for sale and live (`available` or
      `auction_live`), no Scenes, ranked and paged the same way; no event card on those pages
- [x] Tests: `tests/unit/test_feed_extras.py` (19, no database: the cursor and an old one, the
      order, the rank SQL with and without signals, after-the-cursor SQL, the Available SQL,
      series in order with state and photo counts, at most 6 previews, no series asks once);
      `tests/api/test_feed_b29.py` (4, against Postgres in CI: three photos cover first; a
      series on its pieces and none on a piece outside one; Available never returns collected
      or ended; follows, then taste and likes, then the rest, and a guest newest first; the
      cursor holds across ranks)
- [x] `tests/factories.make_piece` takes a `title` (it passed `title` twice before, so any test
      naming its piece failed; B27's API tests needed this too)
- [ ] The API tests run in CI only (no local Postgres here); check them on the next CI run
- [x] App: the series card shows the piece's chip (Available, a live auction too, or
      Collected) in its caption bar and the photo count (stack icon, Mono 11) when there is
      more than one; Available asks `?available=1` for its own pages the first time it opens
      (refresh and paging on its own cursor), still filtering what comes back, so an older
      server that ignores the filter works as before

**Deploy.** No migration.

## B30. Sign-in: email check, login code, reset code, lockout, consent record — Done 2026-11-07 (not committed yet)

**Why.** Sign-in is email first: a new address goes to the code and profile steps, a known one to
Welcome back with a password or "Email me a login code instead"; five wrong passwords lock the
account for 15 minutes; reset is by a 6-digit code; `NoteSignIn3Profile` records when Terms and
Privacy were agreed to and which versions. Today `/api/auth/otp/verify` only answers
`{"verified": true}`, nothing says whether an email has an account, `/api/auth/reset-password`
takes a token, and B1 stores one `terms_version`.

- [x] `POST /api/auth/email/check {email}` → `{exists}`: 10 a minute from one address; a deleted
      account doesn't count
- [x] Codes have a `purpose` on `/otp/generate`, `/otp/resend` and `/otp/verify`: `signup` (the
      default, so older apps are unchanged), `login`, `reset`. Each keeps its own code, so a
      sign-up code can't be spent as a login. A login or reset code is only sent to an account
      (the answer is the same either way), is single use, and dies after five wrong guesses;
      verifying one is also held to 20 a minute from one address
- [x] `POST /api/auth/otp/verify` with `purpose: "login"` returns tokens and the refresh cookie
      like `/login`, and lifts a lock from wrong passwords
- [x] `purpose: "reset"` returns `{"resetToken"}`: single use, 10 minutes, stored like the emailed
      link's token. `/reset-password` takes it as `token` or `resetToken`; as with the link, the
      reset signs every session out
- [x] Wrong passwords counted per account (Redis): the fifth within 15 minutes locks password
      log-in for 15 minutes and says so (429, "… Log in with a code sent to your email, or try
      your password again in 15 minutes."); while locked the right password is refused too. A
      right password or a login code clears it. If Redis is down the lock is skipped, like the
      other rate limits
- [x] `users.privacy_version` beside `terms_accepted_at` and `terms_version`, set wherever the
      terms are agreed (sign-up, log-in with `acceptedTerms`, a login code with it, and
      `POST /api/user/me/accept-terms`), and sent as `privacyVersion`.
      `CURRENT_PRIVACY_VERSION` is `2026-10-10`: the privacy terms are in the Terms document
      today (there is no separate policy page), so it moves with the Terms until one ships
- [x] Tests: `tests/unit/test_sign_in_b30.py` (19, no database or Redis: the lock and its reset,
      accounts lock alone, Redis down locks nobody; codes single use and dead after five; each
      purpose its own code; the email check and its limit; a login code only to an account,
      signs in and lifts the lock, records both versions; a sign-up code isn't a login; a reset
      code gives a grant once; the sixth password refused even when right; the reset takes the
      grant); `tests/api/test_sign_in_b30.py` (6, against Postgres and Redis in CI: the check
      and its limit; a login code signs in once; none sent without an account; a reset code
      resets once; the lock and the code getting round it; sign-up records both versions)
- [ ] The API tests run in CI only (no local Postgres here); check them on the next CI run
- [ ] Not changed: the sign-up code check (`/otp/verify` without a purpose) still peeks without
      a guess limit, as before; worth the same five-guess limit later
- [x] App: Continue checks the email (a new one goes to the sign-up code, a known one to
      Welcome back); Welcome back offers "Email me a login code instead" and Forgot password?
      by code on the shared code screen, then Set a new password; locked, the password and
      Log in turn off with the server's line and only the code is offered. When the check
      isn't there or fails, the old Welcome back (Create an account, reset by link) stays

**Deploy.** Migration `049_user_privacy_version`.

## B31. Seller setup and profile: studio address, profile mediums — Mediums done 2026-11-08 (not committed); studio address on hold

**Why.** After Stripe, `SellerStudio` asks for the studio's street, city, ZIP and pickup notes
(private, for the shipper). `ProfileSeller` shows up to three mediums under the username, picked
in `EditProfile` (sellers only). Only buyer addresses exist, and the user has no mediums.

- [ ] A seller pickup address on the user (or an address with `kind: "studio"`), never in public
      payloads. **On hold** (shipping, 2026-11-05)
- [x] `users.profile_mediums` (JSONB, migration `051_profile_extras`): up to 3, in order (the
      first is their main one). Sent as `profileMediums` in `PATCH /api/user/me` (trimmed, blanks
      and repeats dropped, more than 3 or longer than 40 characters refused with 400; `[]`
      clears) and in every profile payload. Named `profileMediums`, not `mediums`: `mediums`
      already means the taste picked at sign-up (`taste_preferences.mediums`)
- [x] Tests: `tests/unit/test_profile_extras.py` (order, trimming, repeats, a fourth and the
      wrong types refused); `tests/api/test_profile_extras.py` (CI: round trip to the public
      profile, a fourth refused). The studio-address test waits with the address
- [ ] The API tests run in CI only; check them on the next CI run
- [x] App: Edit profile's Mediums row for sellers (the posting medium list, up to 3 in the order
      picked) and the line under the username on a seller's profile once they've posted
      ("Painting · Mixed media"). `phase13_account_test.dart`, `flow_profiles_test.dart`

**Until live.** Seller mode stays a Settings switch with Stripe setup; no studio address.
**Deploy.** Migration `051_profile_extras` (with B34's Private Collection).

## B32. Collected piece: the viewer's order, delivery window, hide from Collection — Pending

**Why.** `PieceCollectedOwner` shows the collector a delivery card (arrival window, On time /
Delayed, a 4-step tracker) and "Hide from my Collection"; `PieceCollectedArtist` shows "Pickup
Nov 5 · In 3 days". The piece payload doesn't link the viewer's order, and the shipment has no
arrival window or on-time flag.

- [ ] On a collected piece, `viewerOrder` (buyer or seller side): `id`, `status`, `pickupAt`,
      `arrivalWindow`, `onTime`, tracker steps
- [ ] `trackingUrl` on the shipment (the card's arrow opens the carrier)
- [ ] `POST /api/collection/<pieceId>/hide` and its undo
- [ ] Tests: the buyer and the seller each get their side; nobody else gets `viewerOrder`; a
      hidden piece leaves the Collection and comes back on undo

**Until live.** The page finds the viewer's order in the first page of Orders (or Sales) and
builds the card from its status and shipment: no arrival window, no On time / Delayed, no
pickup date; the arrow opens the order; Hide from my Collection isn't shown.

## B33. Scenes: save count, comment moderation, failed drafts — Done 2026-11-07 (not committed yet)

**Why.** `SceneViewer` shows Save and Comments with counts; `SceneComments` lets the artist
delete any comment and turn comments off; `Drafts` lists pieces and Scenes, including ones that
"Didn't publish. Tap to try again." Scene payloads have no save count, and Scene drafts aren't
stored on the server.

- [x] `saveCount` and `isSaved` on Scene payloads: the feeds, the detail, a profile's Scenes
      (which now carry the comment count and `isSaved` too) and Saved (whose comment count was 0)
- [x] `DELETE /api/comments/<id>` for the comment's writer and for the artist whose Scene or
      piece it is on (the sheet is shared); anyone else gets 404. Answers the new `commentCount`
      and emits `comment:deleted` to the target's room
- [x] `commentsOff` on posts, set by the artist with `PATCH /api/posts/<id> {commentsOff}`; a new
      comment on that Scene is refused (403, "Comments are off for this Scene."). The comments
      already there still list. A comment on a Scene or piece that doesn't exist is now 404 (it
      used to be saved against nothing)
- [x] `/share/post/<id>`: "A Scene by [name]", the caption, the thumbnail (or the photo), and
      `studio3://post/<id>`; a draft or deleted Scene answers not-found
- [x] `mediaUrls` on posts: create takes up to 10 photos for a photo Scene (one for video),
      each checked as the account's own; `mediaUrl` stays the first. Payloads always send
      `mediaUrls` (the one photo for an older Scene)
- [x] `linkedPieces` on Scene payloads, batched: id, title, picture, artist, price, listing state
      and an auction's bid; a deleted piece is left out, and a draft piece for anyone but its
      artist
- [x] `GET /api/user/me/drafts`: piece and Scene drafts together, newest edit first, each with
      `type`, `updatedAt`, `draftStep` and `publishFailed` (`updatedAt` is on every piece and
      Scene payload now). `draftStep` is set on create and PATCH (a short lower-case name the
      app chooses)
- [x] `publishFailed` on pieces and posts, set by the app with PATCH when going live failed;
      going live clears it and the step
- [x] Tests: `tests/unit/test_scenes_b33.py` (22, no database: the payload fields, photo
      limits, linked pieces in order without deleted or others' drafts, the writer or artist
      deleting and anyone else not, comments off refusing, the draft fields, drafts newest edit
      first, the share page and a draft without one); `tests/api/test_scenes_b33.py` (6, CI:
      the save count with save / unsave, only the writer and the artist delete, comments off
      until turned back on, photos and linked pieces round trip, drafts list both kinds with a
      failed publish, the share page)
- [ ] The API tests run in CI only; check them on the next CI run
- [ ] Not done: the server doesn't set `publishFailed` itself when it refuses a draft going
      live (the app tells it); an open comment sheet elsewhere doesn't drop a deleted comment
      until it reloads (the app doesn't listen for `comment:deleted` yet)
- [x] App: the viewer takes the save count and linked pieces from the Scene, shares
      `/share/post/<id>`, shows every photo, and the artist's More has Turn off / Turn on
      comments; the sheet says "Comments are off" in place of the field. Press and hold your
      own comment to delete it; the artist also gets Delete on anyone's. A Scene is saved as a
      draft, then taken live, so one that fails waits in Drafts ("Saved as draft" and Go to
      drafts on the error screen) and the server hears it. Drafts lists Scenes (40 × 71,
      caption or Untitled Scene, "Ready to post", SCENE · the last edit); tapping a failed one
      posts it, a ready one asks "Post this Scene?". A Scene link or notification opens the
      Scene. A server without the drafts list still gives piece drafts

**Deploy.** Migration `050_scene_extras`.

---

## B38. The artist's own auction — Done 2026-11-09 (not committed yet)

**Why.** The canvas's Bidding row (2026-11-09) adds four screens for the artist on their own
auction (`ArtistAuctionLive`, `ArtistAuctionEnd`, `ArtistAuctionPayment`, `ArtistAuctionUnsold`).
The bid summary had no list of bids, no count of people, and nothing at all once an auction
closed without a sale (the detail carries only a running or settling auction). The user said to
build it. No payments are involved.

- [x] `GET /api/pieces/<id>/auction/bids` (artist only; anyone else 404, signed out 401)
      (`src/modules/bids/seller_view.py`, `auction_controller.bid_history`, route in
      `pieces_routes.py`): every bid in the run (running, else settling, else the latest, as
      B18), newest first, each `{bidder, amountCents, createdAt, isTop}`. `bidder` is a number
      by when each person first bid, kept for the run; nobody is named. Also `bidCount`,
      `bidderCount`, and `nextBidCents` (the best offer from anyone but the top bidder, the
      winner once there is one: what a second chance would be at)
- [x] `lastAuction` on the piece detail, for its artist only, when nothing is running or being
      settled: `{auctionId, status, startingBidCents, reserveCents, topBidCents, bidCount,
      bidderCount, closedAt}`. The top bid is read from every bid in the run, since a close
      without a sale voids them. No migration
- [x] Tests: `tests/unit/test_seller_view_b38.py` (9, no database: numbering, nobody named, top
      bidder and the next offer before and after a winner, no bids, the ended run, only when
      nothing runs, no auction, only the artist reads the bids); `tests/api/test_seller_view_b38.py`
      (2, CI: the artist reads the bids and nobody else; an unsold run on the artist's page only)
- [ ] The API tests run in CI only; check them on the next CI run
- [x] App: `widgets/auction/artist_auction.dart` on the piece page; `AuctionService.bidHistory`,
      `EndedAuction` on `PieceSummary` / `FeedPreviewItem`. `test/new_ui/artist_auction_test.dart`

## B37. A profile's Collection — Done 2026-11-08 (not committed yet)

**Why.** The user (2026-11-08): the profile's tabs are Pieces, Scenes and Collection as on the
boards, and "Collection will be the art purchased by the user on the platform". Nothing listed
another user's purchases (only `/me/orders` for yourself); this was decision D9. The user said
to build it.

- [x] `GET /api/users/<username>/collection` (`src/modules/user/collected.py`, route in
      `users_content_routes.py`): the pieces in their orders with status paid, shipped,
      awaiting_confirmation or completed (the same `COMPLETED_STATUSES` the profile's
      `collectedCount` counts), newest purchase first, each piece once, at most 200, deleted
      pieces left out. Each is the usual piece payload with `author` {username, name,
      profilePhotoUrl} and without `priceCents` / `currency` ("No prices")
- [x] Same rules as their Pieces: a private account only for the owner and their followers
      (403), 404 either side of a block or for an unknown name. Read-only: no order, payment or
      shipping logic changes. No migration
- [x] Tests: `tests/unit/test_collection_tab_b37.py` (6, no database: each piece once, the tile
      has the artist and no price, empty list, unknown name, private refused, block hides it);
      `tests/api/test_collection_tab_b37.py` (2, CI: only paid-and-later orders count, newest
      first, artist, no price; a private Collection only for its owner)
- [ ] The API tests run in CI only; check them on the next CI run
- [ ] Later: B34's Private Collection switch should hide this list from everyone but the owner
- [x] App: the Collection tab (`profile_collection_grid.dart`, `PieceService.getUserCollection`;
      an older server's 404 is an empty tab). `flow_profiles_test.dart`

---

## B36. A private profile's header for someone who doesn't follow — Done 2026-11-08 (not committed yet)

**Why.** `ProfilePrivate` (canvas, 2026-11-08): on a private account you don't follow, "photo,
name, username, following count, bio and stats stay visible", and Message shows "only if the
owner allows messages from everyone". `GET /api/user/<username>` answers such a viewer with
username, name, profilePhotoUrl, profileVisibility, isFollowing and followRequestPending only
(`user_controller.get_public_profile`).

- [x] The locked answer (`profile_extras.locked_header`) now also has `coverPhotoUrl`, `bio`,
      `role`, `followingCount`, `collectedCount`, `artistsCount`, `savesCount` and
      `messagePermission`. Still no `followersCount`, `piecesCount` or `pieces` (the app reads a
      locked profile by those being absent; the board shows no followers count), and still
      nothing from the pieces, posts or series lists
- [x] `artistsCount` (how many artists they've bought from: distinct sellers of their paid and
      later orders, `collected.count_artists`) on every profile payload too, for the collector's
      collected · artists · saves
- [x] Tests: `tests/unit/test_profile_extras.py` (the locked header has the board's keys and
      none of the gated ones); `tests/api/test_profile_extras.py` (CI: a stranger gets the bio,
      counts and message setting, no followers or pieces count)
- [ ] The API tests run in CI only; check them on the next CI run
- [x] App (built 2026-11-08): shows each of these once sent and leaves it off until then;
      Message appears only for `messagePermission: "everyone"`. `flow_profiles_test.dart` covers
      both answers

---

## B35. Events in collections — Done 2026-11-08 (not committed yet)

**Why.** The user asked (2026-11-08) for saving to work as on Instagram everywhere there is a
Save, a piece, a Scene or an event: it saves at once, then "Save to collection" offers every
folder and New collection. Folders took pieces and Scenes only, so an event couldn't go in one.

- [x] `POST /api/collections/<id>/items` and `DELETE …/items/event/<id>` take `targetType:
      "event"`. An event can go in once it is out (published, cancelled or archived); a draft
      only for its host, otherwise 404. A bad id is 404, not a 500
- [x] `GET /api/collections/<id>` lists event items as the event card (`event_card`) with
      `targetType: "event"`; an older app skips a type it doesn't know. A folder's cover can be
      an event's cover picture
- [x] No migration: `collection_items.target_type` is a free 16-character string
- [x] Tests: `tests/unit/test_collection_events_b35.py` (9, no database: what counts as out, a
      draft only for its host, the cover, adding an event, someone else's draft refused, a bad
      type or id); `tests/api/test_collection_events_b35.py` (2, CI: an event goes in a folder,
      shows in its detail and cover, and comes out; someone else's draft can't be added)
- [ ] The API tests run in CI only; check them on the next CI run
- [x] App: every Save (piece pages, the Scene viewer and a Scene's page, the events tab, event
      lists and the event page, and "Save to hear if it comes back" after an auction) saves at
      once and shows "Added to Collection" with "Save to collection"; that opens the folders
      (ticked where it already is), New collection last; Done adds and removes. A folder
      opened from the server keeps its events

---

## B34. Settings: Private Collection, going public, turning off selling, deleting with work in progress — Pending

**Why.** Flow 12 (`HandoffSettings`, added to the canvas 2026-11-06). Most Settings rows use
endpoints that exist (name, email with a code, phone, password, log out of all devices, profile
visibility, who can message you, blocked accounts, follow requests, saved cards, addresses with a
default). These do not:

- [x] Private Collection (`SettingsPrivacy`), built 2026-11-08: `users.collection_private`
      (default false, migration `051_profile_extras`) as `collectionPrivate` in `PATCH
      /api/user/me` (a boolean, else 400) and on your own profile only. When on,
      `GET /api/users/<username>/collection` (B37) answers an empty list to everyone but the
      owner, followers too. Tests: `tests/unit/test_profile_extras.py` (the owner alone sees
      it), `tests/api/test_profile_extras.py` (CI: a follower gets nothing, the owner gets it).
      App: the switch between Who can message you and Blocked accounts ("Only you see the pieces
      you own"), shown once the server sends the flag. `settings_test.dart`
- [ ] Going public approves everyone waiting (`SettingsFollowRequests`): turning off Private
      account accepts every pending follow request and tells each person. Until then the app
      approves them one by one after going public (`privacy_settings_page.dart`)
- [ ] Turn off seller profile (`SettingsSelling`): today it is refused while anything is listed.
      The board takes the listings and auctions without bids down instead (pieces stay as not for
      sale) and refuses only while an auction has bids or a sale is shipping
- [ ] Delete account with work in progress (`SettingsDelete`): `GET /api/user/me/deletion-check`
      listing what blocks it (a running auction, a piece shipping to or from them, a pending
      payout, upcoming events they host with tickets); the delete refuses while that list is not
      empty. Confirmation by typing DELETE, not the password: a decision (the password stays a
      re-authentication step unless the user says otherwise). Until then the app builds the
      list from listings, sales and purchases (`delete_account_page.dart`), and the delete
      itself does not refuse over a pending payout
- [ ] Log out of all devices keeps this phone (`SettingsAccount`): `POST /api/auth/logout-all`
      revokes every session, this one too; the board keeps this phone signed in (revoke all but
      the calling session's refresh token)
- [ ] The piece on each order (`SettingsSales`, `SettingsPurchases`): `GET /api/user/me/sales` and
      `/me/orders` items carry only `pieceId`, so the app reads every piece for its title and
      picture. Add `piece: {id, title, mediaUrl, listingType}` to each item in `order_to_dict`
      (and whether it was an auction, for SOLD or AUCTION on the row)
- [ ] Seller terms with the account's own rate (`SettingsSelling` "Includes fees"): the
      commission quote already returns the rate; check `/terms` can show it
- [ ] Tests: Private Collection hides the Collection from followers and strangers but not the
      owner; going public accepts every pending request once; turning off selling takes down
      listings and unbid auctions and refuses with bids or a shipping sale; the deletion check
      lists each kind of blocker and the delete refuses while any remain

**On hold (payment and shipping, 2026-11-05):** the default card for auction wins
(`SettingsPayment`), the studio pickup address (`SettingsSelling`, B31), ticket rows in Sales
and Purchases (B22), pickup and delivery steps on Sales rows (B32).

**Until live.** The Settings boards are built on what exists; Private Collection, the deletion
check and the new turn-off behaviour are hidden or keep today's behaviour.

## Server bugs found while building auctions

From reading the code (not run). B16 is the first.

- [ ] After `auction-checkout`, a cancelled or abandoned balance order (`orders.expire_abandoned`,
      15 minutes) delists the piece while the hammer price stays captured and is not refunded;
      the winner can no longer check out
- [ ] `bid_hold_expired` notifications have no target
- [ ] Bidding again after a hold expires leaves two active bids
- [ ] Cancelling a draft auction answers 200 but leaves it in place
- [ ] `docs/API.md` says relist works only from `needs_seller_action`; the code also accepts
      `closed_no_bids` and `closed_reserve_not_met` (fix the doc or the code)
- [ ] `create-payment-intent` sets no customer or payment method, so the balance after an
      auction can't be charged to the saved card without the buyer (the app uses the payment
      sheet)

## Keep deployed: restored app features

Restored in the app on 2026-10-25 (plan 12.2). These endpoints exist today; keep them working:

- [x] Events: `GET /api/events`, `GET /api/events/browse`, `GET /api/events/<id>`, `POST/DELETE
      /api/events/<id>/save`, `POST /api/events/<id>/rsvp`, `GET /api/events/<id>/attendees`
- [x] Hosting: `POST /api/events`, `PATCH /api/events/<id>`, `PUT /api/events/<id>/people`,
      `POST/DELETE /api/events/<id>/pieces[/<pieceId>]`, `GET .../pieces/<pieceId>/tagging-preview`,
      `POST /api/events/<id>/publish`, `POST /api/events/<id>/cancel`
- [x] QR codes for pieces at an event: `GET /api/events/<id>/qr-codes`
- [x] Payouts (Stripe Connect): `POST /api/artists/connect`, `GET /api/artists/connect/status`,
      `GET /api/artists/connect/dashboard`
- [x] My reports: `GET /api/reports/mine`; report actions `POST /api/{pieces,posts,users}/<id>/report`
- [x] Seller auction controls: `POST /api/pieces/<id>/auction/extend`, `.../cancel`, `.../relist`
- [x] Saved cards: `GET /api/payments/payment-methods`, `POST /api/payments/setup-intent`, `DELETE
      /api/payments/payment-methods/<id>`
- [x] Share links and app links: `https://api.studio-3.co/share/{piece,series,event}/<id>` and the
      `/.well-known/` files (`src/modules/share`)
- [x] Push taps: push data `{type, targetType, targetId, actorUsername}` (sent by
      `notifications_dao`) routes to the piece, Scene, series, order, event or profile

## Not planned

- A drafts page on the server for "Go to drafts": it opens the artist's profile, where drafts
  already show. (Scene drafts and `GET /api/user/me/drafts` came with B33.)

## Template for new entries

```
## B<n>. <change> — Pending

**Why.** <board / note and what the app shows>

- [ ] Schema (<migration>): <columns>
- [ ] API: <endpoint, request fields, response fields, validation>
- [ ] Tests: <file and what it checks>

**Until live.** <what the app does against the current server>
```

Add a row to the Overview too.
