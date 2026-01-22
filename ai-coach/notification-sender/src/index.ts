import { createApnsProvider } from "./apns.js";
import { getConfig } from "./config.js";
import { logger } from "./logger.js";
import { createSupabase } from "./supabase.js";
import { runWorker } from "./worker.js";

async function main(): Promise<void> {
  const config = getConfig();
  const supabase = createSupabase(config);
  const apnsProvider = config.mode === "apns" ? createApnsProvider(config) : undefined;

  logger.info(
    { workerId: config.workerId, mode: config.mode, maxConcurrency: config.maxConcurrency, claimLimit: config.claimLimit },
    "notification sender starting",
  );

  await runWorker(config, supabase, apnsProvider);
}

main().catch((err) => {
  logger.error({ err }, "fatal");
  process.exitCode = 1;
});
