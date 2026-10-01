-- My Kinu parts. Generated from scripts/kinu/kinu_parts.gd by tools/generate_parts_catalog.py.
-- Apply before shipping the client that reports part:* items: until then the stricter key check
-- rejects the whole report, so no new ownership is recorded for that player.
alter table public.player_inventory drop constraint if exists player_inventory_item_key_check;
alter table public.player_inventory add constraint player_inventory_item_key_check
  check (item_key ~ '^(outfit|part|box|room):[a-z0-9_]+$');

alter table public.inventory_catalog drop constraint if exists inventory_catalog_kind_check;
alter table public.inventory_catalog add constraint inventory_catalog_kind_check
  check (kind in ('outfit', 'part', 'box', 'room'));

insert into public.inventory_catalog (item_key, display_name, kind, rarity, source)
values
  ('part:comfy_tee', 'Comfy Tee', 'part', '', 'included'),
  ('part:sky_tee', 'Sky Tee', 'part', 'common', 'shop'),
  ('part:sailor_stripes', 'Sailor Stripes', 'part', 'common', 'shop'),
  ('part:cosy_scarf', 'Cosy Scarf', 'part', 'common', 'shop'),
  ('part:berry_bow_tie', 'Berry Bow Tie', 'part', 'common', 'shop'),
  ('part:cafe_apron', 'Café Apron', 'part', 'rare', 'shop'),
  ('part:mint_hoodie', 'Mint Hoodie', 'part', 'rare', 'shop'),
  ('part:denim_dungarees', 'Denim Dungarees', 'part', 'rare', 'shop'),
  ('part:festival_yukata', 'Festival Yukata', 'part', 'epic', 'shop'),
  ('part:ballet_tutu', 'Ballet Tutu', 'part', 'rare', 'claw'),
  ('part:swim_ring', 'Swim Ring', 'part', 'legendary', 'claw'),
  ('part:club_jersey', 'Club Jersey', 'part', '', 'goal'),
  ('part:work_overalls', 'Work Overalls', 'part', '', 'goal'),
  ('part:shoyu_bib', 'Shoyu Bib', 'part', '', 'goal'),
  ('part:knit_sweater', 'Knit Sweater', 'part', '', 'level'),
  ('part:star_cape_scarf', 'Starry Scarf', 'part', '', 'level'),
  ('part:golden_sash', 'Golden Sash', 'part', '', 'level'),
  ('part:rainy_day_coat', 'Rainy Day Coat', 'part', '', 'goal'),
  ('part:strawberry_cardigan', 'Strawberry Cardigan', 'part', '', 'goal'),
  ('part:matcha_patchwork', 'Matcha Patchwork', 'part', '', 'goal'),
  ('part:midnight_haori', 'Midnight Haori', 'part', '', 'goal'),
  ('part:cloud_pajamas', 'Cloud Pajamas', 'part', '', 'goal'),
  ('part:honey_waistcoat', 'Honey Waistcoat', 'part', '', 'goal'),
  ('part:picnic_overalls', 'Picnic Overalls', 'part', '', 'goal'),
  ('part:citrus_windbreaker', 'Citrus Windbreaker', 'part', 'common', 'shop'),
  ('part:lilac_quilt', 'Lilac Quilt', 'part', 'rare', 'shop'),
  ('part:tea_shop_vest', 'Tea Shop Vest', 'part', 'rare', 'shop'),
  ('part:aurora_raincoat', 'Aurora Raincoat', 'part', 'epic', 'shop'),
  ('part:moonlit_cape', 'Moonlit Cape', 'part', 'rare', 'claw'),
  ('part:festival_confetti', 'Festival Confetti', 'part', 'legendary', 'claw'),
  ('part:little_beanie', 'Little Beanie', 'part', '', 'included'),
  ('part:sunny_cap', 'Sunny Cap', 'part', 'common', 'shop'),
  ('part:painter_beret', 'Painter Beret', 'part', 'common', 'shop'),
  ('part:party_hat', 'Party Hat', 'part', 'common', 'shop'),
  ('part:ribbon_bow', 'Ribbon Bow', 'part', 'common', 'shop'),
  ('part:bucket_hat', 'Bucket Hat', 'part', 'rare', 'shop'),
  ('part:top_hat', 'Top Hat', 'part', 'rare', 'shop'),
  ('part:chef_hat', 'Chef''s Hat', 'part', 'rare', 'shop'),
  ('part:flower_crown', 'Flower Crown', 'part', 'epic', 'shop'),
  ('part:straw_hat', 'Straw Hat', 'part', 'epic', 'shop'),
  ('part:witch_hat', 'Witch Hat', 'part', 'rare', 'claw'),
  ('part:royal_crown', 'Royal Crown', 'part', 'legendary', 'claw'),
  ('part:halo', 'Halo', 'part', 'legendary', 'claw'),
  ('part:champion_cap', 'Champion Cap', 'part', '', 'goal'),
  ('part:clover_cap', 'Lucky Clover', 'part', '', 'goal'),
  ('part:sun_hat', 'Sun Hat', 'part', '', 'goal'),
  ('part:bunny_band', 'Bunny Headband', 'part', '', 'level'),
  ('part:cat_band', 'Cat Headband', 'part', '', 'level'),
  ('part:propeller_cap', 'Propeller Cap', 'part', '', 'level'),
  ('part:mushroom_cap', 'Mushroom Cap', 'part', '', 'goal'),
  ('part:rainbow_headphones', 'Rainbow Headphones', 'part', '', 'goal'),
  ('part:fox_ears', 'Fox Ears', 'part', '', 'goal'),
  ('part:night_market_beret', 'Night Market Beret', 'part', '', 'goal'),
  ('part:peach_blossom_crown', 'Peach Blossom Crown', 'part', '', 'goal'),
  ('part:stargazer_cap', 'Stargazer Cap', 'part', '', 'goal'),
  ('part:tofu_mushroom', 'Tofu Mushroom', 'part', 'common', 'shop'),
  ('part:mint_headphones', 'Mint Headphones', 'part', 'rare', 'shop'),
  ('part:sunset_bucket', 'Sunset Bucket', 'part', 'epic', 'shop'),
  ('part:plum_mushroom', 'Plum Mushroom', 'part', 'rare', 'claw'),
  ('part:comet_headphones', 'Comet Headphones', 'part', 'legendary', 'claw'),
  ('part:little_arms', 'Little Arms', 'part', '', 'included'),
  ('part:cosy_mittens', 'Cosy Mittens', 'part', 'common', 'shop'),
  ('part:cartoon_gloves', 'Cartoon Gloves', 'part', 'common', 'shop'),
  ('part:hello_wave', 'Hello Wave', 'part', 'common', 'shop'),
  ('part:red_balloon', 'Red Balloon', 'part', 'common', 'shop'),
  ('part:boxing_gloves', 'Boxing Gloves', 'part', 'rare', 'shop'),
  ('part:cheer_pompoms', 'Cheer Pom-poms', 'part', 'rare', 'shop'),
  ('part:little_wings', 'Little Wings', 'part', 'epic', 'shop'),
  ('part:bubble_wand', 'Bubble Wand', 'part', 'rare', 'claw'),
  ('part:sparklers', 'Sparklers', 'part', 'legendary', 'claw'),
  ('part:steady_mitts', 'Steady Mitts', 'part', '', 'goal'),
  ('part:climber_gloves', 'Climber Gloves', 'part', '', 'goal'),
  ('part:victory_flag', 'Victory Flag', 'part', '', 'level'),
  ('part:golden_wings', 'Golden Wings', 'part', '', 'level'),
  ('part:paper_lantern', 'Paper Lantern', 'part', '', 'goal'),
  ('part:peach_lollipop', 'Peach Lollipop', 'part', '', 'goal'),
  ('part:parade_maracas', 'Parade Maracas', 'part', '', 'goal'),
  ('part:baker_mitts', 'Baker Mitts', 'part', '', 'goal'),
  ('part:rainbow_flags', 'Rainbow Flags', 'part', '', 'goal'),
  ('part:plum_wings', 'Plum Wings', 'part', '', 'goal'),
  ('part:mint_pompoms', 'Mint Pom-poms', 'part', 'common', 'shop'),
  ('part:sky_balloon', 'Sky Balloon', 'part', 'common', 'shop'),
  ('part:lemon_lollipop', 'Lemon Lollipop', 'part', 'common', 'shop'),
  ('part:lucky_lantern', 'Lucky Lantern', 'part', 'rare', 'shop'),
  ('part:cocoa_maracas', 'Cocoa Maracas', 'part', 'rare', 'shop'),
  ('part:violet_boxing', 'Violet Boxing Gloves', 'part', 'rare', 'shop'),
  ('part:sunburst_wings', 'Sunburst Wings', 'part', 'epic', 'shop'),
  ('part:moon_lantern', 'Moon Lantern', 'part', 'rare', 'claw'),
  ('part:firefly_maracas', 'Firefly Maracas', 'part', 'rare', 'claw'),
  ('part:heart_lollipop', 'Heart Lollipop', 'part', 'legendary', 'claw'),
  ('part:round_specs', 'Round Specs', 'part', '', 'included'),
  ('part:red_frames', 'Red Frames', 'part', 'common', 'shop'),
  ('part:star_glasses', 'Star Glasses', 'part', 'common', 'shop'),
  ('part:heart_glasses', 'Heart Glasses', 'part', 'common', 'shop'),
  ('part:thick_frames', 'Thick Frames', 'part', 'common', 'shop'),
  ('part:cool_shades', 'Cool Shades', 'part', 'rare', 'shop'),
  ('part:monocle', 'Monocle', 'part', 'rare', 'shop'),
  ('part:swim_goggles', 'Swim Goggles', 'part', 'epic', 'shop'),
  ('part:three_d_glasses', '3D Glasses', 'part', 'epic', 'shop'),
  ('part:cat_eye_glasses', 'Cat-eye Glasses', 'part', 'rare', 'claw'),
  ('part:taster_specs', 'Taster''s Specs', 'part', '', 'goal'),
  ('part:planner_glasses', 'Planner Glasses', 'part', '', 'goal'),
  ('part:golden_specs', 'Golden Specs', 'part', '', 'level'),
  ('part:star_shades', 'Star Shades', 'part', '', 'level'),
  ('part:pixel_specs', 'Pixel Specs', 'part', '', 'goal'),
  ('part:honey_butterfly', 'Honey Butterfly', 'part', '', 'goal'),
  ('part:festival_visor', 'Festival Visor', 'part', '', 'goal'),
  ('part:plum_cat_eyes', 'Plum Cat Eyes', 'part', '', 'goal'),
  ('part:starlight_specs', 'Starlight Specs', 'part', '', 'goal'),
  ('part:sea_glass_goggles', 'Sea Glass Goggles', 'part', '', 'goal'),
  ('part:cocoa_rounds', 'Cocoa Rounds', 'part', 'common', 'shop'),
  ('part:mint_pixel', 'Mint Pixel', 'part', 'common', 'shop'),
  ('part:rose_butterfly', 'Rose Butterfly', 'part', 'common', 'shop'),
  ('part:amber_visor', 'Amber Visor', 'part', 'rare', 'shop'),
  ('part:lilac_lenses', 'Lilac Lenses', 'part', 'rare', 'shop'),
  ('part:sky_butterfly', 'Sky Butterfly', 'part', 'rare', 'shop'),
  ('part:sunrise_visor', 'Sunrise Visor', 'part', 'epic', 'shop'),
  ('part:midnight_pixel', 'Midnight Pixel', 'part', 'rare', 'claw'),
  ('part:aurora_butterfly', 'Aurora Butterfly', 'part', 'rare', 'claw'),
  ('part:golden_visor', 'Golden Visor', 'part', 'legendary', 'claw')
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
  if p_items is null or cardinality(p_items) > 1024 or exists (
    select 1 from unnest(p_items) as owned(item_key)
    where item_key is null or item_key !~ '^(outfit|part|box|room):[a-z0-9_]+$'
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
