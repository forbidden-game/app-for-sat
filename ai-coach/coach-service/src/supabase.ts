import { createClient, type SupabaseClient } from "@supabase/supabase-js";

import type { CoachConfig } from "./config.js";

export function createSupabase(config: CoachConfig): SupabaseClient {
  return createClient(config.supabaseUrl, config.supabaseServiceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}
