import { applyProviderAuth, createChatAgent, resolveJobModel } from "../../agentFactory.js";
import { logger } from "../../logger.js";
import type { JobHandlerContext } from "./types.js";
import { processEnglishGrammarAnalysisJob } from "../processEnglishGrammarAnalysisJob.js";

const ENGLISH_GRAMMAR_SYSTEM_PROMPT =
  "You are an expert English grammar analyst. Output only valid JSON per the schema.";

export async function handleEnglishGrammarAnalysisJob(ctx: JobHandlerContext): Promise<void> {
  const { config, supabase, job, resolveApiKey } = ctx;

  const baseModel = resolveJobModel(config, job.kind);
  const model = applyProviderAuth(baseModel, await resolveApiKey(baseModel.provider));
  const systemPrompt = ENGLISH_GRAMMAR_SYSTEM_PROMPT;

  const agent = createChatAgent(config, model, systemPrompt, resolveApiKey, "medium");

  try {
    await processEnglishGrammarAnalysisJob(
      supabase,
      agent,
      job,
      undefined,
      `${model.provider}/${model.id}`,
    );
  } catch (err) {
    logger.error({ err, jobId: job.id }, "english grammar analysis failed");
    throw err;
  }
}
