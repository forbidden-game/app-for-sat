import { createClient, SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../../../../supabase/database.types";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

let cachedClient: SupabaseClient<Database> | null | undefined;

export function getSupabaseClient(): SupabaseClient<Database> | null {
  if (cachedClient !== undefined) return cachedClient;
  if (!url || !key) {
    cachedClient = null;
    return cachedClient;
  }
  cachedClient = createClient<Database>(url, key);
  return cachedClient;
}

export function isSupabaseConfigured() {
  return Boolean(url && key);
}
