import { applyProviderAuth, createChatAgent, resolveJobModel } from "../../agentFactory.js";
import { createAgentLogSession } from "../../agentLogs.js";
import { logger } from "../../logger.js";
import type { JobHandlerContext } from "./types.js";
import { processEnglishGrammarAnalysisJob, ENGLISH_GRAMMAR_PROMPT_VERSION } from "../processEnglishGrammarAnalysisJob.js";

const ENGLISH_GRAMMAR_SYSTEM_PROMPT =
  "You are an expert English grammar analyst. Output only valid JSON per the schema.";

export async function handleEnglishGrammarAnalysisJob(ctx: JobHandlerContext): Promise<void> {
  const { config, supabase, job, resolveApiKey } = ctx;

  const baseModel = resolveJobModel(config, job.kind);
  const model = applyProviderAuth(baseModel, await resolveApiKey(baseModel.provider));
  const systemPrompt = ENGLISH_GRAMMAR_SYSTEM_PROMPT;

  const agent = createChatAgent(config, model, systemPrompt, resolveApiKey);

  const logSession = createAgentLogSession({
    job,
    model,
    promptVersion: ENGLISH_GRAMMAR_PROMPT_VERSION,
    systemPrompt,
  });

  logSession.attach(agent);
  try {
    await processEnglishGrammarAnalysisJob(
      supabase,
      agent,
      job,
      logSession,
      `${model.provider}/${model.id}`,
    );
    await logSession.flush(supabase, "done");
  } catch (err) {
    logger.error({ err, jobId: job.id }, "english grammar analysis failed");
    await logSession.flush(supabase, "error", err);
    throw err;
  } finally {
    logSession.detach();
  }
}
