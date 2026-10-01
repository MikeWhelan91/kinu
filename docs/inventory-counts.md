# Supabase collection inventory

## What is running

The live Kinu Supabase project is
[vuskhjibjumukigdtmrk](https://supabase.com/dashboard/project/vuskhjibjumukigdtmrk).
It uses the game's existing anonymous reward account: players do not need an email, password,
or separate inventory sign-in. The iOS build has the project URL and publishable key in
`project.godot` under `[supabase]`; no database password or service-role key belongs in the app.

The game records explicitly acquired outfits, boxes, and rooms. At launch it requests the
current account's recorded items, merges any missing items into the local save, and reports
the resulting collection. It reports again after ownership changes. A failed read or write
retries while the app is open; the local save remains usable. The direct database RPCs do not
consume Edge Function invocations.

| Component | Purpose |
| --- | --- |
| `player_inventory` | One permanent row per anonymous account and acquired item; `first_seen_at` records when Supabase first received it. |
| `inventory_catalog` | Names, types, rarity, and acquisition source for 282 catalog items: 162 outfits/boxes/rooms and 120 My Kinu parts, including items with no owners. |
| `inventory_syncs` | Last report time and reported item count per account, including an empty collection. |
| `record_owned_items(text[])` | Adds missing ownership rows for the signed-in account and updates its sync record. Repeated reports do not increase owner counts; previously recorded items are not deleted. |
| `get_owned_items()` | Returns only the signed-in account's recorded cosmetics for recovery. |
| `inventory_overview`, `inventory_players`, `inventory_player_items` | Dashboard views for aggregate counts, account syncs, and each account's item list. |

The database setup is in `supabase/migrations/20260930040000_player_inventory.sql`,
`supabase/migrations/20260930050000_inventory_admin.sql`, and
`supabase/migrations/20261001010000_my_kinu_parts.sql`, and
`supabase/migrations/20261001020000_more_my_kinu_parts.sql`; their SQL has been applied to the live
project. The Godot client is `scripts/systems/inventory_sync.gd`, with HTTP requests in
`scripts/systems/reward_service.gd`. For another Supabase project, enable anonymous sign-ins,
configure its URL and publishable key, and apply the migrations in filename order. The
inventory RPCs require an authenticated anonymous session. The broader reward setup is in
`docs/supabase-daily-rewards.md`.

## See the inventory

In the Supabase dashboard, open **Table Editor** and select `inventory_overview` for every
catalog item, its name, type, rarity, source, and owner count, including zero owners.
`inventory_players` shows one row per account and its last report time. `inventory_player_items`
shows each account's recorded items. Filter that view by `user_id` to inspect one account.
These views are admin only; the game has no general read access to other players' inventories.
The `outputs/kinu_content_inventory/kinu_content_inventory.xlsx` workbook is a planning
snapshot, not a live Supabase report; use the dashboard queries for current owner counts.

**Live check, 1 October 2026:** `inventory_catalog` contains 120 unique `part:` entries,
exactly 30 in each slot in the client: 4 included, 35 goal, 10 level, 53 shop
(24 common, 19 rare, 10 epic), and 18 Claw-only (10 rare, 8 legendary).
The SQL Editor returned 120 live parts, zero missing among the 56 new keys, zero orphaned
part ownership rows, and confirmed the `record_owned_items` report limit is now 1,024.
The previous exact comparison of the original 64 keys found zero missing or unexpected.
The workbook includes all 120 alongside the original 162 cosmetics. The SQL was applied
through the dashboard; this does not itself mark the migration as applied in the Supabase
CLI's migration history.

Saved SQL Editor links in the live Kinu project:

- [Inventory overview](https://supabase.com/dashboard/project/vuskhjibjumukigdtmrk/sql/3cdb0c6a-59db-46f2-b2c5-6ec471eab1e3) lists all 282 cosmetics and parts with owner counts.
- [Player inventories](https://supabase.com/dashboard/project/vuskhjibjumukigdtmrk/sql/57f103a4-4ea1-420f-827e-adfe3a6370f8) lists account IDs and their items.
- [Inventory owner counts](https://supabase.com/dashboard/project/vuskhjibjumukigdtmrk/sql/e76fd113-e4e7-4fb2-bbcf-5cc17385b213) is the original compact count query.

## Supabase commands

Paste the following SQL into the live project's **SQL Editor** and click **Run**. These are
read-only queries; none changes player inventory.

**All items and owner counts** (including zero owners):

```sql
select item_key, display_name, kind, rarity, source, owners
from public.inventory_overview
order by owners desc, display_name;
```

**Lucky Cat owners:**

```sql
select owners as lucky_cat_owners
from public.inventory_overview
where item_key = 'outfit:maneki';
```

**Recently synced accounts:**

```sql
select user_id, last_synced_at, reported_item_count, recorded_items
from public.inventory_players
order by last_synced_at desc
limit 50;
```

**One account's collection:** copy a `user_id` from the preceding result and replace the UUID
below. This lets you see which named items Supabase has recorded for that account.

```sql
select display_name, kind, rarity, source, first_seen_at
from public.inventory_player_items
where user_id = '00000000-0000-0000-0000-000000000000'::uuid
order by kind, display_name;
```

**Catalog entries with no reported owner:**

```sql
select item_key, display_name, kind, source
from public.inventory_overview
where owners = 0
order by kind, display_name;
```

### CLI commands for future database changes

The Supabase CLI is not currently installed or linked in this checkout, and the existing Kinu
migrations were applied in the dashboard's SQL Editor. First reconcile the remote migration
history with the SQL that is already live; otherwise a `db push` may try to replay it. From
the repository root, after [installing the CLI](https://supabase.com/docs/guides/local-development/cli/getting-started):

```sh
supabase init                         # creates supabase/config.toml if absent
supabase login
supabase link --project-ref vuskhjibjumukigdtmrk
supabase migration list --linked      # compare local and remote history first
```

After confirming which existing migrations really ran, record only those missing from the
history with `supabase migration repair <timestamp> --status applied`. This command updates
history; it does not execute SQL. For a *new, reviewed* migration:

```sh
supabase migration new inventory_change
supabase db push --dry-run             # inspect the pending migration list
supabase db push                       # apply only after history is reconciled
```

See the [Supabase CLI migration guide](https://supabase.com/docs/guides/local-development/cli-workflows)
for the current command workflow. Do not use `db reset --linked` on this live project: it
recreates the remote database.

## Recovery and limits

Counts are anonymous reward accounts, not verified unique people. A player who gets a new
anonymous account on another device may be counted twice. Existing owners appear after they
launch a version of the game containing the inventory sync; older builds cannot backfill them.
Cosmetic restoration works only when the same anonymous reward account survives reinstall
(the iOS Keychain normally retains it). The full game save, scores, beans, tickets, and purchase
ledger remain in the game's iCloud save; they are not restored from this inventory table.
`first_seen_at` is when Supabase first received an item, not necessarily when it was earned.
Ownership reports originate in the client, so these counts are for analytics and recovery,
not a fraud-resistant source for paid entitlements or prizes. The inventory table is not
directly readable or writable by the app. Its RPCs are scoped to the caller's own account.

When the game catalog changes, run `python3 tools/generate_inventory_catalog.py` to regenerate
the catalog migration before applying it to a new Supabase project. For an already deployed
project, create a new seed migration for newly added items rather than replaying old migrations.
