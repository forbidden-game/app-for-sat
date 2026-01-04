import { createClient, SupabaseClient } from "@supabase/supabase-js";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

let cachedClient: SupabaseClient | null | undefined;

export function getSupabaseClient(): SupabaseClient | null {
  if (cachedClient !== undefined) return cachedClient;
  if (!url || !key) {
    cachedClient = null;
    return cachedClient;
  }
  cachedClient = createClient(url, key);
  return cachedClient;
}

export function isSupabaseConfigured() {
  return Boolean(url && key);
}
