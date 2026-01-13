import { getConfig } from "./config.js";
import { logger } from "./logger.js";
import { createSupabase } from "./supabase.js";
import { runWorker } from "./worker.js";

async function main(): Promise<void> {
  const config = getConfig();
  const supabase = createSupabase(config);

  logger.info({ workerId: config.workerId }, "ai-coach worker starting");

  await runWorker(config, supabase);
}

main().catch((err) => {
  logger.error({ err }, "fatal");
  process.exitCode = 1;
});
