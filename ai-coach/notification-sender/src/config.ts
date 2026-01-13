import * as dotenv from "dotenv";

dotenv.config();

export type SenderConfig = {
  supabaseUrl: string;
  supabaseServiceRoleKey: string;
  workerId: string;
  pollIntervalMs: number;
  claimLimit: number;
  mode: "log" | "noop";
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

export function getConfig(): SenderConfig {
  const modeRaw = process.env["NOTIFICATION_SENDER_MODE"]?.toLowerCase() ?? "log";
  const mode = modeRaw === "noop" ? "noop" : "log";

  return {
    supabaseUrl: requireEnv("SUPABASE_URL"),
    supabaseServiceRoleKey: requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
    workerId: process.env["NOTIFICATION_SENDER_WORKER_ID"] ?? "notification-worker",
    pollIntervalMs: readInt("NOTIFICATION_SENDER_POLL_INTERVAL_MS", 2000),
    claimLimit: readInt("NOTIFICATION_SENDER_CLAIM_LIMIT", 10),
    mode,
  };
}
