# Secure daily treats with Supabase

This project includes the database migrations, `daily-reward` Edge Function, and Godot client needed to make the seven-day Daily Treat calendar, daily missions, and two free Kinu Claw tickets use server time. Players remain anonymous: no email, password, or sign-in screen is shown.

## One-time dashboard setup

1. Rotate any database password that has been pasted into chat or a ticket. It is not needed by the game or function.
2. In **Authentication → Providers / Settings**, turn on **Allow anonymous sign-ins**. Anonymous users receive an authenticated session without personal information. Enable CAPTCHA before a broad public launch.
3. In **SQL Editor**, run the migrations in `supabase/migrations/` in filename order.
4. In **Edge Functions**, create/deploy `daily-reward` using `supabase/functions/daily-reward/index.ts`. The standard `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` secrets are supplied to hosted Supabase Edge Functions; never copy the service-role key into Godot or Git.
5. In **Project Settings → API Keys**, copy the project URL and **publishable** key (not a secret key). Put them in `project.godot` under `[supabase]` before making an export. Both are expected to be visible in a compiled mobile app.

## Test

Open the app, claim a Daily Treat, then move the phone clock forward a week and try again. The server should return the remaining time rather than a second reward. A network failure deliberately does not grant a reward once Supabase is configured.

The Daily Treat implementation uses a rolling 24-hour cooldown. Claiming again within 48 hours continues the seven-day streak; waiting longer resets it to Day 1. Daily missions rotate at 00:00 UTC, and weekly challenges rotate at 00:00 UTC on the 8th, 15th, 22nd, and 1st. The `time_gate_status` function returns both reset countdowns; the app advances those snapshots with a monotonic clock and requests fresh server status at the boundary. The two free claw tickets refill together 24 hours after the first is used. Unused free tickets do not accrue. The server performs a row lock during claw claims so concurrent requests cannot spend the same free ticket twice. All four reward RPCs are executable by the Edge Function's service role, not by anonymous or authenticated clients directly.

## Scope

Paid Kinu Claw plays and mission progress remain local; they are not time-gated. The server prevents a changed device clock from creating fresh daily missions or extra free Claw tickets.
