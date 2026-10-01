-- Permanent cosmetic ownership, keyed by the reward account already used by the game.
-- The client can only call record_owned_items for its own authenticated user.
create table if not exists public.player_inventory (
  user_id uuid not null references auth.users(id) on delete cascade,
  item_key text not null check (item_key ~ '^(outfit|box|room):[a-z0-9_]+$'),
  first_seen_at timestamptz not null default now(),
  primary key (user_id, item_key)
);

create index if not exists player_inventory_item_key_idx
  on public.player_inventory (item_key);

alter table public.player_inventory enable row level security;
revoke all on public.player_inventory from anon, authenticated;

-- A single idempotent call records everything this player currently owns. Items are never
-- deleted: the game does not revoke cosmetics, and an incomplete local save must not erase
-- ownership already seen on another device.
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
  return inserted_count;
end;
$$;

revoke all on function public.record_owned_items(text[]) from public, anon;
grant execute on function public.record_owned_items(text[]) to authenticated;

-- Visible in the SQL Editor, but not exposed to anonymous or app users.
create or replace view public.inventory_owner_counts as
select item_key, count(*)::bigint as owners
from public.player_inventory
group by item_key;

revoke all on public.inventory_owner_counts from public, anon, authenticated;
