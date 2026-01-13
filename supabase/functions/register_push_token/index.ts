import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

export const config = {
  verify_jwt: false,
};

type RegisterTokenBody = {
  device_token: string;
  platform?: string;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !supabaseServiceRoleKey) {
  throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.");
}

const supabase = createClient(supabaseUrl, supabaseServiceRoleKey, {
  auth: { persistSession: false },
});

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonResponse({ error: "missing_authorization" }, 401);
  }
  const token = authHeader.slice("Bearer ".length);

  const { data: authData, error: authError } = await supabase.auth.getUser(token);
  if (authError || !authData.user) {
    return jsonResponse({ error: "invalid_authorization" }, 401);
  }
  const studentId = authData.user.id;

  let body: RegisterTokenBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const deviceToken = typeof body.device_token === "string" ? body.device_token.trim() : "";
  if (!deviceToken) {
    return jsonResponse({ error: "invalid_payload" }, 400);
  }

  const platform = body.platform === "fcm" ? "fcm" : "apns";
  const now = new Date().toISOString();

  const { data: row, error: upsertError } = await supabase
    .from("push_tokens")
    .upsert(
      {
        student_id: studentId,
        device_token: deviceToken,
        platform,
        last_seen_at: now,
        updated_at: now,
      },
      { onConflict: "student_id,device_token" }
    )
    .select("id")
    .single();

  if (upsertError || !row) {
    return jsonResponse({ error: "token_upsert_failed" }, 500);
  }

  return jsonResponse({ ok: true }, 200);
});
