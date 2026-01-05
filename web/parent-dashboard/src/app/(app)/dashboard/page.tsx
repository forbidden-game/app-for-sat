"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { getSupabaseClient } from "../../../lib/supabaseClient";
import { formatPercent } from "../../../lib/format";

type ParentDashboard = {
  student: {
    id: string;
    name: string;
    grade: string;
  };
  overview: {
    window_days: number;
    practice_minutes: number;
    accuracy: number | null;
    error_rate: number | null;
    rank_percentile: number | null;
    attempts: number;
  };
  trend: Array<{
    session_id: string;
    created_at: string;
    accuracy: number | null;
    rank_percentile: number | null;
    attempts: number;
    duration_minutes: number;
  }>;
  topics: Array<{
    tag_id: string;
    tag_name: string;
    accuracy: number | null;
    attempts: number;
  }>;
};

const chartWidth = 520;
const chartHeight = 180;
const chartPadding = 16;

function buildLinePoints(values: number[], width: number, height: number) {
  if (values.length === 0) return "";
  const step = values.length === 1 ? 0 : (width - chartPadding * 2) / (values.length - 1);
  return values
    .map((value, index) => {
      const x = chartPadding + step * index;
      const y = chartPadding + (1 - value) * (height - chartPadding * 2);
      return `${x},${y}`;
    })
    .join(" ");
}

function formatPercentOrNA(value: number | null) {
  if (value === null || Number.isNaN(value)) return "N/A";
  return formatPercent(value);
}

function formatShortDate(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

export default function DashboardPage() {
  const supabase = getSupabaseClient();
  const [dashboard, setDashboard] = useState<ParentDashboard | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [hasLinkedStudent, setHasLinkedStudent] = useState(true);

  useEffect(() => {
    let isActive = true;
    async function loadDashboard() {
      if (!supabase) {
        if (isActive) {
          setError("Supabase not configured.");
          setLoading(false);
        }
        return;
      }

      setLoading(true);
      setError(null);

      const { data: links, error: linksError } = await supabase
        .from("parent_student_links")
        .select("student_id")
        .eq("status", "active")
        .limit(1);

      if (linksError) {
        if (isActive) {
          setError("Failed to load linked student.");
          setLoading(false);
        }
        return;
      }

      if (!links || links.length === 0) {
        if (isActive) {
          setHasLinkedStudent(false);
          setLoading(false);
        }
        return;
      }

      const targetStudentId = links[0].student_id;
      const { data, error: rpcError } = await supabase.rpc(
        "get_parent_dashboard",
        {
          target_student_id: targetStudentId,
          window_days: 7,
        },
      );

      if (rpcError) {
        if (isActive) {
          setError("Failed to load dashboard data.");
          setLoading(false);
        }
        return;
      }

      if (isActive) {
        setDashboard(data as ParentDashboard);
        setLoading(false);
      }
    }

    loadDashboard();
    return () => {
      isActive = false;
    };
  }, [supabase]);

  const topics = useMemo(() => {
    if (!dashboard) return [] as ParentDashboard["topics"];
    return [...dashboard.topics].sort(
      (a, b) => (a.accuracy ?? 0) - (b.accuracy ?? 0),
    );
  }, [dashboard]);

  const strengths = useMemo(() => topics.slice(-3).reverse(), [topics]);
  const weaknesses = useMemo(() => topics.slice(0, 3), [topics]);

  const accuracySeries = useMemo(() => {
    if (!dashboard) return [] as number[];
    return dashboard.trend.map((point) => point.accuracy ?? 0);
  }, [dashboard]);

  const rankSeries = useMemo(() => {
    if (!dashboard) return [] as Array<number | null>;
    return dashboard.trend.map((point) => point.rank_percentile);
  }, [dashboard]);

  const hasRankSeries = rankSeries.some((value) => value !== null);
  const accuracyPoints = buildLinePoints(
    accuracySeries,
    chartWidth,
    chartHeight,
  );
  const rankPoints = hasRankSeries
    ? buildLinePoints(
        rankSeries.map((value) => value ?? 0),
        chartWidth,
        chartHeight,
      )
    : "";

  if (loading) {
    return (
      <main className="mx-auto max-w-5xl px-6 py-12">
        <p className="text-sm text-zinc-500">Loading dashboard...</p>
      </main>
    );
  }

  if (error) {
    return (
      <main className="mx-auto max-w-5xl px-6 py-12">
        <p className="text-sm text-red-600">{error}</p>
      </main>
    );
  }

  if (!hasLinkedStudent) {
    return (
      <main className="mx-auto max-w-5xl px-6 py-12">
        <p className="text-sm text-zinc-500">
          No linked student yet. Ask the student to redeem a parent invite.
        </p>
      </main>
    );
  }

  if (!dashboard) {
    return (
      <main className="mx-auto max-w-5xl px-6 py-12">
        <p className="text-sm text-zinc-500">No data available.</p>
      </main>
    );
  }

  return (
    <main className="mx-auto max-w-5xl px-6 py-8">
      <div className="flex flex-col gap-2">
        <p className="text-sm text-zinc-500">Parent overview</p>
        <h1 className="text-2xl font-semibold text-zinc-900">
          {dashboard.student.name || "Student"}
        </h1>
        {dashboard.student.grade ? (
          <p className="text-sm text-zinc-500">Grade {dashboard.student.grade}</p>
        ) : null}
      </div>

      <div className="mt-6 grid gap-4 sm:grid-cols-3">
        <div className="rounded-xl border border-zinc-200 bg-white p-4 shadow-sm">
          <p className="text-sm text-zinc-500">
            Study time ({dashboard.overview.window_days}d)
          </p>
          <p className="mt-2 text-2xl font-semibold text-zinc-900">
            {dashboard.overview.practice_minutes.toFixed(1)} min
          </p>
          <p className="mt-1 text-xs text-zinc-400">
            {dashboard.overview.attempts} attempts
          </p>
        </div>
        <div className="rounded-xl border border-zinc-200 bg-white p-4 shadow-sm">
          <p className="text-sm text-zinc-500">
            Error rate ({dashboard.overview.window_days}d)
          </p>
          <p className="mt-2 text-2xl font-semibold text-zinc-900">
            {formatPercentOrNA(dashboard.overview.error_rate)}
          </p>
          <p className="mt-1 text-xs text-zinc-400">
            Accuracy {formatPercentOrNA(dashboard.overview.accuracy)}
          </p>
        </div>
        <div className="rounded-xl border border-zinc-200 bg-white p-4 shadow-sm">
          <p className="text-sm text-zinc-500">
            Rank percentile ({dashboard.overview.window_days}d)
          </p>
          <p className="mt-2 text-2xl font-semibold text-zinc-900">
            {formatPercentOrNA(dashboard.overview.rank_percentile)}
          </p>
          <p className="mt-1 text-xs text-zinc-400">
            All users · min 20 attempts
          </p>
        </div>
      </div>

      <div className="mt-8 grid gap-6 lg:grid-cols-[2fr,1fr]">
        <section className="rounded-xl border border-zinc-200 bg-white p-5 shadow-sm">
          <div className="flex items-center justify-between">
            <h2 className="text-base font-semibold text-zinc-900">
              Last 5 sessions trend
            </h2>
            <span className="text-xs text-zinc-400">
              Accuracy vs rank percentile
            </span>
          </div>
          {dashboard.trend.length === 0 ? (
            <p className="mt-4 text-sm text-zinc-500">
              No session data yet.
            </p>
          ) : (
            <>
              <div className="mt-4 rounded-lg border border-zinc-100 bg-zinc-50 p-3">
                <svg
                  viewBox={`0 0 ${chartWidth} ${chartHeight}`}
                  className="h-40 w-full"
                  role="img"
                  aria-label="Accuracy and rank percentile trend"
                >
                  <polyline
                    fill="none"
                    stroke="#18181b"
                    strokeWidth="3"
                    points={accuracyPoints}
                  />
                  {hasRankSeries ? (
                    <polyline
                      fill="none"
                      stroke="#71717a"
                      strokeWidth="2"
                      strokeDasharray="6 6"
                      points={rankPoints}
                    />
                  ) : null}
                </svg>
              </div>
              <div className="mt-3 flex items-center gap-4 text-xs text-zinc-500">
                <div className="flex items-center gap-2">
                  <span className="h-2 w-6 rounded-full bg-zinc-900" />
                  <span>Accuracy</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="h-0.5 w-6 bg-zinc-400" />
                  <span>Rank percentile</span>
                </div>
              </div>
            </>
          )}
        </section>

        <section className="rounded-xl border border-zinc-200 bg-white p-5 shadow-sm">
          <h2 className="text-base font-semibold text-zinc-900">
            Strengths & weaknesses
          </h2>
          <p className="mt-1 text-xs text-zinc-400">
            Last {dashboard.overview.window_days} days · min 10 attempts
          </p>
          <div className="mt-4">
            <p className="text-xs font-semibold uppercase text-zinc-500">
              Strengths
            </p>
            <div className="mt-3 space-y-3">
              {strengths.length === 0 ? (
                <p className="text-xs text-zinc-500">No topic data yet.</p>
              ) : (
                strengths.map((topic) => (
                  <div
                    key={topic.tag_id}
                    className="flex items-center justify-between text-sm"
                  >
                    <div>
                      <p className="font-medium text-zinc-900">
                        {topic.tag_name}
                      </p>
                      <p className="text-xs text-zinc-500">
                        {topic.attempts} attempts
                      </p>
                    </div>
                    <span className="text-zinc-900">
                      {formatPercentOrNA(topic.accuracy)}
                    </span>
                  </div>
                ))
              )}
            </div>
          </div>
          <div className="mt-6">
            <p className="text-xs font-semibold uppercase text-zinc-500">
              Weaknesses
            </p>
            <div className="mt-3 space-y-3">
              {weaknesses.length === 0 ? (
                <p className="text-xs text-zinc-500">No topic data yet.</p>
              ) : (
                weaknesses.map((topic) => (
                  <div
                    key={topic.tag_id}
                    className="flex items-center justify-between text-sm"
                  >
                    <div>
                      <p className="font-medium text-zinc-900">
                        {topic.tag_name}
                      </p>
                      <p className="text-xs text-zinc-500">
                        {topic.attempts} attempts
                      </p>
                    </div>
                    <span className="text-zinc-900">
                      {formatPercentOrNA(topic.accuracy)}
                    </span>
                  </div>
                ))
              )}
            </div>
          </div>
        </section>
      </div>

      <section className="mt-8 rounded-xl border border-zinc-200 bg-white p-5 shadow-sm">
        <div className="flex items-center justify-between">
          <h2 className="text-base font-semibold text-zinc-900">Recent sessions</h2>
          <Link
            href="/sessions"
            className="text-xs font-semibold text-zinc-500 hover:text-zinc-900"
          >
            View all
          </Link>
        </div>
        <div className="mt-4 divide-y divide-zinc-100">
          {dashboard.trend.length === 0 ? (
            <p className="py-3 text-sm text-zinc-500">No sessions yet.</p>
          ) : (
            dashboard.trend.map((session) => (
              <div
                key={session.session_id}
                className="flex flex-wrap items-center justify-between gap-4 py-3 text-sm"
              >
                <div>
                  <p className="font-medium text-zinc-900">
                    {formatShortDate(session.created_at)}
                  </p>
                  <p className="text-xs text-zinc-500">
                    {session.attempts} attempts · {session.duration_minutes.toFixed(1)} min
                  </p>
                </div>
                <div className="flex items-center gap-6 text-right">
                  <div>
                    <p className="font-semibold text-zinc-900">
                      {formatPercentOrNA(session.accuracy)}
                    </p>
                    <p className="text-xs text-zinc-400">
                      Rank {formatPercentOrNA(session.rank_percentile)}
                    </p>
                  </div>
                  <Link
                    href={`/sessions/${session.session_id}`}
                    className="text-xs font-semibold text-zinc-500 hover:text-zinc-900"
                  >
                    View details
                  </Link>
                </div>
              </div>
            ))
          )}
        </div>
      </section>
    </main>
  );
}
