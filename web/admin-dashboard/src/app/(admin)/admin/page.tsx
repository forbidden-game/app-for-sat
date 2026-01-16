"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { getSupabaseClient } from "@/lib/supabaseClient";
import { getAdminOverview, type AdminOverview } from "./actions";

function formatDateTime(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
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
          setError(loadError instanceof Error ? loadError.message : "Failed to load admin overview.");
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
  const questionBanks = useMemo(() => overview?.question_banks ?? [], [overview]);
  const recentUsers = useMemo(() => overview?.recent_users ?? [], [overview]);

  if (loading) {
    return (
      <main className="mx-auto max-w-[1440px] px-6 py-12">
        <p className="text-sm text-[color:var(--ink-muted)]" role="status" aria-live="polite">
          Loading admin overview…
        </p>
      </main>
    );
  }

  if (error) {
    return (
      <main className="mx-auto max-w-[1440px] px-6 py-12">
        <p className="text-sm text-[color:var(--danger-strong)]" role="alert">
          {error}
        </p>
      </main>
    );
  }

  if (!overview) {
    return (
      <main className="mx-auto max-w-[1440px] px-6 py-12">
        <p className="text-sm text-[color:var(--ink-muted)]">No admin data available.</p>
      </main>
    );
  }

  return (
    <main className="mx-auto flex max-w-[1440px] flex-col gap-8 px-6 pb-10 pt-8">
      <header className="flex flex-wrap items-start justify-between gap-4">
        <div className="flex flex-col gap-1">
          <p className="text-[11px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">Admin Console</p>
          <h1 className="text-2xl font-semibold text-[color:var(--ink)]">Operations Overview</h1>
          <p className="text-sm text-[color:var(--ink-muted)]">
            Signed in as{" "}
            <span className="font-medium text-[color:var(--ink)]">
              {overview.admin.display_name ?? overview.admin.email ?? "Admin"}
            </span>
          </p>
        </div>
        <div className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-1 text-[10px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
          Updated {formatDateTime(overview.generated_at)}
        </div>
      </header>

      <section className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        {metrics.map((metric) => (
          <div
            key={metric.label}
            className="rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface)] p-4"
          >
            <p className="text-[11px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
              {metric.label}
            </p>
            <p className="mt-2 text-2xl font-semibold text-[color:var(--ink)]">{metric.value}</p>
            {metric.helper ? (
              <p className="mt-1 text-xs text-[color:var(--ink-muted)]">{metric.helper}</p>
            ) : null}
          </div>
        ))}
      </section>

      <section id="content" className="flex flex-col gap-4">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold text-[color:var(--ink)]">Question Banks</h2>
          <Link
            className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-[color:var(--ink-muted)] transition hover:border-[color:var(--accent)] hover:text-[color:var(--ink)]"
            href="/admin/banks"
          >
            Manage Banks
          </Link>
        </div>
        <div className="overflow-hidden rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface)]">
          <table className="w-full text-left text-sm text-[color:var(--ink-muted)]">
            <thead className="bg-[color:var(--surface-soft)] text-[11px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
              <tr>
                <th scope="col" className="px-4 py-3">Title</th>
                <th scope="col" className="px-4 py-3">Slug</th>
                <th scope="col" className="px-4 py-3">Mode</th>
                <th scope="col" className="px-4 py-3">Limit</th>
                <th scope="col" className="px-4 py-3">Status</th>
              </tr>
            </thead>
            <tbody>
              {questionBanks.length === 0 ? (
                <tr>
                  <td
                    className="px-4 py-6 text-center text-sm text-[color:var(--ink-muted)]"
                    colSpan={5}
                    role="status"
                    aria-live="polite"
                  >
                    No question banks yet.
                  </td>
                </tr>
              ) : (
                questionBanks.map((bank) => (
                  <tr key={bank.id} className="border-t border-[color:var(--border)]">
                    <td className="px-4 py-3 font-medium text-[color:var(--ink)]">{bank.title}</td>
                    <td className="px-4 py-3 text-xs text-[color:var(--ink-muted)]">{bank.slug}</td>
                    <td className="px-4 py-3 text-xs text-[color:var(--ink-muted)]">{bank.mode}</td>
                    <td className="px-4 py-3 text-xs text-[color:var(--ink-muted)]">
                      {bank.question_limit ?? "N/A"}
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className={`rounded-full px-2 py-0.5 text-[10px] uppercase tracking-[0.2em] text-white ${
                          bank.is_active
                            ? "bg-[color:var(--accent-strong)]"
                            : "bg-[color:var(--danger-strong)]"
                        }`}
                      >
                        {bank.is_active ? "Active" : "Paused"}
                      </span>
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
          <h2 className="text-lg font-semibold text-[color:var(--ink)]">Recent Users</h2>
          <span className="text-xs text-[color:var(--ink-muted)]">Latest 12 profiles</span>
        </div>
        <div className="overflow-hidden rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface)]">
          <table className="w-full text-left text-sm text-[color:var(--ink-muted)]">
            <thead className="bg-[color:var(--surface-soft)] text-[11px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
              <tr>
                <th scope="col" className="px-4 py-3">Name</th>
                <th scope="col" className="px-4 py-3">Role</th>
                <th scope="col" className="px-4 py-3">Created</th>
              </tr>
            </thead>
            <tbody>
              {recentUsers.length === 0 ? (
                <tr>
                  <td
                    className="px-4 py-6 text-center text-sm text-[color:var(--ink-muted)]"
                    colSpan={3}
                    role="status"
                    aria-live="polite"
                  >
                    No users yet.
                  </td>
                </tr>
              ) : (
                recentUsers.map((user) => (
                  <tr key={user.id} className="border-t border-[color:var(--border)]">
                    <td className="px-4 py-3 font-medium text-[color:var(--ink)]">
                      {user.display_name ?? "Unnamed"}
                    </td>
                    <td className="px-4 py-3 text-xs text-[color:var(--ink-muted)]">{user.role ?? "unknown"}</td>
                    <td className="px-4 py-3 text-xs text-[color:var(--ink-muted)]">
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
