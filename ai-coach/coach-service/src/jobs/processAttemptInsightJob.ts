import type { Agent } from "@mariozechner/pi-agent-core";
import type { SupabaseClient } from "@supabase/supabase-js";

import { buildCoachContext } from "../context/coachContext.js";
import { buildAttemptInsightPrompt } from "../prompts/attemptInsightPrompt.js";
import { logger } from "../logger.js";
import { JobDeferredError } from "./jobErrors.js";
import type { AiJobRow } from "../types.js";

export type AttemptInsightJob = Pick<AiJobRow, "id" | "attempt_id" | "created_at" | "student_id" | "kind">;

export type AttemptInsightLogSink = {
  recordPrompt?: (prompt: string) => void;
};

export async function processAttemptInsightJob(
  supabase: SupabaseClient,
  agent: Agent,
  job: AttemptInsightJob,
  log?: AttemptInsightLogSink,
): Promise<void> {
  if (!job.attempt_id) throw new Error("missing attempt_id");
  const attemptId = job.attempt_id;
  const jobCreatedAtIso = job.created_at;
  const context = await buildCoachContext({
    supabase,
    attemptId,
    includeMessages: false,
    includeReports: true,
    includeInsights: true,
    includeSnapshot: true,
    requireAttempt: true,
  });

  if (!context.attempt?.id) throw new Error("invalid attempt context");

  if (context.attempt.is_correct !== false) {
    logger.info({ attemptId, isCorrect: context.attempt.is_correct }, "skip attempt insight job (not wrong)");
    return;
  }

  const stepMissing =
    context.attempt.student_selected_step_is_unknown !== true &&
    context.attempt.student_selected_step_index === null;

  if (stepMissing) {
    const createdAt = Date.parse(jobCreatedAtIso);
    const ageMs = Number.isFinite(createdAt) ? Date.now() - createdAt : 0;

    // Give the iOS client a short window to submit the required step selection.
    // After that, proceed with unknown.
    if (ageMs < 2 * 60 * 1000) {
      throw new JobDeferredError("waiting_for_step_selection", 15_000);
    }

    logger.info({ attemptId }, "step selection missing; proceeding with unknown");
  }

  const prompt = buildAttemptInsightPrompt(context);
  log?.recordPrompt?.(prompt);

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
      `attempt_id=${context.attempt.id}`,
      `student_id=${context.attempt.student_id}`,
      `question_id=${context.attempt.question_id}`,
      "Remember: explanation_short must be Chinese and <= 120 chars. followups max 2.",
    ].join("\n");

    log?.recordPrompt?.(retryPrompt);
    await agent.prompt(retryPrompt);

    if (!(await hasInsight())) {
      throw new Error("attempt_insight_not_written");
    }
  }
}
