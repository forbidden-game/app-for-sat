import { Agent } from "@mariozechner/pi-agent-core";
import type { Model } from "@mariozechner/pi-ai";
import type { SupabaseClient } from "@supabase/supabase-js";

import type { CoachConfig } from "./config.js";
import { logger } from "./logger.js";
import type { AiJobRow } from "./types.js";
import { buildCoachTools } from "./tools/coachTools.js";
import { processAttemptInsightJob } from "./jobs/processAttemptInsightJob.js";
import { processCoachReplyJob } from "./jobs/processCoachReplyJob.js";
import { JobDeferredError } from "./jobs/jobErrors.js";

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export function createCoachAgent(
  config: CoachConfig,
  supabase: SupabaseClient,
  model: Model<"anthropic-messages">,
): Agent {
  const tools = buildCoachTools(supabase);

  return new Agent({
    initialState: {
      systemPrompt:
        "You are a strict, concise SAT tutor. Prefer short, step-by-step guidance and ask questions instead of long explanations.",
      model,
      thinkingLevel: "off",
      tools,
      messages: [],
    },
    getApiKey: async (provider) => {
      if (provider === "minimax-anthropic") return config.minimaxApiKey;
      return undefined;
    },
  });
}

export function createChatAgent(config: CoachConfig, model: Model<"anthropic-messages">): Agent {
  return new Agent({
    initialState: {
      systemPrompt:
        "你是一位严格、精要的 SAT 全科老师。默认用中文，先给最小可执行下一步，再问一个澄清问题。避免长篇大论。",
      model,
      thinkingLevel: "off",
      tools: [],
      messages: [],
    },
    getApiKey: async (provider) => {
      if (provider === "minimax-anthropic") return config.minimaxApiKey;
      return undefined;
    },
  });
}

async function markJobDone(supabase: SupabaseClient, jobId: string): Promise<void> {
  const { error } = await supabase
    .from("ai_jobs")
    .update({ status: "done", error: null, updated_at: new Date().toISOString() })
    .eq("id", jobId);
  if (error) throw new Error(error.message);
}

async function markJobError(supabase: SupabaseClient, jobId: string, err: unknown): Promise<void> {
  const message = err instanceof Error ? err.message : String(err);
  const { error } = await supabase
    .from("ai_jobs")
    .update({ status: "error", error: message, updated_at: new Date().toISOString() })
    .eq("id", jobId);
  if (error) throw new Error(error.message);
}

async function deferJob(supabase: SupabaseClient, jobId: string, delayMs: number): Promise<void> {
  const runAfter = new Date(Date.now() + delayMs).toISOString();
  const { error } = await supabase
    .from("ai_jobs")
    .update({
      status: "queued",
      run_after: runAfter,
      error: null,
      locked_at: null,
      locked_by: null,
      updated_at: new Date().toISOString(),
    })
    .eq("id", jobId);
  if (error) throw new Error(error.message);
}

async function claimJobs(supabase: SupabaseClient, workerId: string, limit: number): Promise<AiJobRow[]> {
  const { data, error } = await supabase.rpc("claim_ai_jobs", {
    p_worker_id: workerId,
    p_limit: limit,
  });

  if (error) throw new Error(error.message);
  return (data ?? []) as AiJobRow[];
}

export async function runWorker(
  config: CoachConfig,
  supabase: SupabaseClient,
  model: Model<"anthropic-messages">,
): Promise<void> {
  for (;;) {
    let jobs: AiJobRow[] = [];

    try {
      jobs = await claimJobs(supabase, config.workerId, config.claimLimit);
    } catch (err) {
      logger.error({ err }, "failed to claim jobs");
      await sleep(config.pollIntervalMs);
      continue;
    }

    if (jobs.length === 0) {
      await sleep(config.pollIntervalMs);
      continue;
    }

    for (const job of jobs) {
      logger.info({ jobId: job.id, kind: job.kind, attemptId: job.attempt_id }, "processing ai job");

      try {
        if (job.kind === "attempt_insight") {
          if (!job.attempt_id) throw new Error("missing attempt_id");
          const agent = createCoachAgent(config, supabase, model);
          await processAttemptInsightJob(supabase, agent, job.attempt_id, job.created_at);
        } else if (job.kind === "coach_reply") {
          const agent = createChatAgent(config, model);
          await processCoachReplyJob(supabase, agent, job);
        } else {
          logger.info({ kind: job.kind }, "job kind not implemented, skipping");
        }

        await markJobDone(supabase, job.id);
      } catch (err) {
        if (err instanceof JobDeferredError) {
          logger.info({ jobId: job.id, delayMs: err.delayMs }, "job deferred");
          try {
            await deferJob(supabase, job.id, err.delayMs);
          } catch (markErr) {
            logger.error({ err: markErr, jobId: job.id }, "failed to defer job");
          }
          continue;
        }

        logger.error({ err, jobId: job.id }, "job failed");
        try {
          await markJobError(supabase, job.id, err);
        } catch (markErr) {
          logger.error({ err: markErr, jobId: job.id }, "failed to mark job error");
        }
      }
    }
  }
}
