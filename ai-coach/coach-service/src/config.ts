import * as dotenv from "dotenv";

dotenv.config();

export type CoachConfig = {
  supabaseUrl: string;
  supabaseServiceRoleKey: string;
  workerId: string;
  pollIntervalMs: number;
  claimLimit: number;
  minimaxApiKey: string;
  scheduleIntervalMs: number;
  activeLookbackDays: number;
  reportWeeklyDays: number;
  reportMonthlyDays: number;
  modelDefault: string;
  modelInsight: string;
  modelChat: string;
  modelReport: string;
};

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing env var: ${name}`);
  return value;
}

function readInt(name: string, fallback: number): number {
  const raw = process.env[name];
  if (!raw) return fallback;
  const parsed = Number.parseInt(raw, 10);
  if (Number.isNaN(parsed)) throw new Error(`Invalid int env var: ${name}=${raw}`);
  return parsed;
}

function readString(name: string, fallback: string): string {
  const raw = process.env[name];
  if (!raw) return fallback;
  const value = raw.trim();
  return value.length > 0 ? value : fallback;
}

export function getConfig(): CoachConfig {
  const defaultModel = readString("AI_COACH_MODEL_DEFAULT", "minimax/MiniMax-M2.1");

  return {
    supabaseUrl: requireEnv("SUPABASE_URL"),
    supabaseServiceRoleKey: requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
    workerId: process.env["AI_COACH_WORKER_ID"] ?? "worker",
    pollIntervalMs: readInt("AI_COACH_POLL_INTERVAL_MS", 2000),
    claimLimit: readInt("AI_COACH_CLAIM_LIMIT", 2),
    minimaxApiKey: requireEnv("MINIMAX_API_KEY"),
    scheduleIntervalMs: readInt("AI_COACH_SCHEDULE_INTERVAL_MS", 6 * 60 * 60 * 1000),
    activeLookbackDays: readInt("AI_COACH_ACTIVE_LOOKBACK_DAYS", 90),
    reportWeeklyDays: readInt("AI_COACH_REPORT_WEEKLY_DAYS", 7),
    reportMonthlyDays: readInt("AI_COACH_REPORT_MONTHLY_DAYS", 30),
    modelDefault: defaultModel,
    modelInsight: readString("AI_COACH_MODEL_INSIGHT", defaultModel),
    modelChat: readString("AI_COACH_MODEL_CHAT", defaultModel),
    modelReport: readString("AI_COACH_MODEL_REPORT", defaultModel),
  };
}
