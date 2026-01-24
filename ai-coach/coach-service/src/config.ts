import type { AiJobKind } from "./types.js";
import { parseModelSpec } from "./model.js";
import { readBoolEnv, readCsvEnv, readIntEnv, readStringEnv, requireEnv } from "@ai-coach/shared";

export type CoachConfig = {
  supabaseUrl: string;
  supabaseServiceRoleKey: string;
  workerId: string;
  pollIntervalMs: number;
  claimLimit: number;
  maxConcurrency: number;
  minimaxApiKey: string | null;
  scheduleIntervalMs: number;
  activeLookbackDays: number;
  reportWeeklyDays: number;
  reportMonthlyDays: number;
  modelDefault: string;
  modelInsight: string;
  modelChat: string;
  modelReport: string;
  jobKinds: AiJobKind[] | null;
  enableScheduler: boolean;
};

const allowedJobKinds: AiJobKind[] = [
  "attempt_insight",
  "thread_summary",
  "procedure_merge",
  "coach_reply",
  "snapshot_refresh",
  "progress_report",
];

const llmJobKinds = new Set<AiJobKind>([
  "attempt_insight",
  "thread_summary",
  "procedure_merge",
  "coach_reply",
  "progress_report",
]);

function parseJobKinds(): AiJobKind[] | null {
  const parts = readCsvEnv("AI_COACH_JOB_KINDS");
  if (!parts) return null;

  const invalid = parts.filter((value: string) => !allowedJobKinds.includes(value as AiJobKind));
  if (invalid.length > 0) {
    throw new Error(`Invalid AI_COACH_JOB_KINDS entries: ${invalid.join(", ")}`);
  }

  return Array.from(new Set(parts)) as AiJobKind[];
}

function shouldRequireMinimaxKey(
  jobKinds: AiJobKind[] | null,
  models: Record<string, string>,
): boolean {
  const enabledKinds = jobKinds ?? allowedJobKinds;
  return enabledKinds.some((kind) => {
    if (!llmJobKinds.has(kind)) return false;
    const spec = models[kind] ?? models.default;
    return parseModelSpec(spec).provider === "minimax";
  });
}

export function getConfig(): CoachConfig {
  const defaultModel = readStringEnv("AI_COACH_MODEL_DEFAULT", "minimax/MiniMax-M2.1");
  const jobKinds = parseJobKinds();

  const claimLimit = Math.max(1, readIntEnv("AI_COACH_CLAIM_LIMIT", 2));
  const maxConcurrency = Math.max(
    1,
    readIntEnv("AI_COACH_MAX_CONCURRENCY", Math.max(1, claimLimit)),
  );

  const modelInsight = readStringEnv("AI_COACH_MODEL_INSIGHT", defaultModel);
  const modelChat = readStringEnv("AI_COACH_MODEL_CHAT", defaultModel);
  const modelReport = readStringEnv("AI_COACH_MODEL_REPORT", defaultModel);

  const models = {
    default: defaultModel,
    attempt_insight: modelInsight,
    coach_reply: modelChat,
    progress_report: modelReport,
    thread_summary: defaultModel,
    procedure_merge: defaultModel,
  };

  const requireMinimax = shouldRequireMinimaxKey(jobKinds, models);
  const minimaxApiKey = requireMinimax
    ? requireEnv("MINIMAX_API_KEY")
    : (process.env["MINIMAX_API_KEY"]?.trim() ?? null);

  return {
    supabaseUrl: requireEnv("SUPABASE_URL"),
    supabaseServiceRoleKey: requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
    workerId: process.env["AI_COACH_WORKER_ID"] ?? "worker",
    pollIntervalMs: readIntEnv("AI_COACH_POLL_INTERVAL_MS", 2000),
    claimLimit,
    maxConcurrency,
    minimaxApiKey,
    scheduleIntervalMs: readIntEnv("AI_COACH_SCHEDULE_INTERVAL_MS", 6 * 60 * 60 * 1000),
    activeLookbackDays: readIntEnv("AI_COACH_ACTIVE_LOOKBACK_DAYS", 90),
    reportWeeklyDays: readIntEnv("AI_COACH_REPORT_WEEKLY_DAYS", 7),
    reportMonthlyDays: readIntEnv("AI_COACH_REPORT_MONTHLY_DAYS", 30),
    modelDefault: defaultModel,
    modelInsight,
    modelChat,
    modelReport,
    jobKinds,
    enableScheduler: readBoolEnv("AI_COACH_ENABLE_SCHEDULER", true),
  };
}
