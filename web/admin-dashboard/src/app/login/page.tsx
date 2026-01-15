"use client";

import { useState } from "react";
import { SupabaseConfigBanner } from "../../components/SupabaseConfigBanner";
import { getSupabaseClient } from "../../lib/supabaseClient";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);
  const supabase = getSupabaseClient();

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!supabase) return;
    const redirectTo = `${window.location.origin}/admin`;
    await supabase.auth.signInWithOtp({
      email,
      options: { emailRedirectTo: redirectTo },
    });
    setSent(true);
  }

  return (
    <div className="min-h-screen bg-zinc-50">
      <SupabaseConfigBanner />
      <main className="mx-auto flex max-w-md flex-col px-6 py-16">
        <div className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
          <h1 className="text-xl font-semibold text-zinc-900">Admin Login</h1>
          <p className="mt-2 text-sm text-zinc-500">
            Receive a magic link to access the admin console.
          </p>
          {sent ? (
            <p className="mt-4 text-sm text-zinc-700">
              Check your email for the login link.
            </p>
          ) : supabase ? (
            <form onSubmit={onSubmit} className="mt-4 space-y-3">
              <label className="text-xs uppercase tracking-[0.16em] text-zinc-400" htmlFor="admin-email">
                Email
              </label>
              <input
                id="admin-email"
                name="email"
                type="email"
                autoComplete="email"
                className="w-full rounded-lg border border-zinc-200 px-3 py-2 text-sm"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="Email"
                required
              />
              <button
                className="w-full rounded-lg bg-zinc-900 px-4 py-2 text-sm font-semibold text-white"
                type="submit"
              >
                Send Link
              </button>
            </form>
          ) : (
            <p className="mt-4 text-sm text-zinc-600">
              Login is disabled until Supabase is configured.
            </p>
          )}
        </div>
      </main>
    </div>
  );
}
