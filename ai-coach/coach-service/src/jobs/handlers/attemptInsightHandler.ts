import { applyProviderAuth, createCoachAgent, modelForSpec, resolveJobModel } from "../../agentFactory.js";
import { createAgentLogSession } from "../../agentLogs.js";
import { DEFAULT_PROMPT_VERSIONS, DEFAULT_SYSTEM_PROMPTS } from "../../prompts/promptOverrides.js";
import type { JobHandlerContext } from "./types.js";
import { processAttemptInsightJob } from "../processAttemptInsightJob.js";
import { JobDeferredError } from "../jobErrors.js";

export async function handleAttemptInsightJob(ctx: JobHandlerContext): Promise<void> {
  const { config, supabase, job, promptOverrides, resolveApiKey } = ctx;

  if (!job.attempt_id) throw new Error("missing attempt_id");

  const baseModel = promptOverrides?.modelSpec
    ? modelForSpec(promptOverrides.modelSpec)
    : resolveJobModel(config, job.kind);
  const model = applyProviderAuth(baseModel, await resolveApiKey(baseModel.provider));
  const systemPrompt = promptOverrides?.systemPrompt ?? DEFAULT_SYSTEM_PROMPTS.attempt_insight;
  const promptVersion = promptOverrides?.promptVersion ?? DEFAULT_PROMPT_VERSIONS.attempt_insight;

  const agent = createCoachAgent(
    config,
    supabase,
    model,
    systemPrompt,
    promptVersion,
    { allowWriteInsight: true, includeContextTool: true, includeMemoryTools: true },
    resolveApiKey,
  );

  const logSession = createAgentLogSession({
    job,
    model,
    promptVersion,
    systemPrompt,
  });

  logSession.attach(agent);
  try {
    await processAttemptInsightJob(supabase, agent, job, logSession);
    await logSession.flush(supabase, "done");
  } catch (err) {
    if (!(err instanceof JobDeferredError)) {
      await logSession.flush(supabase, "error", err);
    }
    throw err;
  } finally {
    logSession.detach();
  }
}
