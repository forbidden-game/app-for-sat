import { readIntEnv, requireEnv } from "@ai-coach/shared";

export type SenderConfig = {
  supabaseUrl: string;
  supabaseServiceRoleKey: string;
  workerId: string;
  pollIntervalMs: number;
  claimLimit: number;
  maxConcurrency: number;
  mode: "log" | "noop";
};

export function getConfig(): SenderConfig {
  const modeRaw = process.env["NOTIFICATION_SENDER_MODE"]?.toLowerCase() ?? "log";
  const mode = modeRaw === "noop" ? "noop" : "log";

  const claimLimit = readIntEnv("NOTIFICATION_SENDER_CLAIM_LIMIT", 10);
  const maxConcurrency = readIntEnv("NOTIFICATION_SENDER_MAX_CONCURRENCY", Math.max(1, claimLimit));

  return {
    supabaseUrl: requireEnv("SUPABASE_URL"),
    supabaseServiceRoleKey: requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
    workerId: process.env["NOTIFICATION_SENDER_WORKER_ID"] ?? "notification-worker",
    pollIntervalMs: readIntEnv("NOTIFICATION_SENDER_POLL_INTERVAL_MS", 2000),
    claimLimit,
    maxConcurrency,
    mode,
  };
}
