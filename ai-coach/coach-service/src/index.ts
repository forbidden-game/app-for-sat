import { captureError, initErrorReporting } from "@ai-coach/shared";

import { getConfig } from "./config.js";
import { logger } from "./logger.js";
import { createSupabase } from "./supabase.js";
import { runWorker } from "./worker.js";

async function main(): Promise<void> {
  const config = getConfig();
  initErrorReporting({ service: "ai-coach-service" });
  const supabase = createSupabase(config);

  logger.info(
    {
      workerId: config.workerId,
      jobKinds: config.jobKinds ?? "all",
      scheduler: config.enableScheduler,
      maxConcurrency: config.maxConcurrency,
      claimLimit: config.claimLimit,
    },
    "ai-coach worker starting",
  );

  await runWorker(config, supabase);
}

main().catch((err) => {
  logger.error({ err }, "fatal");
  captureError(err, { area: "startup" });
  process.exitCode = 1;
});
