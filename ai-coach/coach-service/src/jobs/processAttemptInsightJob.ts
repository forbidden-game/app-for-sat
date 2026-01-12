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

  await agent.prompt(prompt);
}
