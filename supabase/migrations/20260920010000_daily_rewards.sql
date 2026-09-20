-- Daily rewards are recorded only by the server-side function. Do not create any client-side
-- RLS policies for this table: the Godot app must never be able to update it directly.
create table if not exists public.player_daily_rewards (
  user_id uuid primary key references auth.users(id) on delete cascade,
  last_claim_at timestamptz,
  streak integer not null default 0 check (streak between 0 and 7),
  updated_at timestamptz not null default now()
);

alter table public.player_daily_rewards add column if not exists free_claw_claimed_at timestamptz;

alter table public.player_daily_rewards enable row level security;

create or replace function public.daily_reward_status(p_user_id uuid)
returns table(ready boolean, streak integer, seconds_remaining integer, reward_index integer)
language plpgsql security definer set search_path = public as $$
declare current_row public.player_daily_rewards%rowtype;
declare elapsed interval;
declare shown_streak integer;
begin
  insert into public.player_daily_rewards (user_id) values (p_user_id) on conflict (user_id) do nothing;
  select * into current_row from public.player_daily_rewards where user_id = p_user_id;
  if current_row.last_claim_at is null then
    return query select true, 0, 0, 0;
    return;
  end if;
  elapsed := now() - current_row.last_claim_at;
  shown_streak := case when elapsed > interval '48 hours' then 0 else current_row.streak end;
  if elapsed >= interval '24 hours' then
    return query select true, shown_streak, 0, shown_streak % 7;
  else
    return query select false, shown_streak, greatest(0, ceil(extract(epoch from (interval '24 hours' - elapsed)))::integer), shown_streak % 7;
  end if;
end;
$$;

create or replace function public.claim_daily_reward(p_user_id uuid)
returns table(claimed boolean, ready boolean, streak integer, seconds_remaining integer, reward_index integer)
language plpgsql security definer set search_path = public as $$
declare current_row public.player_daily_rewards%rowtype;
declare elapsed interval;
declare next_streak integer;
begin
  insert into public.player_daily_rewards (user_id) values (p_user_id) on conflict (user_id) do nothing;
  select * into current_row from public.player_daily_rewards where user_id = p_user_id for update;
  if current_row.last_claim_at is not null then
    elapsed := now() - current_row.last_claim_at;
    if elapsed < interval '24 hours' then
      return query select false, false, current_row.streak, greatest(0, ceil(extract(epoch from (interval '24 hours' - elapsed)))::integer), current_row.streak % 7;
      return;
    end if;
  end if;
  next_streak := case when current_row.last_claim_at is null or elapsed > interval '48 hours' then 1 else (current_row.streak % 7) + 1 end;
  update public.player_daily_rewards set last_claim_at = now(), streak = next_streak, updated_at = now() where user_id = p_user_id;
  return query select true, false, next_streak, 86400, next_streak - 1;
end;
$$;

revoke all on public.player_daily_rewards from anon, authenticated;
revoke all on function public.daily_reward_status(uuid) from public;
revoke all on function public.claim_daily_reward(uuid) from public;
