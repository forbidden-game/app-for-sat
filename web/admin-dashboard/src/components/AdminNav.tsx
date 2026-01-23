"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useState } from "react";

import { getSupabaseClient } from "@/lib/supabaseClient";
import { clearAdminAccessToken } from "@/lib/adminSessionClient";

const links = [
  { href: "/admin", label: "Overview" },
  { href: "/admin/ai-config", label: "AI Config" },
  { href: "/admin/ai-logs", label: "AI Logs" },
  { href: "/admin/users", label: "Users" },
  { href: "/admin/questions", label: "Questions" },
  { href: "/admin/banks", label: "Banks" },
  { href: "/admin/tags", label: "Tags" },
  { href: "/admin/audit", label: "Audit" },
];

export function AdminNav() {
  const router = useRouter();
  const pathname = usePathname();
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

    clearAdminAccessToken();
    router.push("/login");
    router.refresh();
  }

  return (
    <nav className="sticky top-0 z-20 border-b border-[color:var(--border)] bg-[color:var(--surface)]/90 backdrop-blur-xl">
      <div className="mx-auto flex max-w-[1280px] items-center gap-6 px-6 py-3">
        <div className="flex items-center gap-3">
          <span className="text-sm font-semibold tracking-[-0.01em] text-[color:var(--ink)]">
            Backside of Meng&apos;s Dream
          </span>
          <span className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface-soft)] px-2 py-0.5 text-[10px] font-semibold uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
            Admin
          </span>
        </div>
        <div className="flex flex-1 flex-wrap items-center justify-between gap-3">
          <div className="flex flex-wrap items-center gap-2 text-xs font-medium tracking-[0.02em] text-[color:var(--ink-muted)]">
            {links.map((link) => {
              const isActive =
                link.href === "/admin" ? pathname === "/admin" : pathname.startsWith(link.href);
              return (
                <Link
                  key={link.href}
                  href={link.href}
                  aria-current={isActive ? "page" : undefined}
                  className={`rounded-full px-3 py-1 transition ${
                    isActive
                      ? "bg-[color:var(--surface-strong)] text-[color:var(--ink)]"
                      : "hover:bg-[color:var(--surface-soft)] hover:text-[color:var(--ink)]"
                  }`}
                >
                  {link.label}
                </Link>
              );
            })}
          </div>
          <div className="flex items-center gap-3">
            {errorMessage ? (
              <span className="text-xs text-[color:var(--danger-strong)]" role="alert">
                {errorMessage}
              </span>
            ) : null}
            <button
              className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-4 py-1.5 text-xs font-medium text-[color:var(--ink)] transition hover:bg-[color:var(--surface-soft)] disabled:cursor-not-allowed disabled:opacity-60"
              type="button"
              onClick={handleSignOut}
              disabled={!supabase || isSigningOut}
            >
              {isSigningOut ? "Signing Out…" : "Sign Out"}
            </button>
          </div>
        </div>
      </div>
    </nav>
  );
}
