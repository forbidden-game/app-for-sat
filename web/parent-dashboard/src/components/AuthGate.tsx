"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { getSupabaseClient } from "../lib/supabaseClient";
import { SupabaseConfigBanner } from "./SupabaseConfigBanner";

export function AuthGate({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const [ready, setReady] = useState(false);
  const supabase = getSupabaseClient();

  useEffect(() => {
    if (!supabase) return;
    supabase.auth.getSession().then(({ data }) => {
      if (!data.session) router.push("/login");
      else setReady(true);
    });
  }, [router, supabase]);

  if (!supabase) {
    return (
      <>
        <SupabaseConfigBanner />
        {children}
      </>
    );
  }
  if (!ready) return null;
  return (
    <>
      <SupabaseConfigBanner />
      {children}
    </>
  );
}
