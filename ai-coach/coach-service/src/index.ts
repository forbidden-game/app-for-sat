import { getConfig } from "./config.js";
import { logger } from "./logger.js";
import { createSupabase } from "./supabase.js";

async function main(): Promise<void> {
  const config = getConfig();
  const supabase = createSupabase(config);

  logger.info({ workerId: config.workerId }, "ai-coach worker starting");

  // TODO: implement job loop
  // Placeholder to verify env + connectivity only.
  const { data, error } = await supabase.from("profiles").select("id").limit(1);
  if (error) {
    logger.error({ err: error }, "supabase connectivity check failed");
    process.exitCode = 1;
    return;
  }

  logger.info({ sampleCount: data?.length ?? 0 }, "supabase connectivity ok");
}

main().catch((err) => {
  logger.error({ err }, "fatal");
  process.exitCode = 1;
});
