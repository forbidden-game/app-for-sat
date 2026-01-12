import * as dotenv from "dotenv";

dotenv.config();

export type CoachConfig = {
  supabaseUrl: string;
  supabaseServiceRoleKey: string;
  workerId: string;
  pollIntervalMs: number;
  claimLimit: number;
  minimaxApiKey: string;
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

export function getConfig(): CoachConfig {
  return {
    supabaseUrl: requireEnv("SUPABASE_URL"),
    supabaseServiceRoleKey: requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
    workerId: process.env["AI_COACH_WORKER_ID"] ?? "worker",
    pollIntervalMs: readInt("AI_COACH_POLL_INTERVAL_MS", 2000),
    claimLimit: readInt("AI_COACH_CLAIM_LIMIT", 2),
    minimaxApiKey: requireEnv("MINIMAX_API_KEY"),
  };
}
