"use client";

import { isSupabaseConfigured } from "../lib/supabaseClient";

export function SupabaseConfigBanner() {
  if (isSupabaseConfigured()) return null;
  return (
    <div className="border-b border-amber-200 bg-amber-50 text-amber-900">
      <div className="mx-auto max-w-5xl px-6 py-3 text-sm">
        Supabase not configured. Set NEXT_PUBLIC_SUPABASE_URL and
        NEXT_PUBLIC_SUPABASE_ANON_KEY in <code>.env.local</code>, then restart
        the dev server.
      </div>
    </div>
  );
}
