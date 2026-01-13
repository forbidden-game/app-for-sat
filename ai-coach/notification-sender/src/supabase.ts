import { createClient, type SupabaseClient } from "@supabase/supabase-js";

import type { SenderConfig } from "./config.js";

export function createSupabase(config: SenderConfig): SupabaseClient {
  return createClient(config.supabaseUrl, config.supabaseServiceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}
