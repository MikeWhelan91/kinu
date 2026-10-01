-- Supabase grants EXECUTE to anon and authenticated by default. Only the Edge Function's
-- service role may call these security-definer reward functions with a user ID.
revoke all on function public.daily_reward_status(uuid) from public, anon, authenticated;
revoke all on function public.claim_daily_reward(uuid) from public, anon, authenticated;
revoke all on function public.time_gate_status(uuid) from public, anon, authenticated;
revoke all on function public.claim_free_claw(uuid) from public, anon, authenticated;
