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

The Catcher gives two free tickets per rolling 24-hour cycle, timed by the
server from the first free play in that cycle. Free tickets appear in the
displayed balance alongside purchased and won tickets, but refill to two rather
than stacking. Free tickets are spent before stored tickets.
One of the three daily missions also grants one ticket when claimed, alongside
its bean reward. The other two missions remain bean-only, for up to one earned
ticket per day.

## Catcher balance

- A normal play has a fixed 15% cosmetic chance, regardless of catalogue size.
- Cosmetic wins roll rarity at 55% common, 25% rare, 13% epic and 7% legendary,
  renormalising only if a rarity has no unowned prizes left.
- After 14 consecutive plays without an item, play 15 is guaranteed to be an
  unowned item.
- Owned cosmetics leave the pool, so every item won is new. The pool holds shop
  and Catcher-only outfits, boxes and rooms, plus the 53 shop My Kinu parts and
  18 Catcher-only parts. Part starters, level rewards and goal parts are never in
  the machine.

Full table for a fresh player (195 items in the pool):

| Prize | Chance |
|---|---|
| Any item | 15.00% |
| · Common (72 items) | 8.25%, about 0.115% each |
| · Rare (66 items) | 3.75%, about 0.057% each |
| · Epic (35 items) | 1.95%, about 0.056% each |
| · Legendary (22 items) | 1.05%, about 0.048% each |
| Tickets | 9.00% (1: 5.58%, 2: 2.43%, 3: 0.99%) |
| Beans | 75.97% (50: 31.33%, 100: 23.50%, 200: 12.53%, 400: 6.27%, 1,000: 2.35%) |
| 15,000-bean jackpot | 0.03% |

The in-game Odds page recalculates this over the items a player still lacks.

Run payouts use `NestRun.RUN_BEAN_SCALE` (currently 1.0, the original rates) as a
single tuning knob; Lucky, Heart and Gold catch bonuses are never scaled. My Kinu
levels past 50 pay 1 Catcher ticket every 5 levels. `tools/simulate_collection.py --trials 200` models the whole economy
(runs, missions, calendar, weekly, Claw, shop, My Kinu levels and goals) and puts
the median time to collect everything a player can reach at about 290 days for
casual players (3 runs a day), 113 days for regular (6) and 91 days for
dedicated (12). These are simulated play patterns, not guaranteed rewards.

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
