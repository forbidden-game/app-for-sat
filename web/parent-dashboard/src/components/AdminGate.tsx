"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { getSupabaseClient } from "../lib/supabaseClient";
import { SupabaseConfigBanner } from "./SupabaseConfigBanner";

const LOADING_STATE = "loading" as const;
const READY_STATE = "ready" as const;
const DENIED_STATE = "denied" as const;

type GateState = typeof LOADING_STATE | typeof READY_STATE | typeof DENIED_STATE;

type AdminProfile = {
  role: string | null;
  display_name: string | null;
};

export function AdminGate({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const supabase = getSupabaseClient();
  const [state, setState] = useState<GateState>(LOADING_STATE);
  const [displayName, setDisplayName] = useState<string | null>(null);

  useEffect(() => {
    let active = true;

    async function verifyAdmin() {
      if (!supabase) return;

      const { data: sessionData } = await supabase.auth.getSession();
      const session = sessionData.session;
      if (!session) {
        router.push("/login");
        return;
      }

      const { data: profile, error } = await supabase
        .from("profiles")
        .select("role, display_name")
        .eq("id", session.user.id)
        .single();

      if (!active) return;

      if (!error && profile) {
        const adminProfile = profile as AdminProfile;
        setDisplayName(adminProfile.display_name ?? null);
      }

      if (error || !profile || profile.role !== "admin") {
        setState(DENIED_STATE);
        return;
      }
      setState(READY_STATE);
    }

    verifyAdmin();

    return () => {
      active = false;
    };
  }, [router, supabase]);

  if (!supabase) {
    return (
      <>
        <SupabaseConfigBanner />
        {children}
      </>
    );
  }

  if (state === LOADING_STATE) {
    return (
      <>
        <SupabaseConfigBanner />
        <main className="mx-auto max-w-5xl px-6 py-12">
          <p className="text-sm text-zinc-500">Loading admin console...</p>
        </main>
      </>
    );
  }

  if (state === DENIED_STATE) {
    return (
      <>
        <SupabaseConfigBanner />
        <main className="mx-auto max-w-5xl px-6 py-12">
          <div className="rounded-2xl border border-amber-200 bg-amber-50 p-6">
            <p className="text-sm font-semibold text-amber-900">
              Admin access required
            </p>
            <p className="mt-2 text-sm text-amber-700">
              This area is restricted to admin accounts only.
            </p>
            <div className="mt-4 flex flex-wrap gap-3">
              <Link
                className="rounded-full border border-amber-300 px-4 py-2 text-sm text-amber-900 transition hover:bg-amber-100"
                href="/dashboard"
              >
                Go to parent dashboard
              </Link>
              {displayName ? (
                <span className="text-xs text-amber-600">
                  Signed in as {displayName}
                </span>
              ) : null}
            </div>
          </div>
        </main>
      </>
    );
  }

  return (
    <>
      <SupabaseConfigBanner />
      {children}
    </>
  );
}
