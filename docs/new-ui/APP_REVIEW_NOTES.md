# Studio 3: notes for Apple's App Review

For App Store Connect → the app version → **App Review Information**. Launch checklist 1.6
(`docs/new-ui/APPLE_LAUNCH_CHECKLIST.md`). Written 18 Nov 2026 from what the app and the live
server do today; every statement below was checked in the code.

Three parts: what to set up before submitting (the notes rely on it), the fields to fill in, and
the notes text to paste.

## 1. Set up before submitting

The notes point the reviewer at these. Without them, the instructions don't work and the review
can fail on completeness (Guideline 2.1).

- [ ] The `artist` review account has a piece for sale, a running auction, an upcoming
      published event with tickets, and one past order (launch checklist 2.2).
- [ ] A **test piece** for the reviewer to buy: $1, listed by a second account (not `artist`),
      titled "App Review test piece". Put its seller's handle in the notes where they say
      `@[TEST SELLER]`. Whoever runs that account cancels the reviewer's order within 24 hours
      (Orders → the order → Cancel order), which refunds the card in full.
- [ ] A **test event**: published, hosted by any account other than `artist`, with a $1
      **refundable** ticket type, titled "App Review test event". The reviewer buys a ticket
      and refunds it from the ticket page.
- [ ] Sign-up emails reach any address (AWS SES production access, client list). Until then a
      new account's code only reaches verified addresses; the notes steer the reviewer to the
      demo account, but they may still try signing up.
- [ ] Apple Wallet: if passes aren't switched on at the live server yet (client list), the "Add
      to Apple Wallet" button is hidden. The notes cover both cases; delete the bracketed
      sentence once Wallet is on.
- [ ] Replace every `[...]` in section 3, then check the pasted text is under 4,000 characters
      (App Store Connect's limit; the text below is 2,865 as written).

## 2. App Review Information fields

| Field | Value |
| --- | --- |
| Sign-in required | Yes |
| User name | `artist` |
| Password | From the password manager. **Never commit it to this repo.** |
| Contact first and last name | The person who will answer Apple within a day |
| Contact phone | (214) 506-0426, or that person's number |
| Contact email | support@studio-3.co |
| Notes | Section 3 below |
| Attachment (optional) | A screenshot of a ticket's QR code, so the reviewer can test door check-in from a second device |

## 3. Notes to paste

```
Studio 3 is a marketplace and social app for independent artists in the United States. Artists post their work, sell pieces at a fixed price or by auction, and host in-person events with tickets. Collectors browse, buy, bid and attend.

SIGN IN
Please use the demo account in the Sign-In Information (user name: artist). It is an artist account with a piece for sale, a running auction, an upcoming event with tickets and a past order. An account is needed because everything in the app (follows, purchases, bids, tickets, messages) belongs to a person.

PAYMENTS (no in-app purchase)
Everything sold is a physical artwork or a ticket to an in-person event, so payments go through Stripe (Guidelines 3.1.3(e) and 3.1.5(a)). No digital content or features are sold. Payments are live. Every step up to the card sheet can be tried without paying. To complete a purchase, buy "App Review test piece" ($1) from @[TEST SELLER]; we cancel that sale within 24 hours, which refunds the card in full automatically.

AUCTIONS
Your card is checked and saved at your first bid. Nothing is charged unless you win. When an auction ends, the winner's saved card is charged for the winning bid, plus shipping, insurance and tax.

SHIPPING
Pieces ship through our shipping partner, Convelio. The shipping price is quoted at checkout from the delivery address. We ship within the United States only.

EVENT TICKETS
Open the Events tab, pick an event and tap Get tickets. "App Review test event" has $1 refundable tickets: buy one, open it to see its QR code, then refund it from the ticket page to get the money back.

APPLE WALLET
On a ticket, "Add to Apple Wallet" adds a pass with the same QR code as the app. [If the button isn't shown, Wallet passes aren't switched on yet; the QR code in the app works the same.]

DOOR CHECK-IN (hosts)
As the demo artist, open the upcoming event, tap Manage event, then Check in guests. Scan a ticket's QR code with the camera, type the ticket's code, or check a guest in by hand from the guest list. Scanning keeps working without a connection and syncs when it's back.

USER CONTENT AND SAFETY
Everyone agrees to the Terms of Use when signing up: zero tolerance for objectionable content or abusive users. Pieces, posts, comments and profiles have Report and Block in their menu. Reports are reviewed within 24 hours; blocking hides that person's content at once.

ACCOUNT DELETION
Profile, then Settings (the gear), then Delete account. It removes the profile, pieces, Scenes and messages; sale records are kept as the law requires.

PERMISSIONS
Camera: taking photos to post, scanning tickets. Photos: choosing work to post, saving QR codes. Location (while using the app): nearby artists and events. Calendar: adding an event you're going to. The app keeps working if any of these is declined.

CONTACT
support@studio-3.co, (214) 506-0426
```

## 4. Where each statement comes from

Checked 18 Nov 2026, so the notes can be kept true when the app changes.

| Statement | Source |
| --- | --- |
| First bid checks and saves the card; nothing held; winner charged at close (bid, shipping, insurance, tax) | Server `src/modules/bids/auction_payments.py` (auctions v2); app fine print in `lib/widgets/auction/auction_widgets.dart` |
| Buyer cancels only before paying; after payment the seller's Cancel order refunds in full | `lib/screens/order_detail_page.dart` (`_buyerActions`, `_sellerActions`, "The buyer will be refunded in full") |
| Ticket refunds from the ticket page | `lib/screens/event_ticket_page.dart` (`refundTickets`) |
| Wallet button only when the server offers passes | `lib/widgets/events/event_wallet_button.dart` (`showsFor`) |
| Check in guests: scan, type a code, or by hand; offline scanning | `lib/screens/host/host_manage_page.dart`, `host_scanner_page.dart`, `host_guest_list_page.dart`, `lib/services/offline_check_in.dart` |
| Report and Block on pieces, posts, comments, profiles; "within 24 hours" | `lib/widgets/content_actions_sheet.dart`, `piece_detail/piece_more_sheet.dart`, `profile_page.dart`, `terms_page.dart` |
| Terms agreement with zero-tolerance line at sign-up | `AuthTermsCheckbox` in `lib/widgets/auth_ui.dart` |
| Delete account in Settings; what it removes | `lib/screens/profile_settings_page.dart`, `delete_account_page.dart` |
| Account required, no signed-out browsing | `lib/utils/app_routes.dart`, `lib/screens/login_page.dart` |
| No third-party sign-in (so Sign in with Apple isn't required, Guideline 4.8) | `pubspec.yaml`: no Google, Facebook or Apple sign-in packages; email and code only |
| Permission uses | `ios/Runner/Info.plist` usage texts |
| US only | Launch doc (shipping and artist payouts are US only) |

Change the notes when any of these changes. In particular, if push notifications ship
(checklist 1.8), add a line saying what they're for.
