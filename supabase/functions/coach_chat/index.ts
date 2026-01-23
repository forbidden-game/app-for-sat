import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

export const config = {
  verify_jwt: false,
};

type CoachChatBody = {
  text: string;
  linked_attempt_id?: string | null;
  reply_to_message_id?: string | null;
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

  let body: CoachChatBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const text = typeof body.text === "string" ? body.text.trim() : "";
  if (!text) {
    return jsonResponse({ error: "invalid_payload" }, 400);
  }

  let linkedAttemptId: string | null = null;
  const linkedAttemptCandidate =
    typeof body.linked_attempt_id === "string" ? body.linked_attempt_id.trim() : "";
  if (linkedAttemptCandidate) {
    const { data: attemptRow, error: attemptError } = await supabase
      .from("attempts")
      .select("id")
      .eq("id", linkedAttemptCandidate)
      .eq("student_id", studentId)
      .maybeSingle();

    if (attemptError) {
      return jsonResponse({ error: "linked_attempt_lookup_failed" }, 500);
    }

    if (!attemptRow) {
      // Treat missing/foreign attempts as not found to avoid leaking IDs.
      return jsonResponse({ error: "linked_attempt_not_found" }, 404);
    }

    linkedAttemptId = linkedAttemptCandidate;
  }

  let replyToMessageId: string | null = null;
  const replyToMessageCandidate =
    typeof body.reply_to_message_id === "string" ? body.reply_to_message_id.trim() : "";
  if (replyToMessageCandidate) {
    const { data: replyRow, error: replyError } = await supabase
      .from("coach_thread_messages")
      .select("id")
      .eq("id", replyToMessageCandidate)
      .eq("student_id", studentId)
      .maybeSingle();

    if (replyError) {
      return jsonResponse({ error: "reply_to_message_lookup_failed" }, 500);
    }

    if (!replyRow) {
      return jsonResponse({ error: "reply_to_message_not_found" }, 404);
    }

    replyToMessageId = replyToMessageCandidate;
  }

  const { data: userMessage, error: insertError } = await supabase
    .from("coach_thread_messages")
    .insert({
      student_id: studentId,
      role: "user",
      content: { text },
      linked_attempt_id: linkedAttemptId,
      reply_to_message_id: replyToMessageId,
    })
    .select("id")
    .single();

  if (insertError || !userMessage) {
    return jsonResponse({ error: "message_insert_failed" }, 500);
  }

  const { error: jobError } = await supabase.from("ai_jobs").insert({
    kind: "coach_reply",
    status: "queued",
    student_id: studentId,
    // If the client retries after a timeout, this keeps enqueue idempotent.
    dedupe_key: userMessage.id,
    payload: {
      student_id: studentId,
      user_message_id: userMessage.id,
      linked_attempt_id: linkedAttemptId,
    },
  });

  if (jobError) {
    // Unique constraint violation for (kind, dedupe_key) -> already enqueued.
    if ((jobError as { code?: string }).code !== "23505") {
      return jsonResponse({ error: "job_insert_failed" }, 500);
    }
  }

  return jsonResponse({ ok: true, userMessageId: userMessage.id }, 200);
});
