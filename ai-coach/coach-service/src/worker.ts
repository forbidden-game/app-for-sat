import { getEnvApiKey } from "@mariozechner/pi-ai";
import type { SupabaseClient } from "@supabase/supabase-js";
import { sleep } from "@ai-coach/shared";

import type { CoachConfig } from "./config.js";
import { getPublishedAiPromptConfigs } from "./aiConfig.js";
import { logger } from "./logger.js";
import { jobHandlers } from "./jobs/handlers/index.js";
import { JobDeferredError } from "./jobs/jobErrors.js";
import { resolvePromptOverrides } from "./prompts/promptOverrides.js";
import { getProviderApiKey } from "./providerKeys.js";
import { scheduleRecurringJobs } from "./scheduler.js";
import type { AiJobRow } from "./types.js";

async function resolveProviderKey(
  supabase: SupabaseClient,
  config: CoachConfig,
  provider: string,
): Promise<string | undefined> {
  const fromDb = await getProviderApiKey(supabase, provider);
  if (fromDb) return fromDb;

  if (provider === "minimax") {
    const key = config.minimaxApiKey ?? getEnvApiKey(provider);
    if (!key) throw new Error("missing_minimax_api_key");
    return key;
  }

  return getEnvApiKey(provider);
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

async function claimJobs(
  supabase: SupabaseClient,
  workerId: string,
  limit: number,
  jobKinds: AiJobRow["kind"][] | null,
): Promise<AiJobRow[]> {
  const params: Record<string, unknown> = {
    p_worker_id: workerId,
    p_limit: limit,
  };
  if (jobKinds && jobKinds.length > 0) {
    params.p_kinds = jobKinds;
  }

  const { data, error } = await supabase.rpc("claim_ai_jobs", params);

  if (error) throw new Error(error.message);
  return (data ?? []) as AiJobRow[];
}

async function runJob(
  config: CoachConfig,
  supabase: SupabaseClient,
  job: AiJobRow,
): Promise<void> {
  const promptConfigs = await getPublishedAiPromptConfigs(supabase);
  const promptOverrides = resolvePromptOverrides(job.kind, promptConfigs);
  const providerKeyCache = new Map<string, string | undefined>();
  const resolveApiKey = async (provider: string) => {
    if (providerKeyCache.has(provider)) return providerKeyCache.get(provider);
    const key = await resolveProviderKey(supabase, config, provider);
    providerKeyCache.set(provider, key);
    return key;
  };

  const handler = jobHandlers[job.kind];
  if (!handler) {
    logger.info({ kind: job.kind }, "job kind not implemented, skipping");
    return;
  }

  await handler({ config, supabase, job, promptOverrides, resolveApiKey });
}

async function processJob(
  config: CoachConfig,
  supabase: SupabaseClient,
  job: AiJobRow,
): Promise<void> {
  logger.info({ jobId: job.id, kind: job.kind, attemptId: job.attempt_id }, "processing ai job");

  try {
    await runJob(config, supabase, job);
    await markJobDone(supabase, job.id);
  } catch (err) {
    if (err instanceof JobDeferredError) {
      logger.info({ jobId: job.id, delayMs: err.delayMs }, "job deferred");
      try {
        await deferJob(supabase, job.id, err.delayMs);
      } catch (markErr) {
        logger.error({ err: markErr, jobId: job.id }, "failed to defer job");
      }
      return;
    }

    logger.error({ err, jobId: job.id }, "job failed");
    try {
      await markJobError(supabase, job.id, err);
    } catch (markErr) {
      logger.error({ err: markErr, jobId: job.id }, "failed to mark job error");
    }
  }
}

export async function runWorker(config: CoachConfig, supabase: SupabaseClient): Promise<void> {
  let lastScheduleAt = 0;
  let shuttingDown = false;
  const inFlight = new Set<Promise<void>>();

  const requestShutdown = (signal: string) => {
    if (shuttingDown) return;
    shuttingDown = true;
    logger.info({ signal }, "shutdown requested");
  };

  process.on("SIGTERM", () => requestShutdown("SIGTERM"));
  process.on("SIGINT", () => requestShutdown("SIGINT"));

  while (!shuttingDown) {
    const now = Date.now();
    if (config.enableScheduler && now - lastScheduleAt >= config.scheduleIntervalMs) {
      try {
        await scheduleRecurringJobs(config, supabase);
      } catch (err) {
        logger.warn({ err }, "scheduler failed");
      }
      lastScheduleAt = now;
    }

    if (inFlight.size >= config.maxConcurrency) {
      await Promise.race(inFlight);
      continue;
    }

    const capacity = Math.max(1, config.maxConcurrency - inFlight.size);
    let jobs: AiJobRow[] = [];

    try {
      jobs = await claimJobs(
        supabase,
        config.workerId,
        Math.min(config.claimLimit, capacity),
        config.jobKinds,
      );
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
      const task = processJob(config, supabase, job).finally(() => {
        inFlight.delete(task);
      });
      inFlight.add(task);
    }
  }

  if (inFlight.size > 0) {
    logger.info({ pending: inFlight.size }, "draining in-flight jobs");
    await Promise.allSettled(inFlight);
  }
}
