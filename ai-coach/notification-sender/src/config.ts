import { readIntEnv, requireEnv } from "@ai-coach/shared";

export type SenderConfig = {
  supabaseUrl: string;
  supabaseServiceRoleKey: string;
  workerId: string;
  pollIntervalMs: number;
  claimLimit: number;
  maxConcurrency: number;
  mode: "log" | "noop" | "apns";
  apnsTeamId?: string;
  apnsKeyId?: string;
  apnsPrivateKey?: string;
  apnsBundleId?: string;
  apnsEnv?: "production" | "development";
};

export function getConfig(): SenderConfig {
  const modeRaw = process.env["NOTIFICATION_SENDER_MODE"]?.toLowerCase() ?? "log";
  const mode = modeRaw === "apns" ? "apns" : modeRaw === "noop" ? "noop" : "log";

  const claimLimit = Math.max(1, readIntEnv("NOTIFICATION_SENDER_CLAIM_LIMIT", 10));
  const maxConcurrency = Math.max(
    1,
    readIntEnv("NOTIFICATION_SENDER_MAX_CONCURRENCY", Math.max(1, claimLimit)),
  );

  const config: SenderConfig = {
    supabaseUrl: requireEnv("SUPABASE_URL"),
    supabaseServiceRoleKey: requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
    workerId: process.env["NOTIFICATION_SENDER_WORKER_ID"] ?? "notification-worker",
    pollIntervalMs: readIntEnv("NOTIFICATION_SENDER_POLL_INTERVAL_MS", 2000),
    claimLimit,
    maxConcurrency,
    mode,
  };

  if (mode === "apns") {
    config.apnsTeamId = requireEnv("APNS_TEAM_ID");
    config.apnsKeyId = requireEnv("APNS_KEY_ID");
    config.apnsPrivateKey = requireEnv("APNS_PRIVATE_KEY");
    config.apnsBundleId = requireEnv("APNS_BUNDLE_ID");
    config.apnsEnv = process.env["APNS_ENV"]?.toLowerCase() === "production"
      ? "production"
      : "development";
  }

  return config;
}
