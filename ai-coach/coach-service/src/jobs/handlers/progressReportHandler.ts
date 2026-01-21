import { modelForSpec, resolveJobModel } from "../../agentFactory.js";
import { DEFAULT_PROMPT_VERSIONS, DEFAULT_SYSTEM_PROMPTS } from "../../prompts/promptOverrides.js";
import type { JobHandlerContext } from "./types.js";
import { processProgressReportJob } from "../processProgressReportJob.js";

export async function handleProgressReportJob(ctx: JobHandlerContext): Promise<void> {
  const { supabase, config, job, promptOverrides } = ctx;

  const model = promptOverrides?.modelSpec
    ? modelForSpec(promptOverrides.modelSpec)
    : resolveJobModel(config, job.kind);

  await processProgressReportJob(
    supabase,
    config,
    model,
    (job.payload ?? {}) as Record<string, unknown>,
    promptOverrides?.systemPrompt ?? DEFAULT_SYSTEM_PROMPTS.progress_report,
    promptOverrides?.promptVersion ?? DEFAULT_PROMPT_VERSIONS.progress_report,
    ctx.resolveApiKey,
  );
}
