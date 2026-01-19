import { Agent } from "@mariozechner/pi-agent-core";
import { getEnvApiKey, type Model } from "@mariozechner/pi-ai";
import type { SupabaseClient } from "@supabase/supabase-js";

import type { CoachConfig } from "./config.js";
import { logger } from "./logger.js";
import { applyMinimaxAuth, resolveModel } from "./model.js";
import type { AiJobRow } from "./types.js";
import { buildCoachTools, type CoachToolOptions } from "./tools/coachTools.js";
import { buildModelSpec, getPublishedAiPromptConfigs, type AiPromptKind } from "./aiConfig.js";
import { createAgentLogSession } from "./agentLogs.js";
import { getProviderApiKey } from "./providerKeys.js";
import { processAttemptInsightJob } from "./jobs/processAttemptInsightJob.js";
import { processCoachReplyJob } from "./jobs/processCoachReplyJob.js";
import { processSnapshotRefreshJob } from "./jobs/processSnapshotRefreshJob.js";
import { processProgressReportJob } from "./jobs/processProgressReportJob.js";
import { scheduleRecurringJobs } from "./scheduler.js";
import { JobDeferredError } from "./jobs/jobErrors.js";

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function getStudentId(job: AiJobRow): string | null {
  if (job.student_id) return job.student_id;
  const payload = (job.payload ?? {}) as Record<string, unknown>;
  return typeof payload.student_id === "string" ? payload.student_id : null;
}

const modelCache = new Map<string, Model<any>>();

function modelForSpec(spec: string): Model<any> {
  const cached = modelCache.get(spec);
  if (cached) return cached;
  const model = resolveModel(spec, "minimax");
  modelCache.set(spec, model);
  return model;
}

function resolveJobModel(config: CoachConfig, kind: AiJobRow["kind"]): Model<any> {
  if (kind === "attempt_insight") return modelForSpec(config.modelInsight);
  if (kind === "coach_reply") return modelForSpec(config.modelChat);
  if (kind === "progress_report") return modelForSpec(config.modelReport);
  return modelForSpec(config.modelDefault);
}

const DEFAULT_SYSTEM_PROMPTS: Record<AiPromptKind, string> = {
  attempt_insight:
    "You are a strict, concise SAT tutor. Prefer short, step-by-step guidance and ask questions instead of long explanations.",
  coach_reply:
    "你是一位严格、精要的 SAT 全科老师。默认用中文，先给最小可执行下一步，再问一个澄清问题。避免长篇大论。",
  progress_report: "你是严格、精要的 SAT 一对一老师，只输出 JSON。",
};

const DEFAULT_PROMPT_VERSIONS: Record<AiPromptKind, string> = {
  attempt_insight: "ai-coach-insight-v2",
  coach_reply: "ai-coach-chat-v2",
  progress_report: "ai-coach-report-v1",
};

type PromptOverrides = {
  systemPrompt: string;
  promptVersion: string;
  modelSpec: string | null;
};

function resolvePromptOverrides(
  kind: AiJobRow["kind"],
  configs: Partial<Record<AiPromptKind, { systemPrompt: string; promptVersion: string; modelProvider: string; modelId: string }>> | null,
): PromptOverrides | null {
  if (kind !== "attempt_insight" && kind !== "coach_reply" && kind !== "progress_report") {
    return null;
  }

  const config = configs?.[kind];

  return {
    systemPrompt: config?.systemPrompt ?? DEFAULT_SYSTEM_PROMPTS[kind],
    promptVersion: config?.promptVersion ?? DEFAULT_PROMPT_VERSIONS[kind],
    modelSpec: buildModelSpec(config ?? null),
  };
}

type CoachToolOverrides = Omit<CoachToolOptions, "modelId" | "promptVersion">;

export function createCoachAgent(
  config: CoachConfig,
  supabase: SupabaseClient,
  model: Model<any>,
  systemPrompt?: string,
  promptVersion?: string,
  toolOverrides?: CoachToolOverrides,
  apiKeyResolver?: (provider: string) => Promise<string | undefined> | string | undefined,
): Agent {
  const tools = buildCoachTools(supabase, {
    modelId: model.id,
    promptVersion: promptVersion ?? DEFAULT_PROMPT_VERSIONS.attempt_insight,
    ...toolOverrides,
  });

  return new Agent({
    initialState: {
      systemPrompt: systemPrompt ?? DEFAULT_SYSTEM_PROMPTS.attempt_insight,
      model,
      thinkingLevel: "off",
      tools,
      messages: [],
    },
    getApiKey: apiKeyResolver
      ? apiKeyResolver
      : async (provider) => (provider === "minimax" ? config.minimaxApiKey : getEnvApiKey(provider)),
  });
}

export function createChatAgent(
  config: CoachConfig,
  model: Model<any>,
  systemPrompt?: string,
  apiKeyResolver?: (provider: string) => Promise<string | undefined> | string | undefined,
): Agent {
  return new Agent({
    initialState: {
      systemPrompt: systemPrompt ?? DEFAULT_SYSTEM_PROMPTS.coach_reply,
      model,
      thinkingLevel: "off",
      tools: [],
      messages: [],
    },
    getApiKey: apiKeyResolver
      ? apiKeyResolver
      : async (provider) => (provider === "minimax" ? config.minimaxApiKey : getEnvApiKey(provider)),
  });
}

async function resolveProviderKey(
  supabase: SupabaseClient,
  config: CoachConfig,
  provider: string,
): Promise<string | undefined> {
  const fromDb = await getProviderApiKey(supabase, provider);
  if (fromDb) return fromDb;
  if (provider === "minimax") return config.minimaxApiKey;
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

export async function runWorker(config: CoachConfig, supabase: SupabaseClient): Promise<void> {
  let lastScheduleAt = 0;
  const baseApiKeyResolver = async (provider: string) => resolveProviderKey(supabase, config, provider);

  for (;;) {
    const now = Date.now();
    if (config.enableScheduler && now - lastScheduleAt >= config.scheduleIntervalMs) {
      try {
        await scheduleRecurringJobs(config, supabase);
      } catch (err) {
        logger.warn({ err }, "scheduler failed");
      }
      lastScheduleAt = now;
    }

    let jobs: AiJobRow[] = [];

    try {
      jobs = await claimJobs(supabase, config.workerId, config.claimLimit, config.jobKinds);
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
        const promptConfigs = await getPublishedAiPromptConfigs(supabase);
        const overrides = resolvePromptOverrides(job.kind, promptConfigs);
        const providerKeyCache = new Map<string, string | undefined>();
        const apiKeyResolver = async (provider: string) => {
          if (providerKeyCache.has(provider)) return providerKeyCache.get(provider);
          const key = await baseApiKeyResolver(provider);
          providerKeyCache.set(provider, key);
          return key;
        };

        if (job.kind === "attempt_insight") {
          if (!job.attempt_id) throw new Error("missing attempt_id");
          const baseModel = overrides?.modelSpec
            ? modelForSpec(overrides.modelSpec)
            : resolveJobModel(config, job.kind);
          const model =
            baseModel.provider === "minimax"
              ? applyMinimaxAuth(baseModel, await apiKeyResolver(baseModel.provider))
              : baseModel;
          const systemPrompt = overrides?.systemPrompt ?? DEFAULT_SYSTEM_PROMPTS.attempt_insight;
          const promptVersion = overrides?.promptVersion ?? DEFAULT_PROMPT_VERSIONS.attempt_insight;
          const agent = createCoachAgent(
            config,
            supabase,
            model,
            systemPrompt,
            promptVersion,
            { allowWriteInsight: true, includeContextTool: true, includeMemoryTools: true },
            apiKeyResolver,
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
        } else if (job.kind === "coach_reply") {
          const baseModel = overrides?.modelSpec
            ? modelForSpec(overrides.modelSpec)
            : resolveJobModel(config, job.kind);
          const model =
            baseModel.provider === "minimax"
              ? applyMinimaxAuth(baseModel, await apiKeyResolver(baseModel.provider))
              : baseModel;
          const systemPrompt = overrides?.systemPrompt ?? DEFAULT_SYSTEM_PROMPTS.coach_reply;
          const promptVersion = overrides?.promptVersion ?? DEFAULT_PROMPT_VERSIONS.coach_reply;
          const agent = createCoachAgent(
            config,
            supabase,
            model,
            systemPrompt,
            promptVersion,
            { allowWriteInsight: false, includeContextTool: true, includeMemoryTools: true },
            apiKeyResolver,
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
        } else if (job.kind === "snapshot_refresh") {
          const studentId = getStudentId(job);
          if (!studentId) throw new Error("missing student_id");
          const payload = (job.payload ?? {}) as Record<string, unknown>;
          const periodEnd = typeof payload.period_end === "string" ? payload.period_end : null;
          await processSnapshotRefreshJob(supabase, studentId, periodEnd);
        } else if (job.kind === "progress_report") {
          const model = overrides?.modelSpec ? modelForSpec(overrides.modelSpec) : resolveJobModel(config, job.kind);
          await processProgressReportJob(
            supabase,
            config,
            model,
            (job.payload ?? {}) as Record<string, unknown>,
            overrides?.systemPrompt ?? DEFAULT_SYSTEM_PROMPTS.progress_report,
            overrides?.promptVersion ?? DEFAULT_PROMPT_VERSIONS.progress_report,
          );
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
