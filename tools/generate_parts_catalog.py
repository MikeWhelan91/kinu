#!/usr/bin/env python3
"""Generate the Supabase migration that lets My Kinu parts sync and lists them for admins.

Parts are defined in scripts/kinu/kinu_parts.gd rather than catalog.tres. Re-run this after
adding or renaming a part, then apply the migration before shipping the client that owns it.
"""

import pathlib
import re


ROOT = pathlib.Path(__file__).resolve().parents[1]
PARTS = ROOT / "scripts/kinu/kinu_parts.gd"
OUTPUT = ROOT / "supabase/migrations/20261001010000_my_kinu_parts.sql"
KEY = "^(outfit|part|box|room):[a-z0-9_]+$"


def sql(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def main() -> None:
    rows = []
    pattern = r'\["([a-z0-9_]+)", "(body|hat|arms|glasses)", "([^"]+)", "[a-z_]+", "[0-9a-f]+", "[0-9a-f]+", "([a-z:]+)", -?\d+\]'
    for item_id, _slot, name, source in re.findall(pattern, PARTS.read_text()):
        rarity = ""
        if source == "starter":
            kind = "included"
        elif source == "level":
            kind = "level"
        elif source.startswith("crane:"):
            kind, rarity = "claw", source.split(":", 1)[1]
        elif source in ("common", "rare", "epic"):
            kind, rarity = "shop", source
        else:
            kind = "goal"
        rows.append((f"part:{item_id}", name, "part", rarity, kind))
    if not rows or len(rows) != len({row[0] for row in rows}):
        raise SystemExit("No parts found, or a duplicate part key")
    values = ",\n".join("  (" + ", ".join(map(sql, row)) + ")" for row in rows)
    migration = f"""-- My Kinu parts. Generated from scripts/kinu/kinu_parts.gd by tools/generate_parts_catalog.py.
-- Apply before shipping the client that reports part:* items: until then the stricter key check
-- rejects the whole report, so no new ownership is recorded for that player.
alter table public.player_inventory drop constraint if exists player_inventory_item_key_check;
alter table public.player_inventory add constraint player_inventory_item_key_check
  check (item_key ~ '{KEY}');

alter table public.inventory_catalog drop constraint if exists inventory_catalog_kind_check;
alter table public.inventory_catalog add constraint inventory_catalog_kind_check
  check (kind in ('outfit', 'part', 'box', 'room'));

insert into public.inventory_catalog (item_key, display_name, kind, rarity, source)
values
{values}
on conflict (item_key) do update set
  display_name = excluded.display_name,
  kind = excluded.kind,
  rarity = excluded.rarity,
  source = excluded.source;

create or replace function public.record_owned_items(p_items text[])
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  player_id uuid := auth.uid();
  inserted_count integer;
begin
  if player_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if p_items is null or cardinality(p_items) > 256 or exists (
    select 1 from unnest(p_items) as owned(item_key)
    where item_key is null or item_key !~ '{KEY}'
  ) then
    raise exception 'Invalid inventory';
  end if;

  insert into public.player_inventory (user_id, item_key)
  select player_id, item_key from (select distinct unnest(p_items) as item_key) owned
  on conflict do nothing;
  get diagnostics inserted_count = row_count;
  insert into public.inventory_syncs (user_id, last_synced_at, reported_item_count)
  values (player_id, now(), cardinality(p_items))
  on conflict (user_id) do update set
    last_synced_at = excluded.last_synced_at,
    reported_item_count = excluded.reported_item_count;
  return inserted_count;
end;
$$;
revoke all on function public.record_owned_items(text[]) from public, anon;
grant execute on function public.record_owned_items(text[]) to authenticated;
"""
    OUTPUT.write_text(migration)
    print(f"Wrote {len(rows)} parts to {OUTPUT}")


if __name__ == "__main__":
    main()
