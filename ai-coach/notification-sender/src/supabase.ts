import { createSupabaseClient } from "@ai-coach/shared";

import type { SenderConfig } from "./config.js";

export function createSupabase(config: SenderConfig) {
  return createSupabaseClient(config);
}
