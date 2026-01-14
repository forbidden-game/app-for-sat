import * as dotenv from "dotenv";
import type { AiJobKind } from "./types.js";

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
  jobKinds: AiJobKind[] | null;
  enableScheduler: boolean;
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

function readBool(name: string, fallback: boolean): boolean {
  const raw = process.env[name];
  if (!raw) return fallback;
  const normalized = raw.trim().toLowerCase();
  if (["1", "true", "yes", "y"].includes(normalized)) return true;
  if (["0", "false", "no", "n"].includes(normalized)) return false;
  throw new Error(`Invalid bool env var: ${name}=${raw}`);
}

const allowedJobKinds: AiJobKind[] = [
  "attempt_insight",
  "thread_summary",
  "procedure_merge",
  "coach_reply",
  "snapshot_refresh",
  "progress_report",
];

function parseJobKinds(): AiJobKind[] | null {
  const raw = process.env["AI_COACH_JOB_KINDS"];
  if (!raw) return null;
  const parts = raw
    .split(",")
    .map((value) => value.trim())
    .filter((value) => value.length > 0);
  if (parts.length === 0) return null;

  const invalid = parts.filter((value) => !allowedJobKinds.includes(value as AiJobKind));
  if (invalid.length > 0) {
    throw new Error(`Invalid AI_COACH_JOB_KINDS entries: ${invalid.join(", ")}`);
  }

  return Array.from(new Set(parts)) as AiJobKind[];
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
    jobKinds: parseJobKinds(),
    enableScheduler: readBool("AI_COACH_ENABLE_SCHEDULER", true),
  };
}
