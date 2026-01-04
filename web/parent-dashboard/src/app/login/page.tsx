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
    await supabase.auth.signInWithOtp({ email });
    setSent(true);
  }

  return (
    <main className="p-6 max-w-sm mx-auto">
      <SupabaseConfigBanner />
      <h1 className="text-xl font-semibold">Parent Login</h1>
      {sent ? (
        <p className="mt-4">Check your email for the login link.</p>
      ) : supabase ? (
        <form onSubmit={onSubmit} className="mt-4 space-y-3">
          <input
            className="border p-2 w-full"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="Email"
          />
          <button className="bg-black text-white px-4 py-2" type="submit">
            Send Link
          </button>
        </form>
      ) : (
        <p className="mt-4 text-sm text-zinc-600">
          Login is disabled until Supabase is configured.
        </p>
      )}
    </main>
  );
}
