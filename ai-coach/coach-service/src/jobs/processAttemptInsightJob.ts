import type { Agent } from "@mariozechner/pi-agent-core";
import type { SupabaseClient } from "@supabase/supabase-js";

import type { AttemptForCoach } from "../domain/attemptForCoach.js";
import { buildAttemptInsightPrompt } from "../prompts/attemptInsightPrompt.js";
import { logger } from "../logger.js";

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

  const hasInsight = async (): Promise<boolean> => {
    const { data, error: insightError } = await supabase
      .from("attempt_insights")
      .select("attempt_id")
      .eq("attempt_id", attemptId)
      .maybeSingle();

    if (insightError) throw new Error(insightError.message);
    return !!data?.attempt_id;
  };

  await agent.prompt(prompt);

  if (!(await hasInsight())) {
    const retryPrompt = [
      "You did not persist the insight.",
      "Call write_attempt_insight now. Do not write free-form text.",
      `attempt_id=${payload.attempt.id}`,
      `student_id=${payload.attempt.student_id}`,
      `question_id=${payload.attempt.question_id}`,
      "Remember: explanation_short must be Chinese and <= 120 chars. followups max 2.",
    ].join("\n");

    await agent.prompt(retryPrompt);

    if (!(await hasInsight())) {
      throw new Error("attempt_insight_not_written");
    }
  }
}
