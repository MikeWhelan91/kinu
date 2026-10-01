-- Daily missions reset at UTC midnight. Weekly challenges use the four month-aligned
-- weeks: days 1-7, 8-14, 15-21, and 22 through the end of the month.
drop function if exists public.time_gate_status(uuid);
create function public.time_gate_status(p_user_id uuid)
returns table(
  daily_key text,
  free_claw_ready boolean,
  free_claw_seconds_remaining integer,
  free_claw_remaining integer,
  daily_seconds_remaining integer,
  weekly_seconds_remaining integer
)
language plpgsql security definer set search_path = public as $$
declare current_row public.player_daily_rewards%rowtype;
declare seconds_left integer;
declare available integer;
declare utc_now timestamp := now() at time zone 'UTC';
declare next_week date;
begin
  insert into public.player_daily_rewards (user_id) values (p_user_id) on conflict (user_id) do nothing;
  select * into current_row from public.player_daily_rewards where user_id = p_user_id;
  seconds_left := case when current_row.free_claw_claimed_at is null then 0
    else greatest(0, ceil(extract(epoch from (current_row.free_claw_claimed_at + interval '24 hours' - now())))::integer) end;
  available := case when seconds_left = 0 then 2 else current_row.free_claw_remaining end;

  next_week := case
    when extract(day from utc_now) <= 7 then make_date(extract(year from utc_now)::integer, extract(month from utc_now)::integer, 8)
    when extract(day from utc_now) <= 14 then make_date(extract(year from utc_now)::integer, extract(month from utc_now)::integer, 15)
    when extract(day from utc_now) <= 21 then make_date(extract(year from utc_now)::integer, extract(month from utc_now)::integer, 22)
    else (date_trunc('month', utc_now) + interval '1 month')::date
  end;

  return query select
    to_char(utc_now, 'YYYY-MM-DD'),
    available > 0,
    seconds_left,
    available,
    greatest(0, ceil(extract(epoch from ((utc_now::date + 1)::timestamp - utc_now)))::integer),
    greatest(0, ceil(extract(epoch from (next_week::timestamp - utc_now)))::integer);
end;
$$;

revoke all on function public.time_gate_status(uuid) from public, anon, authenticated;
