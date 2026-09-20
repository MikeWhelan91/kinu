-- Server UTC is the source for daily mission rotation and the free Kinu Claw play.
alter table public.player_daily_rewards add column if not exists free_claw_claimed_at timestamptz;

create or replace function public.time_gate_status(p_user_id uuid)
returns table(daily_key text, free_claw_ready boolean, free_claw_seconds_remaining integer)
language plpgsql security definer set search_path = public as $$
declare claimed_at timestamptz;
declare elapsed interval;
begin
  insert into public.player_daily_rewards (user_id) values (p_user_id) on conflict (user_id) do nothing;
  select free_claw_claimed_at into claimed_at from public.player_daily_rewards where user_id = p_user_id;
  if claimed_at is null then
    return query select to_char(now() at time zone 'UTC', 'YYYY-MM-DD'), true, 0;
    return;
  end if;
  elapsed := now() - claimed_at;
  return query select to_char(now() at time zone 'UTC', 'YYYY-MM-DD'), elapsed >= interval '24 hours', greatest(0, ceil(extract(epoch from (interval '24 hours' - elapsed)))::integer);
end;
$$;

create or replace function public.claim_free_claw(p_user_id uuid)
returns table(claimed boolean, daily_key text, free_claw_ready boolean, free_claw_seconds_remaining integer)
language plpgsql security definer set search_path = public as $$
declare current_row public.player_daily_rewards%rowtype;
declare elapsed interval;
begin
  insert into public.player_daily_rewards (user_id) values (p_user_id) on conflict (user_id) do nothing;
  select * into current_row from public.player_daily_rewards where user_id = p_user_id for update;
  if current_row.free_claw_claimed_at is not null then
    elapsed := now() - current_row.free_claw_claimed_at;
    if elapsed < interval '24 hours' then
      return query select false, to_char(now() at time zone 'UTC', 'YYYY-MM-DD'), false, greatest(0, ceil(extract(epoch from (interval '24 hours' - elapsed)))::integer);
      return;
    end if;
  end if;
  update public.player_daily_rewards set free_claw_claimed_at = now(), updated_at = now() where user_id = p_user_id;
  return query select true, to_char(now() at time zone 'UTC', 'YYYY-MM-DD'), false, 86400;
end;
$$;

revoke all on function public.time_gate_status(uuid) from public;
revoke all on function public.claim_free_claw(uuid) from public;
