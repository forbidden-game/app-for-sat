import { createSupabaseClient } from "@ai-coach/shared";

import type { CoachConfig } from "./config.js";

export function createSupabase(config: CoachConfig) {
  return createSupabaseClient(config);
}
