-- Admin inventory browser. Generated from resources/kinu/catalog.tres by
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
  ('outfit:tanuki', 'Tanuki', 'outfit', 'rare', 'shop'),
  ('outfit:bunny', 'Bunny', 'outfit', 'common', 'shop'),
  ('outfit:bat', 'Bat', 'outfit', 'epic', 'shop'),
  ('outfit:fox', 'Fox', 'outfit', 'rare', 'shop'),
  ('outfit:frog', 'Frog', 'outfit', 'common', 'shop'),
  ('outfit:leaf', 'Little Leaf', 'outfit', '', 'goal'),
  ('outfit:pirate', 'Pirate', 'outfit', 'rare', 'shop'),
  ('outfit:ninja', 'Ninja', 'outfit', 'common', 'shop'),
  ('outfit:panda', 'Panda', 'outfit', 'common', 'shop'),
  ('outfit:dino', 'Dino', 'outfit', 'rare', 'shop'),
  ('outfit:astronaut', 'Astronaut', 'outfit', '', 'goal'),
  ('outfit:ghost', 'Ghost', 'outfit', '', 'goal'),
  ('outfit:shark', 'Shark', 'outfit', 'rare', 'shop'),
  ('outfit:strawberry', 'Strawberry', 'outfit', 'common', 'shop'),
  ('outfit:tiger', 'Tiger', 'outfit', 'rare', 'shop'),
  ('outfit:dragon', 'Dragon', 'outfit', '', 'goal'),
  ('outfit:wood', 'Wood', 'outfit', '', 'goal'),
  ('outfit:marble', 'Marble', 'outfit', '', 'goal'),
  ('outfit:crystal', 'Crystal', 'outfit', '', 'goal'),
  ('outfit:galaxy', 'Galaxy', 'outfit', '', 'goal'),
  ('outfit:gold', 'Gold', 'outfit', '', 'goal'),
  ('box:hinoki', 'Hinoki', 'box', '', 'included'),
  ('box:bamboo', 'Bamboo Steamer', 'box', '', 'goal'),
  ('box:lacquer', 'Red Lacquer', 'box', 'rare', 'shop'),
  ('box:sakura', 'Sakura', 'box', 'rare', 'shop'),
  ('box:stone', 'Stone', 'box', 'rare', 'shop'),
  ('box:goldbox', 'Gold', 'box', 'epic', 'shop'),
  ('room:shop', 'Tofu Shop', 'room', '', 'included'),
  ('room:night', 'Night Market', 'room', 'rare', 'shop'),
  ('room:winter', 'Winter', 'room', '', 'goal'),
  ('room:sakura_street', 'Sakura Street', 'room', '', 'goal'),
  ('outfit:hatchling', 'Just Hatched', 'outfit', '', 'goal'),
  ('outfit:parcel', 'Parcel', 'outfit', '', 'goal'),
  ('outfit:onsen', 'Onsen Day', 'outfit', '', 'goal'),
  ('outfit:nigiri', 'Salmon Nigiri', 'outfit', 'common', 'shop'),
  ('outfit:bee', 'Bee', 'outfit', 'common', 'shop'),
  ('outfit:daruma', 'Daruma', 'outfit', '', 'goal'),
  ('outfit:tako', 'Tako', 'outfit', 'rare', 'shop'),
  ('outfit:kappa', 'Kappa', 'outfit', 'rare', 'shop'),
  ('box:wicker', 'Wicker', 'box', '', 'goal'),
  ('box:candy', 'Candy Stripe', 'box', 'common', 'shop'),
  ('box:gift', 'Gift Box', 'box', 'common', 'shop'),
  ('box:jubako', 'Jubako', 'box', 'epic', 'shop'),
  ('box:ice', 'Ice', 'box', '', 'goal'),
  ('box:neon', 'Neon', 'box', 'epic', 'shop'),
  ('room:bamboo_grove', 'Bamboo Grove', 'room', 'rare', 'shop'),
  ('room:autumn_temple', 'Autumn Temple', 'room', 'rare', 'shop'),
  ('room:onsen', 'Onsen', 'room', 'epic', 'shop'),
  ('room:festival', 'Summer Festival', 'room', 'epic', 'shop'),
  ('room:moon_viewing', 'Moon Viewing', 'room', '', 'goal'),
  ('room:neon_alley', 'Neon Rooftop', 'room', 'epic', 'shop'),
  ('outfit:kitsune', 'Kitsune', 'outfit', 'legendary', 'claw'),
  ('outfit:phoenix', 'Phoenix', 'outfit', 'legendary', 'claw'),
  ('outfit:unicorn', 'Unicorn', 'outfit', 'legendary', 'claw'),
  ('outfit:maneki', 'Lucky Cat', 'outfit', 'legendary', 'showcase'),
  ('outfit:samurai', 'Samurai', 'outfit', 'epic', 'shop'),
  ('outfit:koi', 'Koi', 'outfit', 'epic', 'shop'),
  ('outfit:axolotl', 'Axolotl', 'outfit', 'rare', 'shop'),
  ('outfit:kimono', 'Kimono', 'outfit', 'epic', 'shop'),
  ('outfit:oni', 'Oni', 'outfit', 'epic', 'shop'),
  ('outfit:capybara', 'Yuzu Capybara', 'outfit', 'rare', 'shop'),
  ('outfit:chick', 'Baby Chick', 'outfit', 'common', 'shop'),
  ('outfit:shiba', 'Shiba Pup', 'outfit', 'common', 'shop'),
  ('outfit:calico', 'Calico Kitty', 'outfit', 'common', 'shop'),
  ('outfit:bear_cub', 'Honey Bear', 'outfit', 'common', 'shop'),
  ('outfit:hamster', 'Hamster', 'outfit', 'common', 'shop'),
  ('outfit:penguin', 'Baby Penguin', 'outfit', 'common', 'shop'),
  ('outfit:duckling', 'Duckling', 'outfit', 'common', 'shop'),
  ('outfit:seal', 'Mochi Seal', 'outfit', 'common', 'shop'),
  ('outfit:otter', 'Little Otter', 'outfit', 'common', 'shop'),
  ('outfit:red_panda', 'Red Panda', 'outfit', 'common', 'shop'),
  ('outfit:mushroom', 'Mushroom Cap', 'outfit', 'common', 'shop'),
  ('outfit:peach', 'Peachy', 'outfit', 'common', 'shop'),
  ('outfit:lemon', 'Lemon Drop', 'outfit', 'common', 'shop'),
  ('outfit:cupcake', 'Cupcake', 'outfit', 'common', 'shop'),
  ('outfit:pudding', 'Purin Pudding', 'outfit', 'common', 'shop'),
  ('outfit:boba', 'Boba Tea', 'outfit', 'common', 'shop'),
  ('outfit:melonpan', 'Melonpan', 'outfit', 'common', 'shop'),
  ('outfit:donut', 'Sprinkle Donut', 'outfit', 'common', 'shop'),
  ('outfit:marshmallow', 'Marshmallow', 'outfit', 'common', 'shop'),
  ('outfit:taiyaki', 'Taiyaki', 'outfit', 'common', 'shop'),
  ('outfit:cloud_outfit', 'Tiny Cloud', 'outfit', 'common', 'shop'),
  ('outfit:star_outfit', 'Twinkle Star', 'outfit', 'common', 'shop'),
  ('outfit:moon_outfit', 'Sleepy Moon', 'outfit', 'common', 'shop'),
  ('outfit:sunflower', 'Sunflower', 'outfit', 'common', 'shop'),
  ('outfit:daisy', 'Daisy Chain', 'outfit', 'common', 'shop'),
  ('outfit:sailor', 'Tiny Sailor', 'outfit', 'common', 'shop'),
  ('outfit:raincoat', 'Puddle Pal', 'outfit', 'common', 'shop'),
  ('outfit:overalls', 'Berry Overalls', 'outfit', 'common', 'shop'),
  ('outfit:artist', 'Little Artist', 'outfit', 'common', 'shop'),
  ('outfit:sleepy_cap', 'Sleepy Cap', 'outfit', 'common', 'shop'),
  ('outfit:magical_girl', 'Magical Kinu', 'outfit', 'rare', 'claw'),
  ('outfit:moon_princess', 'Moon Princess', 'outfit', 'rare', 'claw'),
  ('outfit:candy_witch', 'Candy Witch', 'outfit', 'rare', 'claw'),
  ('outfit:celestial_bunny', 'Celestial Bunny', 'outfit', 'rare', 'claw'),
  ('outfit:sakura_deer', 'Sakura Deer', 'outfit', 'rare', 'claw'),
  ('outfit:royal_frog', 'Frog Prince', 'outfit', 'rare', 'claw'),
  ('outfit:pastel_dragon', 'Pastel Dragon', 'outfit', 'rare', 'claw'),
  ('outfit:snow_fox', 'Snow Fox', 'outfit', 'rare', 'claw'),
  ('outfit:jellyfish', 'Dream Jellyfish', 'outfit', 'rare', 'claw'),
  ('outfit:fairy', 'Kinu Fairy', 'outfit', 'rare', 'claw'),
  ('outfit:builder', 'Builder Helmet', 'outfit', '', 'goal'),
  ('outfit:acrobat', 'Balance Pole', 'outfit', '', 'goal'),
  ('outfit:chef', 'Shoyu Chef', 'outfit', '', 'goal'),
  ('outfit:yukata', 'Festival Yukata', 'outfit', '', 'goal'),
  ('outfit:climber', 'Mountain Climber', 'outfit', '', 'goal'),
  ('outfit:lucky_charm', 'Lucky Charm', 'outfit', '', 'goal'),
  ('outfit:jelly_cube', 'Jelly Cube', 'outfit', 'common', 'shop'),
  ('outfit:rose_delight', 'Rose Delight', 'outfit', 'common', 'shop'),
  ('outfit:chocolate_square', 'Chocolate Square', 'outfit', 'rare', 'shop'),
  ('outfit:burger', 'Burger Stack', 'outfit', 'rare', 'shop'),
  ('outfit:snack_box', 'Joyful Snack Box', 'outfit', 'rare', 'shop'),
  ('outfit:sea_sponge', 'Sunny Sea Sponge', 'outfit', 'epic', 'shop'),
  ('outfit:bread_loaf', 'Bread Loaf', 'outfit', 'common', 'shop'),
  ('box:kintsugi', 'Kintsugi', 'box', 'legendary', 'claw'),
  ('box:treasure', 'Treasure Chest', 'box', 'legendary', 'claw'),
  ('box:geode', 'Amethyst Geode', 'box', 'legendary', 'showcase'),
  ('box:gachapon', 'Capsule Toy', 'box', 'legendary', 'claw'),
  ('box:taiko', 'Taiko Drum', 'box', 'epic', 'shop'),
  ('box:shortcake', 'Shortcake', 'box', 'rare', 'showcase'),
  ('box:starry', 'Starry Night', 'box', 'epic', 'shop'),
  ('box:koi_pond', 'Koi Pond', 'box', 'epic', 'shop'),
  ('box:cloud', 'Cloud', 'box', 'rare', 'shop'),
  ('box:raden', 'Mother of Pearl', 'box', 'epic', 'shop'),
  ('room:arcade', 'Game Centre', 'room', 'legendary', 'claw'),
  ('room:dragon_palace', 'Dragon Palace', 'room', 'legendary', 'claw'),
  ('room:moon_base', 'Moon Base', 'room', 'legendary', 'showcase'),
  ('room:sky_shrine', 'Sky Shrine', 'room', 'legendary', 'claw'),
  ('room:tea_fields', 'Fuji Tea Fields', 'room', 'epic', 'shop'),
  ('room:sweets', 'Wagashi Land', 'room', 'epic', 'shop'),
  ('room:aurora', 'Aurora Snowfield', 'room', 'epic', 'shop'),
  ('room:beach', 'Summer Beach', 'room', 'epic', 'shop'),
  ('room:lantern_river', 'Lantern River', 'room', 'epic', 'showcase'),
  ('room:castle', 'Castle Keep', 'room', 'epic', 'shop'),
  ('outfit:onigiri', 'Onigiri', 'outfit', 'common', 'shop'),
  ('outfit:dumpling', 'Dumpling', 'outfit', 'common', 'shop'),
  ('outfit:crab', 'Crab', 'outfit', 'common', 'shop'),
  ('outfit:ladybug', 'Ladybug', 'outfit', 'common', 'shop'),
  ('outfit:snail', 'Snail', 'outfit', 'common', 'shop'),
  ('outfit:tempura_shrimp', 'Tempura Shrimp', 'outfit', 'rare', 'shop'),
  ('outfit:pufferfish', 'Pufferfish', 'outfit', 'rare', 'shop'),
  ('outfit:hermit_crab', 'Hermit Crab', 'outfit', 'rare', 'claw'),
  ('outfit:firefly', 'Firefly', 'outfit', 'rare', 'claw'),
  ('outfit:pumpkin', 'Pumpkin', 'outfit', 'rare', 'shop'),
  ('outfit:snowman', 'Snowman', 'outfit', 'rare', 'shop'),
  ('outfit:firework', 'Firework', 'outfit', 'epic', 'shop'),
  ('outfit:ramen_bowl', 'Ramen Bowl', 'outfit', 'epic', 'showcase'),
  ('outfit:narwhal', 'Narwhal', 'outfit', 'epic', 'shop'),
  ('outfit:kraken_hatchling', 'Kraken Hatchling', 'outfit', 'legendary', 'claw'),
  ('outfit:tsukumogami', 'Tsukumogami', 'outfit', 'legendary', 'claw'),
  ('box:moss', 'Moss', 'box', 'common', 'shop'),
  ('box:driftwood', 'Driftwood', 'box', 'rare', 'shop'),
  ('box:coral', 'Coral', 'box', 'epic', 'shop'),
  ('box:pumpkin_patch', 'Pumpkin Patch', 'box', 'rare', 'shop'),
  ('box:snowdrift', 'Snowdrift', 'box', 'rare', 'shop'),
  ('box:paper_lantern', 'Paper Lantern', 'box', 'epic', 'shop'),
  ('box:abyss', 'Abyss', 'box', 'legendary', 'claw'),
  ('box:starforge', 'Starforge', 'box', 'legendary', 'claw'),
  ('room:seaside_town', 'Tidepool Town', 'room', 'legendary', 'claw'),
  ('outfit:opening_day', 'Opening Day', 'outfit', 'legendary', 'event'),
  ('box:first_edition', 'First Edition', 'box', 'legendary', 'event'),
  ('room:grand_opening', 'Grand Opening', 'room', 'legendary', 'event')
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
