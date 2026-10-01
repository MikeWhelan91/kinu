-- Two non-bankable free claw tickets refill 24 hours after the first ticket in a cycle is used.
alter table public.player_daily_rewards
  add column if not exists free_claw_remaining integer not null default 2;

-- Existing players who used the old single free play keep one new free ticket this cycle.
update public.player_daily_rewards
set free_claw_remaining = case
  when free_claw_claimed_at is not null and free_claw_claimed_at > now() - interval '24 hours' then 1
  else 2
end;

alter table public.player_daily_rewards
  add constraint free_claw_remaining_range check (free_claw_remaining between 0 and 2);

drop function if exists public.time_gate_status(uuid);
create function public.time_gate_status(p_user_id uuid)
returns table(daily_key text, free_claw_ready boolean, free_claw_seconds_remaining integer, free_claw_remaining integer)
language plpgsql security definer set search_path = public as $$
declare current_row public.player_daily_rewards%rowtype;
declare seconds_left integer;
declare available integer;
begin
  insert into public.player_daily_rewards (user_id) values (p_user_id) on conflict (user_id) do nothing;
  select * into current_row from public.player_daily_rewards where user_id = p_user_id;
  seconds_left := case when current_row.free_claw_claimed_at is null then 0
    else greatest(0, ceil(extract(epoch from (current_row.free_claw_claimed_at + interval '24 hours' - now())))::integer) end;
  available := case when seconds_left = 0 then 2 else current_row.free_claw_remaining end;
  return query select to_char(now() at time zone 'UTC', 'YYYY-MM-DD'), available > 0, seconds_left, available;
end;
$$;

drop function if exists public.claim_free_claw(uuid);
create function public.claim_free_claw(p_user_id uuid)
returns table(claimed boolean, daily_key text, free_claw_ready boolean, free_claw_seconds_remaining integer, free_claw_remaining integer)
language plpgsql security definer set search_path = public as $$
declare current_row public.player_daily_rewards%rowtype;
declare seconds_left integer;
declare available integer;
declare granted boolean;
begin
  insert into public.player_daily_rewards (user_id) values (p_user_id) on conflict (user_id) do nothing;
  select * into current_row from public.player_daily_rewards where user_id = p_user_id for update;
  seconds_left := case when current_row.free_claw_claimed_at is null then 0
    else greatest(0, ceil(extract(epoch from (current_row.free_claw_claimed_at + interval '24 hours' - now())))::integer) end;
  available := case when seconds_left = 0 then 2 else current_row.free_claw_remaining end;
  granted := available > 0;
  if granted then
    available := available - 1;
    if seconds_left = 0 then
      current_row.free_claw_claimed_at := now();
      seconds_left := 86400;
    end if;
    update public.player_daily_rewards
      set free_claw_claimed_at = current_row.free_claw_claimed_at,
          free_claw_remaining = available, updated_at = now()
      where user_id = p_user_id;
  end if;
  return query select granted, to_char(now() at time zone 'UTC', 'YYYY-MM-DD'), available > 0, seconds_left, available;
end;
$$;

revoke all on function public.time_gate_status(uuid) from public;
revoke all on function public.claim_free_claw(uuid) from public;
