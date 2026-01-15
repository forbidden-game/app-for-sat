"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";

import { getSupabaseClient } from "@/lib/supabaseClient";

const links = [
  { href: "/admin", label: "Overview" },
  { href: "/admin/ai-config", label: "AI Config" },
  { href: "/admin/users", label: "Users" },
  { href: "/admin/questions", label: "Questions" },
  { href: "/admin/banks", label: "Banks" },
  { href: "/admin/tags", label: "Tags" },
  { href: "/admin/audit", label: "Audit" },
];

export function AdminNav() {
  const router = useRouter();
  const supabase = getSupabaseClient();
  const [isSigningOut, setIsSigningOut] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  async function handleSignOut() {
    setErrorMessage(null);
    if (!supabase) {
      setErrorMessage("Supabase is not configured.");
      return;
    }

    setIsSigningOut(true);
    const { error } = await supabase.auth.signOut();
    setIsSigningOut(false);

    if (error) {
      setErrorMessage(error.message);
      return;
    }

    router.push("/login");
    router.refresh();
  }

  return (
    <nav className="sticky top-0 z-20 border-b border-[color:var(--border)] bg-white/85 backdrop-blur-xl">
      <div className="mx-auto flex max-w-6xl items-center gap-6 px-6 py-4">
        <div className="flex items-baseline gap-2">
          <span className="text-sm font-semibold text-[color:var(--ink)]">SAT Prep</span>
          <span className="text-xs text-[color:var(--ink-muted)]">Admin Console</span>
        </div>
        <div className="flex flex-1 flex-wrap items-center justify-between gap-3">
          <div className="flex flex-wrap items-center gap-2 text-sm text-[color:var(--ink-muted)]">
            {links.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                className="rounded-full px-3 py-1 transition hover:bg-[color:var(--surface-soft)] hover:text-[color:var(--ink)]"
              >
                {link.label}
              </Link>
            ))}
          </div>
          <div className="flex items-center gap-3">
            {errorMessage ? (
              <span className="text-xs text-red-600">{errorMessage}</span>
            ) : null}
            <button
              className="rounded-full border border-[color:var(--border)] bg-white px-4 py-1 text-sm text-[color:var(--ink)] transition hover:bg-[color:var(--surface-soft)] disabled:cursor-not-allowed disabled:opacity-60"
              type="button"
              onClick={handleSignOut}
              disabled={!supabase || isSigningOut}
            >
              {isSigningOut ? "Signing out..." : "Sign out"}
            </button>
          </div>
        </div>
      </div>
    </nav>
  );
}
