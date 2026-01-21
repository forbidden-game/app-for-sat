import "server-only";
import { createClient } from "@supabase/supabase-js";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

let cachedAdminClient: ReturnType<typeof createClient> | null | undefined;

export function getSupabaseAdminClient() {
  if (cachedAdminClient !== undefined) return cachedAdminClient;
  if (!url || !serviceRoleKey) {
    cachedAdminClient = null;
    return cachedAdminClient;
  }
  cachedAdminClient = createClient(url, serviceRoleKey, {
    auth: {
      persistSession: false,
    },
  });
  return cachedAdminClient;
}
