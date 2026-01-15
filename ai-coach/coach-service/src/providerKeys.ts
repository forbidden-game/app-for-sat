import type { SupabaseClient } from "@supabase/supabase-js";

const CACHE_TTL_MS = 60_000;

type CachedKey = {
  value: string | null;
  fetchedAt: number;
};

const cache = new Map<string, CachedKey>();

export async function getProviderApiKey(
  supabase: SupabaseClient,
  provider: string,
): Promise<string | null> {
  const cached = cache.get(provider);
  if (cached && Date.now() - cached.fetchedAt < CACHE_TTL_MS) {
    return cached.value;
  }

  const { data, error } = await supabase
    .from("ai_provider_keys")
    .select("api_key")
    .eq("provider", provider)
    .maybeSingle();

  if (error) {
    cache.set(provider, { value: null, fetchedAt: Date.now() });
    return null;
  }

  const value = (data?.api_key as string | undefined) ?? null;
  cache.set(provider, { value, fetchedAt: Date.now() });
  return value;
}
