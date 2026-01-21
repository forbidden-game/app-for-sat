import type { SupabaseClient } from "@supabase/supabase-js";

import type { CoachConfig } from "../../config.js";
import type { PromptOverrides } from "../../prompts/promptOverrides.js";
import type { AiJobRow } from "../../types.js";

export type JobHandlerContext = {
  config: CoachConfig;
  supabase: SupabaseClient;
  job: AiJobRow;
  promptOverrides: PromptOverrides | null;
  resolveApiKey: (provider: string) => Promise<string | undefined>;
};
