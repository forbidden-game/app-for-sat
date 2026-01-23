"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { getSupabaseClient } from "@/lib/supabaseClient";
import { getAdminOverview, type AdminOverview } from "./actions";
import { Skeleton, SkeletonCard } from "@/components/Skeleton";
import { EmptyState } from "@/components/EmptyState";
import { MetricCard } from "@/components/TrendIndicator";
import { useSortable, renderSortIcon } from "@/hooks/useSortable";

function formatDateTime(value: string | null | undefined) {
  if (!value) return "—";
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

type AdminOverviewClientProps = {
  initialOverview?: AdminOverview | null;
  initialError?: string | null;
};

export default function AdminOverviewClient({
  initialOverview = null,
  initialError = null,
}: AdminOverviewClientProps) {
  const supabase = getSupabaseClient();
  const [overview, setOverview] = useState<AdminOverview | null>(initialOverview);
  const [loading, setLoading] = useState(!initialOverview && !initialError);
  const [error, setError] = useState<string | null>(initialError);

  useEffect(() => {
    if (initialOverview || initialError) return;
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
          setError(
            loadError instanceof Error ? loadError.message : "Failed to load admin overview.",
          );
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
  }, [initialError, initialOverview, supabase]);

  const metrics = overview?.metrics ?? [];
  const questionBanks = overview?.question_banks ?? [];
  const recentUsers = overview?.recent_users ?? [];

  // Sortable hooks for tables
  const {
    sortedData: sortedQuestionBanks,
    handleSort: handleBankSort,
    sortConfig: bankSortConfig,
  } = useSortable(questionBanks, "title", "asc");
  const {
    sortedData: sortedRecentUsers,
    handleSort: handleUserSort,
    sortConfig: userSortConfig,
  } = useSortable(recentUsers, "created_at", "desc");

  if (loading) {
    return (
      <main className="mx-auto flex max-w-[1280px] flex-col gap-8 px-6 pb-10 pt-8">
        <header className="flex flex-wrap items-start justify-between gap-4">
          <div className="flex flex-col gap-2">
            <Skeleton variant="text" width="80px" />
            <Skeleton variant="text" width="200px" height="28px" />
            <Skeleton variant="text" width="150px" />
          </div>
          <Skeleton variant="rectangular" width="120px" height="28px" />
        </header>

        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {Array.from({ length: 4 }).map((_, i) => (
            <SkeletonCard key={i} />
          ))}
        </div>

        <div className="flex flex-col gap-4">
          <Skeleton variant="text" width="150px" height="24px" />
          <div className="overflow-hidden rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface)]">
            <div className="bg-[color:var(--surface-soft)] px-4 py-3">
              <div className="flex gap-4">
                {Array.from({ length: 5 }).map((_, i) => (
                  <Skeleton key={i} variant="text" width="20%" />
                ))}
              </div>
            </div>
            <div className="divide-y divide-[color:var(--border)] px-4 py-6">
              {Array.from({ length: 3 }).map((_, i) => (
                <div key={i} className="flex gap-4 py-3">
                  {Array.from({ length: 5 }).map((_, j) => (
                    <Skeleton key={j} variant="text" width="20%" />
                  ))}
                </div>
              ))}
            </div>
          </div>
        </div>
      </main>
    );
  }

  if (error) {
    return (
      <main className="mx-auto max-w-[1280px] px-6 py-12">
        <p className="text-sm text-[color:var(--danger-strong)]" role="alert">
          {error}
        </p>
      </main>
    );
  }

  if (!overview) {
    return (
      <main className="mx-auto max-w-[1280px] px-6 py-12">
        <p className="text-sm text-[color:var(--ink-muted)]">No admin data available.</p>
      </main>
    );
  }

  return (
    <main className="mx-auto flex max-w-[1280px] flex-col gap-8 px-6 pb-10 pt-8">
      <header className="flex flex-wrap items-start justify-between gap-4">
        <div className="flex flex-col gap-1">
          <p className="text-xs font-medium text-[color:var(--ink-muted)]">Admin Console</p>
          <h1 className="text-2xl font-semibold tracking-tight text-[color:var(--ink)]">
            Operations Overview
          </h1>
          <p className="text-sm text-[color:var(--ink-muted)]">
            Signed in as{" "}
            <span className="font-medium text-[color:var(--ink)]">
              {overview.admin.display_name ?? overview.admin.email ?? "Admin"}
            </span>
          </p>
        </div>
        <div className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface-soft)] px-3 py-1 text-[11px] font-medium text-[color:var(--ink-muted)]">
          Updated {formatDateTime(overview.generated_at)}
        </div>
      </header>

      <section className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        {metrics.map((metric) => {
          // Generate mock trend for demo purposes (in production, this would come from the API)
          const mockTrends: Record<string, number> = {
            "Total Users": 12,
            "Active Today": 8,
            Questions: 5,
            "Practice Sessions": -3,
          };
          const trend = mockTrends[metric.label];

          return (
            <MetricCard
              key={metric.label}
              label={metric.label}
              value={metric.value}
              helper={metric.helper}
              trend={trend}
              trendLabel="vs last week"
            />
          );
        })}
      </section>

      <section id="content" className="flex flex-col gap-4">
        <div className="flex items-center justify-between border-b border-[color:var(--border)] pb-3">
          <h2 className="text-lg font-semibold tracking-tight text-[color:var(--ink)]">
            Question Banks
          </h2>
          <Link
            className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-1.5 text-xs font-medium text-[color:var(--ink-muted)] transition hover:border-[color:var(--accent)] hover:text-[color:var(--ink)]"
            href="/admin/banks"
          >
            Manage Banks
          </Link>
        </div>
        <div className="overflow-hidden rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface)]">
          <div className="overflow-x-auto scrollbar-thin scrollbar-thumb-[color:var(--border)] scrollbar-track-transparent">
            <table className="w-full text-left text-sm text-[color:var(--ink-muted)] min-w-[600px]">
              <thead className="bg-[color:var(--surface-soft)] text-xs font-medium text-[color:var(--ink-muted)]">
                <tr>
                  <th
                    scope="col"
                    className="px-4 py-3 sticky left-0 bg-[color:var(--surface-soft)] min-w-[140px]"
                  >
                    Title
                  </th>
                  <th
                    scope="col"
                    className="px-4 py-3 min-w-[100px] cursor-pointer select-none hover:text-[color:var(--ink)]"
                    onClick={() => handleBankSort("slug")}
                  >
                    <span className="inline-flex items-center gap-1">
                      Slug
                      {renderSortIcon(bankSortConfig.column === "slug", bankSortConfig.direction)}
                    </span>
                  </th>
                  <th
                    scope="col"
                    className="px-4 py-3 min-w-[80px] cursor-pointer select-none hover:text-[color:var(--ink)]"
                    onClick={() => handleBankSort("mode")}
                  >
                    <span className="inline-flex items-center gap-1">
                      Mode
                      {renderSortIcon(bankSortConfig.column === "mode", bankSortConfig.direction)}
                    </span>
                  </th>
                  <th
                    scope="col"
                    className="px-4 py-3 min-w-[60px] cursor-pointer select-none hover:text-[color:var(--ink)] text-center"
                    onClick={() => handleBankSort("question_limit")}
                  >
                    <span className="inline-flex items-center gap-1 justify-center">
                      Limit
                      {renderSortIcon(
                        bankSortConfig.column === "question_limit",
                        bankSortConfig.direction,
                      )}
                    </span>
                  </th>
                  <th
                    scope="col"
                    className="px-4 py-3 min-w-[70px] cursor-pointer select-none hover:text-[color:var(--ink)]"
                    onClick={() => handleBankSort("is_active")}
                  >
                    <span className="inline-flex items-center gap-1">
                      Status
                      {renderSortIcon(
                        bankSortConfig.column === "is_active",
                        bankSortConfig.direction,
                      )}
                    </span>
                  </th>
                </tr>
              </thead>
              <tbody>
                {sortedQuestionBanks.length === 0 ? (
                  <tr>
                    <td colSpan={5}>
                      <EmptyState
                        title="No question banks yet"
                        description="Create your first question bank to start managing practice content."
                        icon="banks"
                        action={{
                          label: "Create Bank",
                          onClick: () => (window.location.href = "/admin/banks"),
                          variant: "primary",
                        }}
                        className="m-4"
                      />
                    </td>
                  </tr>
                ) : (
                  sortedQuestionBanks.map((bank) => (
                    <tr
                      key={bank.id}
                      className="border-t border-[color:var(--border)] transition-colors hover:bg-[color:var(--surface-soft)]"
                    >
                      <td className="px-4 py-3 font-medium text-[color:var(--ink)] sticky left-0 bg-[color:var(--surface)]">
                        {bank.title}
                      </td>
                      <td className="px-4 py-3 text-xs text-[color:var(--ink-muted)]">
                        {bank.slug}
                      </td>
                      <td className="px-4 py-3 text-xs text-[color:var(--ink-muted)]">
                        {bank.mode}
                      </td>
                      <td className="px-4 py-3 text-xs text-[color:var(--ink-muted)]">
                        {bank.question_limit ?? "N/A"}
                      </td>
                      <td className="px-4 py-3">
                        <span
                          className={`rounded-full px-2 py-0.5 text-[11px] font-medium text-white ${
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
        </div>
      </section>

      <section id="users" className="flex flex-col gap-4">
        <div className="flex items-center justify-between border-b border-[color:var(--border)] pb-3">
          <h2 className="text-lg font-semibold tracking-tight text-[color:var(--ink)]">
            Recent Users
          </h2>
          <span className="text-xs text-[color:var(--ink-muted)]">Latest 12 profiles</span>
        </div>
        <div className="overflow-hidden rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface)]">
          <table className="w-full text-left text-sm text-[color:var(--ink-muted)]">
            <thead className="bg-[color:var(--surface-soft)] text-xs font-medium text-[color:var(--ink-muted)]">
              <tr>
                <th
                  scope="col"
                  className="px-4 py-3 cursor-pointer select-none hover:text-[color:var(--ink)]"
                  onClick={() => handleUserSort("display_name")}
                >
                  <span className="inline-flex items-center gap-1">
                    Name
                    {renderSortIcon(
                      userSortConfig.column === "display_name",
                      userSortConfig.direction,
                    )}
                  </span>
                </th>
                <th
                  scope="col"
                  className="px-4 py-3 cursor-pointer select-none hover:text-[color:var(--ink)]"
                  onClick={() => handleUserSort("role")}
                >
                  <span className="inline-flex items-center gap-1">
                    Role
                    {renderSortIcon(userSortConfig.column === "role", userSortConfig.direction)}
                  </span>
                </th>
                <th
                  scope="col"
                  className="px-4 py-3 cursor-pointer select-none hover:text-[color:var(--ink)]"
                  onClick={() => handleUserSort("created_at")}
                >
                  <span className="inline-flex items-center gap-1">
                    Created
                    {renderSortIcon(
                      userSortConfig.column === "created_at",
                      userSortConfig.direction,
                    )}
                  </span>
                </th>
              </tr>
            </thead>
            <tbody>
              {sortedRecentUsers.length === 0 ? (
                <tr>
                  <td colSpan={3}>
                    <EmptyState
                      title="No users yet"
                      description="Users will appear here once students sign up for the platform."
                      icon="users"
                      className="m-4"
                    />
                  </td>
                </tr>
              ) : (
                sortedRecentUsers.map((user) => (
                  <tr key={user.id} className="border-t border-[color:var(--border)]">
                    <td className="px-4 py-3 font-medium text-[color:var(--ink)]">
                      {user.display_name ?? "Unnamed"}
                    </td>
                    <td className="px-4 py-3 text-xs text-[color:var(--ink-muted)]">
                      {user.role ?? "unknown"}
                    </td>
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
