"use client";

import { useEffect, useMemo, useState } from "react";
import { getSupabaseClient } from "@/lib/supabaseClient";
import { getAdminOverview, type AdminOverview } from "./actions";

function formatDateTime(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export default function AdminPage() {
  const supabase = getSupabaseClient();
  const [overview, setOverview] = useState<AdminOverview | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;

    async function loadOverview() {
      if (!supabase) {
        if (active) {
          setError("Supabase not configured.");
          setLoading(false);
        }
        return;
      }

      const { data: sessionData } = await supabase.auth.getSession();
      const session = sessionData.session;
      if (!session) {
        if (active) {
          setError("You are not signed in.");
          setLoading(false);
        }
        return;
      }

      try {
        const data = await getAdminOverview(session.access_token);
        if (active) {
          setOverview(data);
        }
      } catch (loadError) {
        if (active) {
          setError("Failed to load admin overview.");
        }
      } finally {
        if (active) {
          setLoading(false);
        }
      }
    }

    loadOverview();

    return () => {
      active = false;
    };
  }, [supabase]);

  const metrics = useMemo(() => overview?.metrics ?? [], [overview]);
  const questionBanks = useMemo(
    () => overview?.question_banks ?? [],
    [overview],
  );
  const recentUsers = useMemo(() => overview?.recent_users ?? [], [overview]);

  if (loading) {
    return (
      <main className="mx-auto max-w-6xl px-6 py-12">
        <p className="text-sm text-zinc-500">Loading admin overview...</p>
      </main>
    );
  }

  if (error) {
    return (
      <main className="mx-auto max-w-6xl px-6 py-12">
        <p className="text-sm text-red-600">{error}</p>
      </main>
    );
  }

  if (!overview) {
    return (
      <main className="mx-auto max-w-6xl px-6 py-12">
        <p className="text-sm text-zinc-500">No admin data available.</p>
      </main>
    );
  }

  return (
    <main className="mx-auto flex max-w-6xl flex-col gap-10 px-6 py-8">
      <header className="flex flex-wrap items-start justify-between gap-4">
        <div className="flex flex-col gap-1">
          <p className="text-xs uppercase tracking-[0.2em] text-zinc-400">
            Admin Console
          </p>
          <h1 className="text-2xl font-semibold text-zinc-900">
            Operations overview
          </h1>
          <p className="text-sm text-zinc-500">
            Signed in as{" "}
            <span className="font-medium text-zinc-700">
              {overview.admin.display_name ?? overview.admin.email ?? "Admin"}
            </span>
          </p>
        </div>
        <div className="text-xs text-zinc-400">
          Updated {formatDateTime(overview.generated_at)}
        </div>
      </header>

      <section className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        {metrics.map((metric) => (
          <div
            key={metric.label}
            className="rounded-2xl border border-zinc-200 bg-white p-4 shadow-sm"
          >
            <p className="text-xs uppercase tracking-[0.2em] text-zinc-400">
              {metric.label}
            </p>
            <p className="mt-2 text-2xl font-semibold text-zinc-900">
              {metric.value}
            </p>
            {metric.helper ? (
              <p className="mt-1 text-xs text-zinc-500">{metric.helper}</p>
            ) : null}
          </div>
        ))}
      </section>

      <section id="content" className="flex flex-col gap-4">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold text-zinc-900">Question banks</h2>
          <span className="text-xs text-zinc-400">Read-only (MVP)</span>
        </div>
        <div className="overflow-hidden rounded-2xl border border-zinc-200 bg-white">
          <table className="w-full text-left text-sm text-zinc-700">
            <thead className="bg-zinc-50 text-xs uppercase tracking-wide text-zinc-500">
              <tr>
                <th className="px-4 py-3">Title</th>
                <th className="px-4 py-3">Slug</th>
                <th className="px-4 py-3">Mode</th>
                <th className="px-4 py-3">Limit</th>
                <th className="px-4 py-3">Status</th>
              </tr>
            </thead>
            <tbody>
              {questionBanks.length === 0 ? (
                <tr>
                  <td
                    className="px-4 py-6 text-center text-sm text-zinc-500"
                    colSpan={5}
                  >
                    No question banks yet.
                  </td>
                </tr>
              ) : (
                questionBanks.map((bank) => (
                  <tr
                    key={bank.id}
                    className="border-t border-zinc-100"
                  >
                    <td className="px-4 py-3 font-medium text-zinc-900">
                      {bank.title}
                    </td>
                    <td className="px-4 py-3 text-xs text-zinc-500">
                      {bank.slug}
                    </td>
                    <td className="px-4 py-3">{bank.mode}</td>
                    <td className="px-4 py-3">
                      {bank.question_limit ?? "N/A"}
                    </td>
                    <td className="px-4 py-3">
                      {bank.is_active ? "Active" : "Paused"}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>

      <section id="users" className="flex flex-col gap-4">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold text-zinc-900">Recent users</h2>
          <span className="text-xs text-zinc-400">Latest 12 profiles</span>
        </div>
        <div className="overflow-hidden rounded-2xl border border-zinc-200 bg-white">
          <table className="w-full text-left text-sm text-zinc-700">
            <thead className="bg-zinc-50 text-xs uppercase tracking-wide text-zinc-500">
              <tr>
                <th className="px-4 py-3">Name</th>
                <th className="px-4 py-3">Role</th>
                <th className="px-4 py-3">Created</th>
              </tr>
            </thead>
            <tbody>
              {recentUsers.length === 0 ? (
                <tr>
                  <td
                    className="px-4 py-6 text-center text-sm text-zinc-500"
                    colSpan={3}
                  >
                    No users yet.
                  </td>
                </tr>
              ) : (
                recentUsers.map((user) => (
                  <tr key={user.id} className="border-t border-zinc-100">
                    <td className="px-4 py-3 font-medium text-zinc-900">
                      {user.display_name ?? "Unnamed"}
                    </td>
                    <td className="px-4 py-3">{user.role ?? "unknown"}</td>
                    <td className="px-4 py-3 text-xs text-zinc-500">
                      {formatDateTime(user.created_at)}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  );
}
