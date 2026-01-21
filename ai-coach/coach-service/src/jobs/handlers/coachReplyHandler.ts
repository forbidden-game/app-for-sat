import { applyProviderAuth, createCoachAgent, modelForSpec, resolveJobModel } from "../../agentFactory.js";
import { createAgentLogSession } from "../../agentLogs.js";
import { DEFAULT_PROMPT_VERSIONS, DEFAULT_SYSTEM_PROMPTS } from "../../prompts/promptOverrides.js";
import type { JobHandlerContext } from "./types.js";
import { processCoachReplyJob } from "../processCoachReplyJob.js";

export async function handleCoachReplyJob(ctx: JobHandlerContext): Promise<void> {
  const { config, supabase, job, promptOverrides, resolveApiKey } = ctx;

  const baseModel = promptOverrides?.modelSpec
    ? modelForSpec(promptOverrides.modelSpec)
    : resolveJobModel(config, job.kind);
  const model = applyProviderAuth(baseModel, await resolveApiKey(baseModel.provider));
  const systemPrompt = promptOverrides?.systemPrompt ?? DEFAULT_SYSTEM_PROMPTS.coach_reply;
  const promptVersion = promptOverrides?.promptVersion ?? DEFAULT_PROMPT_VERSIONS.coach_reply;

  const agent = createCoachAgent(
    config,
    supabase,
    model,
    systemPrompt,
    promptVersion,
    { allowWriteInsight: false, includeContextTool: true, includeMemoryTools: true },
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
    await processCoachReplyJob(supabase, agent, job, logSession);
    await logSession.flush(supabase, "done");
  } catch (err) {
    await logSession.flush(supabase, "error", err);
    throw err;
  } finally {
    logSession.detach();
  }
}
