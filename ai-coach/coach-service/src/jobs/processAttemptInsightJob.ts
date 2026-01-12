import type { Agent } from "@mariozechner/pi-agent-core";
import type { SupabaseClient } from "@supabase/supabase-js";

import { buildAttemptInsightPrompt } from "../prompts/attemptInsightPrompt.js";
import { logger } from "../logger.js";

type AttemptForCoach = {
  attempt: {
    id: string;
    student_id: string;
    question_id: string;
    is_correct: boolean | null;
    answer: unknown;
    duration_ms: number | null;
    skipped: boolean;
    student_selected_step_index: number | null;
    student_selected_step_is_unknown: boolean;
    created_at: string;
  };
  question: {
    subject: string;
    stem: string;
    options: { label: string; content: string }[];
    answer_key: unknown;
    module: string;
    difficulty: number;
    question_type: string;
    tags: { id: string; name: string; category: string }[];
  };
};

export async function processAttemptInsightJob(
  supabase: SupabaseClient,
  agent: Agent,
  attemptId: string,
): Promise<void> {
  const { data, error } = await supabase.rpc("get_attempt_for_coach", { p_attempt_id: attemptId });
  if (error) throw new Error(error.message);

  const payload = data as AttemptForCoach;
  if (!payload?.attempt?.id) throw new Error("invalid get_attempt_for_coach response");

  if (payload.attempt.is_correct !== false) {
    logger.info({ attemptId, isCorrect: payload.attempt.is_correct }, "skip attempt insight job (not wrong)");
    return;
  }

  const prompt = buildAttemptInsightPrompt(payload);

  await agent.prompt(prompt);
}
