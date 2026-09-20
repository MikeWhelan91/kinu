import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Content-Type": "application/json",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return Response.json({ error: "method_not_allowed" }, { status: 405, headers: corsHeaders });
  const token = request.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return Response.json({ error: "unauthorized" }, { status: 401, headers: corsHeaders });

  const url = Deno.env.get("SUPABASE_URL")!;
  const publishableKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const auth = createClient(url, publishableKey);
  const { data: { user }, error: userError } = await auth.auth.getUser(token);
  if (userError || !user) return Response.json({ error: "unauthorized" }, { status: 401, headers: corsHeaders });

  const body = await request.json().catch(() => ({}));
  const rpc = body.action === "claim" ? "claim_daily_reward"
    : body.action === "status" ? "daily_reward_status"
    : body.action === "time_status" ? "time_gate_status"
    : body.action === "claim_free_claw" ? "claim_free_claw" : "";
  if (!rpc) return Response.json({ error: "invalid_action" }, { status: 400, headers: corsHeaders });
  const admin = createClient(url, serviceRoleKey);
  const { data, error } = await admin.rpc(rpc, { p_user_id: user.id }).single();
  if (error) return Response.json({ error: "reward_unavailable" }, { status: 500, headers: corsHeaders });
  return Response.json(data, { headers: corsHeaders });
});
