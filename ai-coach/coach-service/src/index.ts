import { getConfig } from "./config.js";
import { logger } from "./logger.js";
import { getMinimaxAnthropicModel } from "./model.js";
import { createSupabase } from "./supabase.js";
import { runWorker } from "./worker.js";

async function main(): Promise<void> {
  const config = getConfig();
  const supabase = createSupabase(config);
  const model = getMinimaxAnthropicModel(config.minimaxApiKey);

  logger.info({ workerId: config.workerId, provider: model.provider, model: model.id }, "ai-coach worker starting");

  await runWorker(config, supabase, model);
}

main().catch((err) => {
  logger.error({ err }, "fatal");
  process.exitCode = 1;
});
