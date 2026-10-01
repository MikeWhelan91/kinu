# My Kinu: design proposal

Status: **proposal, awaiting decisions** (see [Decisions needed](#decisions-needed)). Nothing here is implemented.

My Kinu is one personal Kinu per player. It levels up from play, unlocks equipment slots (body, hat, arms first), and wears parts the player earns or buys. In the Wardrobe the player picks either **My Kinu** or one of the existing complete outfits. Every Kinu dropped in a run then wears that look. Customisation is visual only.

## 1. What exists today

| Area | Where | What matters for My Kinu |
|---|---|---|
| Outfit data | `scripts/kinu/kinu_outfit.gd`, `resources/kinu/catalog.tres` (109 outfits) | Complete looks. A *costume* has a `style`, built procedurally. A *pattern outfit* has a `finish` (gold, crystal…) that replaces the body look. Source fields: `price`, `goal`, `crane_only`, `showcase`, `event`, `rarity`, `available`. |
| Rendering | `KinuModel.build(shape, flavour, outfit, mood)` in `scripts/kinu/kinu_model.gd` | Body mesh cached per `shape/flavour`, costume per `shape/outfit`. Non-`BARE_STYLES` costumes hide the body and add an `ExposedFace` patch in the flavour colour. One style, one monolithic builder; no notion of parts. Side "paw" spheres (`_outfit`, ~line 421) are the nearest thing to arms; base Kinu has none. |
| Physics | `KinuBody.setup` in `scripts/kinu/kinu_body.gd` | Mass, friction, bounce, hitbox and centre of mass all come from `KinuShape` only. The outfit only changes `visual`. The ghost sheet's `fit` is a visual transform. **Customisation already cannot touch physics if it stays inside `visual`.** |
| Equipped look | `Save.data.outfit` (one id) | Read in about 10 places: `NestRun.make_body` / `pattern_for`, `toss_play.gd`, the landing ghost, the results/pause mascot, `home_tour.gd`, `tutorial_coach.gd`, the next-piece card in `main.gd`, `outfit_best` records, and `summary().dressed` for the daily "dressed" mission. |
| Flavours | `kinu_flavour.gd`, 27 flavours | Flavour is **gameplay-visible**: the "New flavour" discovery moment, daily "land N *flavour*" missions, flavour unlocks by best pile. `pattern_for` deliberately applies a pattern outfit only to flavours the player has *found*, so a discovery always shows its true look. |
| Specials | `make_body` | Lucky forces the gold finish over any outfit. Tiny scales the body. Sticky adds `KinuModel.sticky_coat(shape, outfit)`. Heart adds a badge. |
| Ownership | `Save.data.owned` (`"kind:id"`), `Save.owns`, `Save.buy` | Kinds are `outfit`, `box` and `room`. Goal items count as owned once their stat is met. Catcher, showcase and event items are owned only when granted. |
| Shop / Wardrobe | `scripts/ui/kinu_shop.gd`, `scripts/ui/wardrobe_screen.gd` | Shared tabs: Outfits, Boxes, Rooms. The Wardrobe lists owned items plus "No Outfit"; tapping opens a live spin preview with **Wear**. |
| Catcher | `scripts/systems/kinu_catcher.gd` | 6% cosmetic chance, rarity roll, owned items leave the pool, pity at 20. These odds are published in `docs/purchases.md`. |
| Run end | `run.end()` → `finished` → `main._results` → `NestMenuScreen.results` → `Save.finish_run` | `finish_run` is the **only** place lifetime progress is recorded. Pause → Restart / Main Menu never reach it (comment at `menu_screen.gd:304`). `end()` guards against running twice. Beans are added by a separate `add_earned_beans` call after `finish_run`. |
| Save | `scripts/systems/save_manager.gd`, version 5 | `load_data` starts from `defaults()` and copies only known, validated keys, so unknown keys are dropped. Migrations are `version < N` blocks. |
| Cloud | `cloud_kvs_service.gd`, iCloud KVS, about 2.4 KB snapshot | The snapshot is the whole save minus session and debug keys, so new fields travel automatically. `cloud_snapshot_valid` rejects snapshots from a newer save version. |
| Supabase inventory | `scripts/systems/inventory_sync.gd`, `supabase/migrations/20260930040000_player_inventory.sql` | Both the client regex and a DB `CHECK` allow only `^(outfit|box|room):`. A new kind is silently not synced until both change. |

## 2. Player flow

1. **Introduction.** After the player's first finished run (or right away for existing players after the update), the results screen shows "Meet My Kinu" with a Level 1 badge. The body slot is open with a free starter item.
2. **Results screen.** Every finished run shows an XP bar filling, and a level-up banner when one happens. A level that opens a slot says so ("Hat slot unlocked!") with a **Customise** shortcut. Level rewards (parts, beans) appear in the existing rewards list.
3. **Wardrobe.** A pinned **My Kinu** card sits first in the Outfits tab, before "No Outfit" and the owned outfits. It shows the assembled look and the level. Tapping it opens the My Kinu screen with a **Wear My Kinu** button. Tapping any other outfit works exactly as now. One card is marked "Wearing".
4. **My Kinu screen.** A live spin preview at the top, a level and XP bar, and a row of slot chips. Locked slots show "Lv N". Below is a grid of owned parts for the chosen slot, plus "Nothing" for that slot. A flavour/shape preview toggle cycles the preview through shapes and a few found flavours, so the player sees the look across what will actually drop. "Get more in the Shop" links to the Parts tab.
5. **Shop.** A new **Parts** tab, filtered by slot. Parts for locked slots are visible but marked "Unlocks at Lv N" (see decision D5).
6. **In a run.** If My Kinu is selected, every Kinu dropped (Classic, Tower, Toss), the landing ghost, the next-piece card and the mascots all render the assembled parts over each Kinu's own shape and flavour.

## 3. Slot unlock order

The proposed default keeps the early levels quick and puts the three requested slots first:

| Level | Unlock |
|---|---|
| 1 | **Body** slot + free starter body item |
| 2 | **Hat** slot + free starter hat |
| 4 | **Arms** slot + free starter arms |
| 7 | Face accessory (glasses, blush stickers, mask) *(optional, later content)* |
| 10 | Back (cape, wings, backpack) *(optional)* |
| 14 | Tail *(optional)* |
| Every other level | Beans, or a part from that level's reward table |

Body, hat and arms are the committed scope. Later slots are listed only so the save format and UI leave room for them.

## 4. XP rules

**Grant point.** XP is computed and added **inside `Save.finish_run`**, in the same `persist()` as runs, best and stats. That path only runs when a run reaches results, so:

- Pause → Restart and Pause → Main Menu grant nothing, because they never call `finish_run`.
- Quitting the app mid-run grants nothing.
- Each run grants once. As a guard against any future second call (re-rendering results, a revive feature), `NestRun.begin()` stamps a `run_id` into the summary. `finish_run` records it in `my_kinu.last_run`, and a repeated id grants nothing.

**Formula** (to tune with `tools/economy_sim.gd`):

```
xp = placed                         # 1 per Kinu actually landed, every mode
   + (10 if placed >= 5 else 0)     # finish bonus, only for a real attempt
   + (10 if new mode best else 0)
```

- `placed` already exists in every mode's summary and measures actual play. Instantly losing a run earns almost nothing.
- Toss `placed` may run at a different rate per minute than Classic. The simulation should check that XP per minute is within about ±25% across modes.
- No XP from purchases, the Catcher, missions or daily treats. **XP is earned only by playing** (see D8).
- Tutorial runs that reach results count.

**Level curve.** XP to go from level L to L+1 is `60 + 20·(L−1)`. With a typical 25–35 XP per run:

| Level | Cumulative XP | ≈ runs |
|---|---|---|
| 2 | 60 | 2 |
| 4 | 240 | 7 |
| 10 | 1,260 | 36 |
| 20 | 4,560 | 130 |

Level is derived from total XP and never stored separately, so it can't drift. The cap is open (see D9).

## 5. Item ownership model

- **New resource `KinuPart`**: `id`, `slot` (`body`/`hat`/`arms`/…), `display_name`, `description`, `style` (builder key), colours, and the same source fields as `KinuOutfit`: `price`, `rarity`, `goal`/`goal_amount`, `crane_only`, `showcase`, `event`, `available`. It also gets a new `level` field for level rewards. It is stored in `KinuCatalog.parts`.
- **Ownership** reuses `Save.data.owned` with a new kind: `"part:<id>"`. `Save.owns("part", id)` follows the same rules as outfits (goal parts owned once met, Catcher/showcase/event/level parts owned when granted). Part ids are globally unique, so the key does not need the slot.
- **Starter parts** (one per slot, price 0) are owned automatically. Level-reward parts are granted into `owned` in the `finish_run` that reaches that level, so they persist and sync like any other item.
- **Equipping** goes through a new `Save.equip_part(slot, id)` and is never routed through `Save.buy`. `buy` sets `data[kind] = id`, which does not fit slots. A part can be equipped only if it is owned **and** its slot is unlocked. `""` means the slot is empty.
- **Existing outfits stay complete looks.** They are not split into parts. Every current `outfit:*` entry and the current `outfit` selection are untouched.

### Save shape (version 6)

```jsonc
"look": "outfit",                  // "outfit" | "my_kinu"; what runs wear
"outfit": "frog",                  // unchanged; remembered while My Kinu is worn
"my_kinu": {
  "xp": 0,
  "equipped": {"body": "", "hat": "", "arms": ""},
  "last_run": "",                  // idempotency guard
  "seen_level": 1                  // for "new slot" banners and the fresh dot
}
```

`load_data` validates each key:

- `xp` is clamped to 0…2^31.
- `equipped` keeps only known slots with String ids. An unknown id falls back to `""` at render time, not at load, so a newer catalogue on another device isn't wiped.
- `look` must be one of the two values.

## 6. Body customisation, flavours and shapes

**This is the main open decision (D1). I have not assumed an answer.**

Constraints from the current code:

- Flavour colour is the player's only cue for flavour missions and the discovery moment. `pattern_for` already protects undiscovered flavours from being restyled.
- Existing non-bare costumes hide the body but keep the **face opening in the flavour colour** (`ExposedFace`). The costume review calls this out as deliberate.
- Lucky Kinu must stay gold: catching them is a mission and a stat.

Options for what a **body** item does:

| | Option | Flavour legibility | Customisation feel | Notes |
|---|---|---|---|---|
| A | **Preserve.** Body items are garments (overalls, shirt, apron, scarf wrap) and surface patterns layered over the flavour-coloured tofu, like today's `BARE_STYLES`. | Full | Medium | Lowest risk. Builds on the overalls/pirate code path. |
| B | **Replace on found flavours only.** The body item sets the body colour and finish, like a pattern outfit. Undiscovered flavours keep their own look. | Lost for found flavours (missions get harder) | High | Same rule `pattern_for` uses. Flavour missions would need an on-piece badge. |
| C | **Tint.** Blend the custom colour with the flavour colour and keep the flavour's surface pattern (speckles, petals, stars). | Partial | Medium-high | Needs per-flavour contrast checks; dark flavours (Galaxy) tint poorly. |
| D | **Player choice.** A "Keep flavour colours" toggle on the My Kinu screen chooses between A and B. | Player's choice | High | Most UI and test work: two render paths. |

Whichever option is picked, these rules apply:

- **Lucky** stays gold. Hat and arms still show, so Lucky reads as "my Kinu, but gold".
- **Undiscovered flavours** always show their true colour, matching `pattern_for`.
- **Glass and jelly flavours** never make parts transparent; parts use the opaque fabric material, as costumes do.
- **Light-face flavours** keep pale features.

**Shapes.** There are five shapes: block, slab, long, tall and ball. Each has a different size and roundness, and each is its own hitbox.

- Every part must have a builder that renders on all five shapes, sized from `shape.size` the way costumes are: hats anchored at `h.y*1.08`, arms at the sides like the paw spheres, body garments wrapped with `Face`.
- A part may adapt per shape (a beret on *long* sits off-centre), but it may never be missing on any shape.
- Tiny Kinu scale with the body. The sticky coat and glaze keep using the shape outline.
- Visual protrusion: hats and arms stick out past the hitbox the way ears and wings already do. Hats are capped at about 0.35 × shape height so a stacked pile still reads clearly. The landing ghost shows parts, so the player sees the same silhouette they drop.

**Physics guarantee.** Parts live only under `KinuBody.visual`. `KinuBody.setup` keeps taking mass, friction, hitbox and centre of mass from `KinuShape` alone. A test asserts all four are identical with and without every loadout.

## 7. Risks and compatibility

- **Existing players:** `owned`, `outfit`, `outfit_best` and every goal or Catcher ownership are preserved. The v5→v6 migration only adds `look: "outfit"` and `my_kinu` defaults, so nobody's look changes on update.
- **Downgrade:** an older build loading a v6 save drops `my_kinu` and `look` on its next save, because `load_data` ignores unknown keys. iCloud is protected because `cloud_snapshot_valid` rejects a newer version, but a local TestFlight downgrade would reset My Kinu. This is acceptable; note it in release notes.
- **Supabase:** add `part` to the client regex in `inventory_sync.gd` **and** to the DB `CHECK`, using a new migration file. Also add part rows to `inventory_catalog` (`tools/generate_inventory_catalog.py`). Ship the migration before the client.
- **Catcher:** adding parts to the pool dilutes the per-item odds that `docs/purchases.md` publishes and changes how soon the pity guarantee completes a collection (D6).
- **Performance:** each Kinu would gain up to six mesh instances (three parts plus outlines). Merge the equipped parts into one mesh per shape when the run starts, cached as `shape/loadout-hash`, so a My Kinu Kinu costs the same draw calls as a costume today. Verify with `tests/performance.tscn`.

## Decisions needed

| # | Decision | My recommendation |
|---|---|---|
| **D1** | Does a custom body colour **replace** or **preserve** flavour colours (options A–D in §6)? | **A (preserve)** for the first release; consider C later. |
| D2 | Body, hat and arms at levels 1/2/4, or all three open at level 1? Do you want slots after arms? | 1/2/4; extra slots later. |
| D3 | Existing players: start at level 1, or get retroactive XP from lifetime `stats.total` (capped, for example at level 5)? | Retroactive, capped at level 4, so veterans start with all three slots. |
| D4 | Default `look` for **new** players: My Kinu or No Outfit? | My Kinu once introduced after the first run. Existing players stay on their current outfit. |
| D5 | Can parts for still-locked slots be bought or won? | Visible but not buyable; excluded from the Catcher until unlocked. |
| D6 | Should parts enter the Kinu Catcher pool? This changes the published odds. | Not in the first release. Add later with a docs/odds update. |
| D7 | Shop prices and rarities for parts, relative to outfits (outfits are priced as complete looks). | Each part about 30–40% of a same-rarity outfit. Confirm with the economy sim. |
| D8 | Is XP ever purchasable or boostable (XP packs, double-XP events)? | No. Play only, as specified. |
| D9 | Level cap, and rewards after the last slot. | No cap. Beans every level, and a part reward every 5 levels. |
| D10 | Does My Kinu with at least one part count for the daily "dressed" mission? How does Records → best by outfit show it? | Yes. Show one "My Kinu" row in Records. |

## Build stages (after decisions)

Each stage is shippable behind `look == "outfit"` (no visible change) until stage 4 exposes the selection.

1. **Save migration and XP core**
   - `KinuPart` resource and `KinuCatalog.parts`.
   - Save v6: `look`, `my_kinu`, validation in `load_data`, the migration block, and the D3 retroactive XP.
   - `Save.owns`/`equip_part` for kind `part`.
   - XP and level-reward grants inside `finish_run`, with the `run_id` guard. `xp_gained` and `level_before/after` added to the results data.
   - Tests in `tests/my_kinu.gd`:
     - A finished run grants once; replaying the summary grants 0.
     - Pause → Restart and Pause → Main Menu grant 0.
     - A v5 save keeps every `owned` entry, `outfit` and `outfit_best`.
     - Cloud snapshots round-trip v6, and a v5 snapshot migrates.
     - Update `tests/cloud_save` and `tests/integration`.
2. **Character rendering**
   - Let `KinuModel.build` accept an appearance: a complete outfit, or parts plus the D1 rule.
   - Per-slot builders for the starter set of 3–4 parts per slot on all five shapes.
   - Merged-mesh cache.
   - Lucky, Tiny, Sticky and glaze compatibility.
   - Tests:
     - A `tests/parts.gd` grid like `tests/costumes.gd`: parts × shapes × moods × flavours and finishes.
     - The physics-invariance test.
     - A `tools/parts_sheet` render.
     - `tests/performance`.
3. **Customisation screen**
   - My Kinu screen: preview, level and XP bar, slot chips with lock state, part grid and equip.
   - Shape/flavour preview cycling.
   - Fresh dots for new parts and slots.
   - `tests/ui` click navigation, and `tests/visual -- screen=my_kinu` at 393×852 and 360×640.
4. **Run appearance selection**
   - Replace direct `Save.data.outfit` reads with one `Save.current_appearance()`, covering:
     - `make_body`
     - Toss
     - the landing ghost
     - the next card
     - the mascots, home tour and tutorial coach
     - `summary().dressed`
     - `outfit_best`/Records
   - Add the Wardrobe My Kinu card and the "Wearing" state.
5. **Shop and reward integration**
   - Shop Parts tab.
   - Level-up banner and rewards on results.
   - Kinu Book entries for goal or level parts.
   - Supabase migration (`part` kind and catalogue rows) plus the client regex.
   - Analytics events (level up, equip, look switch).
   - Translations (ja, ko, zh_TW).
   - Run `tools/economy_sim.gd` and update `docs/purchases.md` if D6 changes the Catcher.

Stages 1 and 2 can proceed in parallel. Stage 4 depends on both, and stages 3 and 5 on stage 4.
