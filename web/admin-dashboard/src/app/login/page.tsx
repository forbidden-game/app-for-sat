"use client";

import { useState } from "react";
import { SupabaseConfigBanner } from "../../components/SupabaseConfigBanner";
import { getSupabaseClient } from "../../lib/supabaseClient";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const supabase = getSupabaseClient();

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!supabase || !email) return;
    setIsSubmitting(true);
    const redirectTo = `${window.location.origin}/admin`;
    try {
      await supabase.auth.signInWithOtp({
        email,
        options: { emailRedirectTo: redirectTo },
      });
      setSent(true);
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <div className="min-h-screen">
      <SupabaseConfigBanner />
      <main className="mx-auto flex max-w-md flex-col px-6 py-16">
        <div className="rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface)] p-6 shadow-[var(--shadow)]">
          <h1 className="text-xl font-semibold text-[color:var(--ink)]">Admin Login</h1>
          <p className="mt-2 text-sm text-[color:var(--ink-muted)]">
            Receive a magic link to access the admin console.
          </p>
          {sent ? (
            <p className="mt-4 text-sm text-[color:var(--ink)]">
              Check your email for the login link.
            </p>
          ) : supabase ? (
            <form onSubmit={onSubmit} className="mt-4 space-y-3">
              <label
                className="text-xs uppercase tracking-[0.16em] text-[color:var(--ink-muted)]"
                htmlFor="admin-email"
              >
                Email
              </label>
              <input
                id="admin-email"
                name="email"
                type="email"
                autoComplete="email"
                autoCapitalize="none"
                spellCheck={false}
                className="w-full rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="Email…"
                required
                disabled={isSubmitting}
              />
              <button
                className="w-full rounded-lg bg-[color:var(--accent)] px-4 py-2 text-sm font-semibold text-white transition hover:bg-[color:var(--accent-strong)]"
                type="submit"
                disabled={isSubmitting}
              >
                {isSubmitting ? "Sending…" : "Send Link"}
              </button>
            </form>
          ) : (
            <p className="mt-4 text-sm text-[color:var(--ink-muted)]">
              Login is disabled until Supabase is configured.
            </p>
          )}
        </div>
      </main>
    </div>
  );
}
