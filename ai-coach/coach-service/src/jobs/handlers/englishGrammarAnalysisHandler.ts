import {
  applyProviderAuth,
  createChatAgent,
  modelForSpec,
  resolveJobModel,
} from "../../agentFactory.js";
import { logger } from "../../logger.js";
import { DEFAULT_SYSTEM_PROMPTS } from "../../prompts/promptOverrides.js";
import type { JobHandlerContext } from "./types.js";
import { processEnglishGrammarAnalysisJob } from "../processEnglishGrammarAnalysisJob.js";

export async function handleEnglishGrammarAnalysisJob(ctx: JobHandlerContext): Promise<void> {
  const { config, supabase, job, promptOverrides, resolveApiKey } = ctx;

  const baseModel = promptOverrides?.modelSpec
    ? modelForSpec(promptOverrides.modelSpec)
    : resolveJobModel(config, job.kind);
  const model = applyProviderAuth(baseModel, await resolveApiKey(baseModel.provider));
  const systemPrompt =
    promptOverrides?.systemPrompt ?? DEFAULT_SYSTEM_PROMPTS.english_grammar_analysis;

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
