import { readIntEnv, requireEnv } from "@ai-coach/shared";

export type SenderConfig = {
  supabaseUrl: string;
  supabaseServiceRoleKey: string;
  workerId: string;
  pollIntervalMs: number;
  claimLimit: number;
  mode: "log" | "noop";
};

export function getConfig(): SenderConfig {
  const modeRaw = process.env["NOTIFICATION_SENDER_MODE"]?.toLowerCase() ?? "log";
  const mode = modeRaw === "noop" ? "noop" : "log";

  return {
    supabaseUrl: requireEnv("SUPABASE_URL"),
    supabaseServiceRoleKey: requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
    workerId: process.env["NOTIFICATION_SENDER_WORKER_ID"] ?? "notification-worker",
    pollIntervalMs: readIntEnv("NOTIFICATION_SENDER_POLL_INTERVAL_MS", 2000),
    claimLimit: readIntEnv("NOTIFICATION_SENDER_CLAIM_LIMIT", 10),
    mode,
  };
}
