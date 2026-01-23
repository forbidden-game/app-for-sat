import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import {
  buildAttemptInsightDraft,
  buildCoachReplyDraft,
  type AttemptSnapshot,
} from "../_shared/ai_coach.ts";

export const config = {
  verify_jwt: false,
};

type AIJob = {
  id: string;
  kind: string;
  status: string;
  attempt_id: string | null;
  student_id: string | null;
  payload: Record<string, unknown> | null;
};

type ProcessBody = {
  worker_id?: string;
  limit?: number;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const workerSecret = Deno.env.get("AI_WORKER_SECRET");

if (!supabaseUrl || !supabaseServiceRoleKey) {
  throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.");
}

if (!workerSecret) {
  throw new Error("Missing AI_WORKER_SECRET.");
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

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function clampLimit(value: number | undefined, fallback = 3) {
  if (!value || !Number.isFinite(value)) return fallback;
  return Math.min(Math.max(Math.trunc(value), 1), 10);
}

serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonResponse({ error: "missing_authorization" }, 401);
  }
  const token = authHeader.slice("Bearer ".length);
  if (token !== workerSecret) {
    return jsonResponse({ error: "invalid_authorization" }, 401);
  }

  let body: ProcessBody = {};
  try {
    body = await req.json();
  } catch {
    body = {};
  }

  const workerId = body.worker_id ?? `worker-${crypto.randomUUID()}`;
  const limit = clampLimit(body.limit);

  const { data: jobs, error: jobError } = await supabase.rpc("claim_ai_jobs", {
    p_worker_id: workerId,
    p_limit: limit,
  });

  if (jobError) {
    return jsonResponse({ error: "claim_failed", details: jobError.message }, 500);
  }

  const processed: Array<Record<string, unknown>> = [];

  for (const job of (jobs as AIJob[]) ?? []) {
    try {
      if (job.kind === "attempt_insight") {
        await handleAttemptInsight(job);
      } else if (job.kind === "coach_reply") {
        await handleCoachReply(job);
      } else {
        throw new Error(`unsupported_kind:${job.kind}`);
      }

      await markJobDone(job.id);
      processed.push({ id: job.id, kind: job.kind, status: "done" });
    } catch (error) {
      const message = error instanceof Error ? error.message : "unknown_error";
      await markJobError(job.id, message);
      processed.push({ id: job.id, kind: job.kind, status: "error", message });
    }
  }

  return jsonResponse({ ok: true, workerId, processed }, 200);
});

async function handleAttemptInsight(job: AIJob) {
  const attemptId =
    job.attempt_id ??
    (typeof job.payload?.attempt_id === "string" ? job.payload?.attempt_id : null);
  if (!attemptId) {
    throw new Error("missing_attempt_id");
  }

  const { data: snapshot, error: snapshotError } = await supabase.rpc("get_attempt_for_coach", {
    p_attempt_id: attemptId,
  });

  if (snapshotError || !snapshot) {
    throw new Error(`attempt_snapshot_failed:${snapshotError?.message ?? "missing"}`);
  }

  const draft = buildAttemptInsightDraft(snapshot as AttemptSnapshot);
  const subject = (snapshot as AttemptSnapshot).question.subject?.trim() || "general";

  const procedure = await ensureProcedure({
    subject,
    name: draft.procedureName,
    steps: draft.procedureSteps,
    stepsVersion: draft.procedureStepsVersion,
  });

  const attempt = (snapshot as AttemptSnapshot).attempt;
  const question = (snapshot as AttemptSnapshot).question;

  const insightPayload = {
    attempt_id: attempt.id,
    student_id: attempt.student_id,
    question_id: question.id,
    procedure_id: procedure.id,
    procedure_steps_version: procedure.stepsVersion,
    error_step_index: draft.errorStepIndex,
    student_selected_step_index: attempt.student_selected_step_index,
    student_selected_step_is_unknown: attempt.student_selected_step_is_unknown,
    error_mode_enum: draft.errorModeEnum,
    error_mode_detail: draft.errorModeDetail,
    evidence: { source: "draft" },
    explanation_short: draft.explanationShort,
    followups: draft.followups,
    confidence: draft.confidence,
    model: draft.model,
    prompt_version: draft.promptVersion,
    cost_usd: draft.costUsd,
    created_at: new Date().toISOString(),
  };

  const { error: upsertError } = await supabase
    .from("attempt_insights")
    .upsert(insightPayload, { onConflict: "attempt_id" });

  if (upsertError) {
    throw new Error(`insight_upsert_failed:${upsertError.message}`);
  }

  await enqueueNotificationEvent({
    studentId: attempt.student_id,
    eventType: "attempt_insight_ready",
    payload: { attempt_id: attempt.id, question_id: question.id },
  });
}

async function handleCoachReply(job: AIJob) {
  const payload = job.payload ?? {};
  const userMessageId =
    typeof payload.user_message_id === "string" ? payload.user_message_id : null;

  if (!userMessageId) {
    throw new Error("missing_user_message_id");
  }

  const { data: userMessage, error: userMessageError } = await supabase
    .from("coach_thread_messages")
    .select("id, student_id, content, linked_attempt_id")
    .eq("id", userMessageId)
    .maybeSingle();

  if (userMessageError || !userMessage) {
    throw new Error(`user_message_missing:${userMessageError?.message ?? "unknown"}`);
  }

  const userText = typeof userMessage.content?.text === "string" ? userMessage.content.text : "";

  const draft = buildCoachReplyDraft({
    userText,
    linkedAttemptId: userMessage.linked_attempt_id,
  });

  const { data: assistantMessage, error: assistantError } = await supabase
    .from("coach_thread_messages")
    .insert({
      student_id: userMessage.student_id,
      role: "assistant",
      content: { text: "", status: "streaming" },
      linked_attempt_id: userMessage.linked_attempt_id,
    })
    .select("id")
    .single();

  if (assistantError || !assistantMessage) {
    throw new Error(`assistant_insert_failed:${assistantError?.message ?? "unknown"}`);
  }

  for (let i = 0; i < draft.chunks.length; i += 1) {
    const chunk = draft.chunks[i];
    const isLast = i === draft.chunks.length - 1;

    const content = isLast ? { text: chunk } : { text: chunk, status: "streaming" };

    const { error: updateError } = await supabase
      .from("coach_thread_messages")
      .update({ content })
      .eq("id", assistantMessage.id);

    if (updateError) {
      throw new Error(`assistant_update_failed:${updateError.message}`);
    }

    if (!isLast) {
      await sleep(250);
    }
  }

  await enqueueNotificationEvent({
    studentId: userMessage.student_id,
    eventType: "coach_reply_ready",
    payload: { message_id: assistantMessage.id },
  });
}

async function ensureProcedure(params: {
  subject: string;
  name: string;
  steps: string[];
  stepsVersion: number;
}): Promise<{ id: string; stepsVersion: number }> {
  const { data: existing, error: existingError } = await supabase
    .from("procedures")
    .select("id, steps_version")
    .eq("subject", params.subject)
    .eq("name", params.name)
    .maybeSingle();

  if (existingError) {
    throw new Error(`procedure_lookup_failed:${existingError.message}`);
  }

  if (existing) {
    return { id: existing.id, stepsVersion: existing.steps_version };
  }

  const { data: inserted, error: insertError } = await supabase
    .from("procedures")
    .insert({
      subject: params.subject,
      name: params.name,
      description: "Auto-generated placeholder procedure.",
      steps: params.steps,
      steps_version: params.stepsVersion,
      aliases: [],
      status: "active",
      created_by: "ai-worker",
    })
    .select("id, steps_version")
    .single();

  if (insertError || !inserted) {
    throw new Error(`procedure_insert_failed:${insertError?.message ?? "unknown"}`);
  }

  return { id: inserted.id, stepsVersion: inserted.steps_version };
}

async function enqueueNotificationEvent(params: {
  studentId: string;
  eventType: "attempt_insight_ready" | "coach_reply_ready";
  payload: Record<string, unknown>;
}) {
  const { error } = await supabase.from("notification_events").insert({
    student_id: params.studentId,
    event_type: params.eventType,
    payload: params.payload,
    status: "queued",
  });

  if (error) {
    console.warn("Failed to enqueue notification", error.message);
  }
}

async function markJobDone(jobId: string) {
  const now = new Date().toISOString();
  const { error } = await supabase
    .from("ai_jobs")
    .update({ status: "done", updated_at: now, error: null })
    .eq("id", jobId);

  if (error) {
    console.warn("Failed to mark job done", error.message);
  }
}

async function markJobError(jobId: string, message: string) {
  const now = new Date().toISOString();
  const { error } = await supabase
    .from("ai_jobs")
    .update({ status: "error", updated_at: now, error: message })
    .eq("id", jobId);

  if (error) {
    console.warn("Failed to mark job error", error.message);
  }
}
