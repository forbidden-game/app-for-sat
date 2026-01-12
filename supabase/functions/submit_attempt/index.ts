import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { scoreAttempt } from "../_shared/scoring.ts";

export const config = {
  verify_jwt: false,
};

type SubmitAttemptBody = {
  session_id: string;
  question_id: string;
  answer?: string | number | null;
  duration_ms?: number | null;
  skipped?: boolean | null;
  student_selected_step_index?: number | null;
  student_selected_step_is_unknown?: boolean | null;
};

type QuestionRow = {
  question_type: "mcq" | "numeric";
  answer_key: { correct: string | number | null };
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

function normalizeAnswer(questionType: "mcq" | "numeric", raw: unknown) {
  if (raw === undefined || raw === null) {
    return null;
  }
  if (questionType === "numeric") {
    if (typeof raw === "number" && Number.isFinite(raw)) {
      return raw;
    }
    if (typeof raw === "string") {
      const trimmed = raw.trim();
      if (trimmed.length === 0) {
        return null;
      }
      const value = Number(trimmed);
      return Number.isFinite(value) ? value : null;
    }
    return null;
  }
  if (typeof raw === "string") {
    const trimmed = raw.trim();
    return trimmed.length === 0 ? null : trimmed;
  }
  return String(raw);
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

  let body: SubmitAttemptBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  if (!body.session_id || !body.question_id) {
    return jsonResponse({ error: "invalid_payload" }, 400);
  }

  const { data: sessionRow, error: sessionError } = await supabase
    .from("sessions")
    .select("id, student_id")
    .eq("id", body.session_id)
    .single();

  if (sessionError || !sessionRow) {
    return jsonResponse({ error: "session_not_found" }, 404);
  }
  if (sessionRow.student_id !== studentId) {
    return jsonResponse({ error: "forbidden" }, 403);
  }

  const { count: sessionQuestionCount, error: sessionQuestionCountError } = await supabase
    .from("session_questions")
    .select("question_id", { count: "exact", head: true })
    .eq("session_id", body.session_id);

  if (sessionQuestionCountError) {
    return jsonResponse({ error: "session_question_check_failed" }, 500);
  }

  if ((sessionQuestionCount ?? 0) > 0) {
    const { count: matchingCount, error: matchingError } = await supabase
      .from("session_questions")
      .select("question_id", { count: "exact", head: true })
      .eq("session_id", body.session_id)
      .eq("question_id", body.question_id);
    if (matchingError) {
      return jsonResponse({ error: "session_question_check_failed" }, 500);
    }
    if ((matchingCount ?? 0) === 0) {
      return jsonResponse({ error: "question_not_in_session" }, 400);
    }
  }

  const { data: questionRow, error: questionError } = await supabase
    .from("questions")
    .select("question_type, answer_key")
    .eq("id", body.question_id)
    .single();

  if (questionError || !questionRow) {
    return jsonResponse({ error: "question_not_found" }, 404);
  }

  const typedQuestion = questionRow as QuestionRow;
  const correctValue = typedQuestion.answer_key?.correct;
  if (correctValue === null || correctValue === undefined) {
    return jsonResponse({ error: "invalid_answer_key" }, 500);
  }

  const normalizedAnswer = normalizeAnswer(typedQuestion.question_type, body.answer);
  const skipped = body.skipped === true;
  const durationMs =
    typeof body.duration_ms === "number" && Number.isFinite(body.duration_ms)
      ? Math.trunc(body.duration_ms)
      : null;

  const attemptAnswer = skipped ? null : normalizedAnswer;
  const result = skipped
    ? { isCorrect: false }
    : scoreAttempt(
      {
        questionType: typedQuestion.question_type,
        answerKey: { correct: correctValue },
      },
      { answer: attemptAnswer },
    );

  const selectedStepIsUnknown = body.student_selected_step_is_unknown === true;
  const selectedStepIndex =
    selectedStepIsUnknown || typeof body.student_selected_step_index !== "number" || !Number.isFinite(body.student_selected_step_index)
      ? null
      : Math.trunc(body.student_selected_step_index);

  const { data: insertedAttempt, error: insertError } = await supabase
    .from("attempts")
    .insert({
      session_id: body.session_id,
      question_id: body.question_id,
      student_id: studentId,
      answer: attemptAnswer,
      is_correct: skipped ? null : result.isCorrect,
      duration_ms: durationMs,
      skipped: skipped,
      student_selected_step_index: selectedStepIndex,
      student_selected_step_is_unknown: selectedStepIsUnknown,
    })
    .select("id")
    .single();

  if (insertError || !insertedAttempt) {
    return jsonResponse({ error: "attempt_insert_failed" }, 500);
  }

  if (!skipped && result.isCorrect) {
    const { count: correctCount, error: correctCountError } = await supabase
      .from("attempts")
      .select("id", { count: "exact", head: true })
      .eq("session_id", body.session_id)
      .eq("question_id", body.question_id)
      .eq("student_id", studentId)
      .eq("is_correct", true);

    if (correctCountError) {
      return jsonResponse({ error: "correct_count_failed" }, 500);
    }

    if ((correctCount ?? 0) === 1) {
      const { data: sessionCountRow, error: sessionCountError } = await supabase
        .from("sessions")
        .select("correct_count")
        .eq("id", body.session_id)
        .single();

      if (sessionCountError || !sessionCountRow) {
        return jsonResponse({ error: "session_count_failed" }, 500);
      }

      const nextCount = (sessionCountRow.correct_count ?? 0) + 1;
      const { error: updateError } = await supabase
        .from("sessions")
        .update({ correct_count: nextCount })
        .eq("id", body.session_id);

      if (updateError) {
        return jsonResponse({ error: "session_update_failed" }, 500);
      }
    }
  }

  return jsonResponse({ isCorrect: result.isCorrect, attemptId: insertedAttempt.id }, 200);
});
