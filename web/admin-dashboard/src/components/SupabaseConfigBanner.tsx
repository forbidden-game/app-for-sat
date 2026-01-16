"use client";

import { isSupabaseConfigured } from "../lib/supabaseClient";

export function SupabaseConfigBanner() {
  if (isSupabaseConfigured()) return null;
  return (
    <div className="border-b border-[color:var(--danger)] bg-[color:var(--surface)] text-[color:var(--danger-strong)]">
      <div className="mx-auto max-w-[1440px] px-6 py-3 text-sm">
        Supabase not configured. Set NEXT_PUBLIC_SUPABASE_URL and
        NEXT_PUBLIC_SUPABASE_ANON_KEY in <code>.env.local</code>. For admin
        actions, also set SUPABASE_SERVICE_ROLE_KEY, then restart the dev
        server.
      </div>
    </div>
  );
}
