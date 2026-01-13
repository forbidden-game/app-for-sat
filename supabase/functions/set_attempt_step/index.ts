import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

export const config = {
  verify_jwt: false,
};

type SetAttemptStepBody = {
  attempt_id: string;
  student_selected_step_index?: number | null;
  student_selected_step_is_unknown?: boolean | null;
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

  let body: SetAttemptStepBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  if (!body.attempt_id) {
    return jsonResponse({ error: "invalid_payload" }, 400);
  }

  const isUnknown = body.student_selected_step_is_unknown === true;

  let stepIndex: number | null = null;
  if (!isUnknown) {
    const raw = body.student_selected_step_index;
    if (typeof raw !== "number" || !Number.isFinite(raw)) {
      return jsonResponse({ error: "invalid_payload" }, 400);
    }
    stepIndex = Math.trunc(raw);
    if (stepIndex < 0 || stepIndex > 20) {
      return jsonResponse({ error: "invalid_payload" }, 400);
    }
  }

  const { data: updated, error: updateError } = await supabase
    .from("attempts")
    .update({
      student_selected_step_index: isUnknown ? null : stepIndex,
      student_selected_step_is_unknown: isUnknown,
    })
    .eq("id", body.attempt_id)
    .eq("student_id", studentId)
    .select("id")
    .maybeSingle();

  if (updateError) {
    return jsonResponse({ error: "attempt_update_failed" }, 500);
  }

  if (!updated) {
    return jsonResponse({ error: "attempt_not_found" }, 404);
  }

  const now = new Date().toISOString();

  const { data: requeued, error: requeueError } = await supabase
    .from("ai_jobs")
    .update({
      status: "queued",
      run_after: now,
      updated_at: now,
      locked_at: null,
      locked_by: null,
      error: null,
    })
    .eq("attempt_id", body.attempt_id)
    .eq("kind", "attempt_insight")
    .select("id")
    .maybeSingle();

  if (requeueError) {
    console.warn("Failed to requeue ai job", requeueError.message);
  }

  if (!requeued) {
    const { error: insertJobError } = await supabase.from("ai_jobs").insert({
      kind: "attempt_insight",
      status: "queued",
      attempt_id: body.attempt_id,
      student_id: studentId,
      payload: { attempt_id: body.attempt_id },
      run_after: now,
    });

    if (insertJobError) {
      console.warn("Failed to insert ai job", insertJobError.message);
    }
  }

  return jsonResponse({ ok: true }, 200);
});
