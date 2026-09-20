# Beans, Tickets and Extras

The home bean wallet and the cosmetic shop's **Get Beans & Extras** button open
the same purchase screen. Players can switch between bean and Kinu Catcher ticket
packs. The back arrow returns to the originating page.

| Product ID | Type | Delivery |
|---|---|---|
| `com.kinutumble.app.beans.bag` | Consumable | 300 beans |
| `com.kinutumble.app.beans.pouch` | Consumable | 1,000 beans, including 100 bonus |
| `com.kinutumble.app.beans.jar` | Consumable | 2,400 beans, including 400 bonus |
| `com.kinutumble.app.beans.pantry` | Consumable | 6,500 beans, including 1,500 bonus |
| `com.kinutumble.app.tickets.trio` | Consumable | 3 Kinu Catcher tickets |
| `com.kinutumble.app.tickets.bundle` | Consumable | 10 Kinu Catcher tickets |
| `com.kinutumble.app.tickets.stack` | Consumable | 25 Kinu Catcher tickets |
| `com.kinutumble.app.tickets.roll` | Consumable | 60 Kinu Catcher tickets |
| `com.kinutumble.app.removeads` | Non-consumable | Permanent ad-removal entitlement |

Prices are fetched from StoreKit and displayed in the customer's currency. No
fallback dollar price is used for buying. Missing products are disabled and can
be requested again using Retry. Desktop builds do not simulate transactions.

The Catcher gives one free play each calendar day. That free play is a daily
entitlement rather than a stored ticket, so unused free plays do not stack.
One of the three daily missions also grants one ticket when claimed, alongside
its bean reward. The other two missions remain bean-only, for up to one earned
ticket per day.

## Catcher balance

- A normal play has a fixed 6% cosmetic chance, regardless of catalogue size.
- Cosmetic wins roll rarity at 78% common, 17% rare, 4% epic and 1% legendary,
  renormalising only if a rarity has no unowned prizes left.
- After 19 consecutive bean prizes, play 20 is guaranteed to be an unowned item.
- Owned cosmetics leave the pool. Forty Catcher-exclusive outfits currently
  provide 30 common and 10 rare designs, all visible in the Kinu Book.

Remove Ads is wired for delivery, refund handling, and restoration, but sales
are disabled with `Store.ADS_ENABLED` until a real ad integration is present.
AdMob IDs supplied by the owner are saved in `resources/monetization.cfg`.
These IDs alone do not serve ads; consent, SDK integration, test-unit selection,
placements and rewarded callbacks still need implementation.

## Native dependency

The split GodotApplePlugins StoreKit 2 framework and its Swift runtime were
copied from this owner's existing CritterScale project. They require iOS 17+.
The extension manifest makes Godot embed both frameworks during iOS export.
There are no native macOS libraries in this payload; desktop Godot reports an
unsupported-platform extension warning and the app uses its unavailable state.

Upstream source: https://github.com/migueldeicaza/GodotApplePlugins
Licences are included in each addon directory. No backend secrets are bundled.

## Delivery and recovery

- Only the native verified-transaction callbacks grant products.
- Direct purchase completion and asynchronous transaction updates both deliver.
- Balance and transaction ID are saved together before calling `finish()`.
- Replayed transaction IDs do not credit again. IDs are stored as strings.
- Failed saves roll back the in-memory balance and leave the transaction
  unfinished, with a Retry path; StoreKit redelivers unfinished purchases.
- Pending approval and cancellation do not grant currency.
- Known refunds reverse their credited beans once, clamped at zero; ad-removal
  refunds revoke the entitlement. No negative balances are introduced.
- Restore Purchases explicitly asks Apple to sync, then requests current
  entitlements and unfinished transactions. It does not replay spent consumables.

Bean and ticket balances and cosmetic ownership currently use the game's local
save and backup. Finished consumable purchases cannot reconstruct an unspent balance after the
app's data is deleted or on another device. Account/cloud wallet recovery and a
server transaction ledger are not implemented in this change.

## Validation

Run `tests/purchases.tscn` for delivery, duplicate events, cancellation, pending
approval, failed persistence, refunds, localized pricing and restoration tests.
`tests/ui.tscn` checks both entry points and their back navigation using clicks.
Use `tests/visual.tscn -- screen=beans aspect=393x852` or
`tests/visual.tscn -- screen=tickets aspect=393x852` for the purchase layouts.

On-device debug logs print the bridge status and fetched public product IDs and
prices. Do not log signed receipts. Real purchase confirmation is left to the
owner using a Sandbox Apple Account or TestFlight; no chargeable purchase should
be made as part of automated verification. The five existing IAPs in the owner's
setup screenshot were marked Prepare for Submission. The four ticket consumables
listed above still need to be created in App Store Connect, and all products need
App Review before sales.
