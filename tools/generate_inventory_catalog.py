#!/usr/bin/env python3
"""Generate the item catalog seed used by the Supabase inventory migration."""

import pathlib
import re


ROOT = pathlib.Path(__file__).resolve().parents[1]
CATALOG = ROOT / "resources/kinu/catalog.tres"
OUTPUT = ROOT / "supabase/migrations/20260930050000_inventory_admin.sql"


def sql(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def main() -> None:
    contents = CATALOG.read_text()
    blocks = re.findall(
        r'\[sub_resource type="Resource" id="((?:outfit|box|room)_[^"]+)"\]\n(.*?)(?=\n\[|\Z)',
        contents,
        re.S,
    )
    rows = []
    for resource_id, body in blocks:
        fields = dict(re.findall(r'^(\w+) = "([^"]*)"$', body, re.M))
        kind = resource_id.split("_", 1)[0]
        item_id = fields["id"]
        name = fields["display_name"]
        if fields.get("event"):
            source = "event"
        elif fields.get("showcase"):
            source = "showcase"
        elif re.search(r"^crane_only = true$", body, re.M):
            source = "claw"
        elif fields.get("goal"):
            source = "goal"
        elif re.search(r"^price = 0$", body, re.M):
            source = "included"
        else:
            source = "shop"
        rows.append((f"{kind}:{item_id}", name, kind, fields.get("rarity", ""), source))

    if len(rows) != len({row[0] for row in rows}):
        raise SystemExit("Duplicate catalog item key")

    values = ",\n".join("  (" + ", ".join(map(sql, row)) + ")" for row in rows)
    migration = f"""-- Admin inventory browser. Generated from resources/kinu/catalog.tres by
-- tools/generate_inventory_catalog.py. These are catalog labels, not client-provided data.
create table if not exists public.inventory_catalog (
  item_key text primary key,
  display_name text not null,
  kind text not null check (kind in ('outfit', 'box', 'room')),
  rarity text not null,
  source text not null
);
alter table public.inventory_catalog enable row level security;
revoke all on public.inventory_catalog from anon, authenticated;

insert into public.inventory_catalog (item_key, display_name, kind, rarity, source)
values
{values}
on conflict (item_key) do update set
  display_name = excluded.display_name,
  kind = excluded.kind,
  rarity = excluded.rarity,
  source = excluded.source;

-- A sync record shows when this app last reported a collection, including an empty one.
create table if not exists public.inventory_syncs (
  user_id uuid primary key references auth.users(id) on delete cascade,
  last_synced_at timestamptz not null default now(),
  reported_item_count integer not null default 0
);
alter table public.inventory_syncs enable row level security;
revoke all on public.inventory_syncs from anon, authenticated;

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
    where item_key is null or item_key !~ '^(outfit|box|room):[a-z0-9_]+$'
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

-- Every catalog entry appears, including items with no reported owners.
create or replace view public.inventory_overview as
select c.item_key, c.display_name, c.kind, c.rarity, c.source,
       count(p.user_id)::bigint as owners
from public.inventory_catalog c
left join public.player_inventory p on p.item_key = c.item_key
group by c.item_key, c.display_name, c.kind, c.rarity, c.source;
revoke all on public.inventory_overview from public, anon, authenticated;

-- Anonymous account IDs help inspect one account's collection without exposing auth tokens.
create or replace view public.inventory_players as
select s.user_id, s.last_synced_at, s.reported_item_count,
       count(i.item_key)::bigint as recorded_items
from public.inventory_syncs s
left join public.player_inventory i on i.user_id = s.user_id
group by s.user_id, s.last_synced_at, s.reported_item_count;
revoke all on public.inventory_players from public, anon, authenticated;

create or replace view public.inventory_player_items as
select p.user_id, p.item_key,
       coalesce(c.display_name, p.item_key) as display_name,
       split_part(p.item_key, ':', 1) as kind,
       coalesce(c.rarity, '') as rarity,
       coalesce(c.source, 'unknown') as source,
       p.first_seen_at
from public.player_inventory p
left join public.inventory_catalog c on c.item_key = p.item_key;
revoke all on public.inventory_player_items from public, anon, authenticated;

-- The game may read only its own permanent cosmetics for recovery after reinstall.
create or replace function public.get_owned_items()
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'items', coalesce(jsonb_agg(item_key order by item_key), '[]'::jsonb)
  )
  from public.player_inventory
  where user_id = auth.uid();
$$;
revoke all on function public.get_owned_items() from public, anon;
grant execute on function public.get_owned_items() to authenticated;
"""
    OUTPUT.write_text(migration)
    print(f"Wrote {len(rows)} items to {OUTPUT}")


if __name__ == "__main__":
    main()
