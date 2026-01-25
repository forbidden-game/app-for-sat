"use client";

import { useCallback, useEffect, useState } from "react";
import { getSupabaseClient } from "@/lib/supabaseClient";
import { getStudyBehaviorList, type StudyBehaviorList, type StudyBehaviorItem } from "./actions";

const stateStyles: Record<string, string> = {
  "On Track": "border-emerald-200 bg-emerald-50 text-emerald-700",
  "Catching Up": "border-sky-200 bg-sky-50 text-sky-700",
  "Inconsistent": "border-amber-200 bg-amber-50 text-amber-700",
  "At Risk": "border-rose-200 bg-rose-50 text-rose-700",
  "No Data": "border-[color:var(--border)] bg-[color:var(--surface-soft)] text-[color:var(--ink-muted)]",
};

function formatPercent(value: number | null) {
  if (value === null || Number.isNaN(value)) return "N/A";
  return `${Math.round(value * 100)}%`;
}

function formatDelta(value: number, digits = 1) {
  const sign = value >= 0 ? "+" : "";
  return `${sign}${value.toFixed(digits)}`;
}

function Metric({ label, value, delta }: { label: string; value: string; delta?: string }) {
  return (
    <div className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] p-3">
      <p className="text-xs font-medium text-[color:var(--ink-muted)]">{label}</p>
      <p className="mt-2 text-lg font-semibold text-[color:var(--ink)]">{value}</p>
      {delta ? <p className="mt-1 text-xs text-[color:var(--ink-muted)]">{delta}</p> : null}
    </div>
  );
}

function BehaviorCard({ item, windowDays }: { item: StudyBehaviorItem; windowDays: number }) {
  const label = item.behavior?.state.label ?? "No Data";
  const stateClass = stateStyles[label] ?? stateStyles["No Data"];

  return (
    <section className="rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface)] p-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p className="text-sm font-semibold text-[color:var(--ink)]">
            {item.student.display_name || "Student"}
          </p>
          <p className="mt-1 text-xs text-[color:var(--ink-muted)]">{item.student.id}</p>
        </div>
        <span className={`rounded-full border px-3 py-1 text-xs font-semibold ${stateClass}`}>
          {label}
        </span>
      </div>

      {item.error ? (
        <p className="mt-4 text-sm text-[color:var(--ink-muted)]">{item.error}</p>
      ) : item.behavior ? (
        <div className="mt-4 grid gap-3 sm:grid-cols-3">
          <Metric
            label="Time spent"
            value={`${item.behavior.metrics.minutes.toFixed(1)} min`}
            delta={`${formatDelta(item.behavior.metrics.minutes_delta)} min vs prior ${windowDays}d`}
          />
          <Metric
            label="Outcome improvement"
            value={formatPercent(item.behavior.metrics.accuracy)}
            delta={`${formatDelta(item.behavior.metrics.accuracy_delta ?? 0, 0)}% vs prior ${windowDays}d`}
          />
          <Metric
            label="Consistency"
            value={`${item.behavior.metrics.active_days}/${windowDays} days`}
            delta={`${formatDelta(item.behavior.metrics.active_days_delta, 0)} days vs prior ${windowDays}d`}
          />
        </div>
      ) : (
        <p className="mt-4 text-sm text-[color:var(--ink-muted)]">Behavior data unavailable.</p>
      )}
    </section>
  );
}

export default function BehaviorClient({
  initialData,
  initialError,
}: {
  initialData?: StudyBehaviorList | null;
  initialError?: string | null;
}) {
  const supabase = getSupabaseClient();
  const [data, setData] = useState<StudyBehaviorList | null>(initialData ?? null);
  const [loading, setLoading] = useState(!initialData && !initialError);
  const [error, setError] = useState<string | null>(initialError ?? null);

  const loadData = useCallback(async () => {
    if (!supabase) {
      setError("Supabase not configured.");
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    const { data: sessionData } = await supabase.auth.getSession();
    const session = sessionData.session;
    if (!session) {
      setError("You are not signed in.");
      setLoading(false);
      return;
    }

    try {
      const result = await getStudyBehaviorList(session.access_token, { limit: 30, windowDays: 7 });
      setData(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load study behavior.");
    } finally {
      setLoading(false);
    }
  }, [supabase]);

  useEffect(() => {
    if (!initialData && !initialError) {
      void loadData();
    }
  }, [initialData, initialError, loadData]);

  return (
    <main className="mx-auto max-w-[1280px] px-6 py-12">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
            Study Behavior
          </p>
          <h1 className="mt-2 text-2xl font-semibold text-[color:var(--ink)]">Teacher View</h1>
          <p className="mt-2 text-sm text-[color:var(--ink-muted)]">
            Highlights time spent, outcome improvement, and consistency for recent students.
          </p>
        </div>
        <button
          type="button"
          onClick={() => void loadData()}
          className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-4 py-1.5 text-xs font-medium text-[color:var(--ink)] transition hover:bg-[color:var(--surface-soft)]"
          disabled={loading}
        >
          {loading ? "Refreshing…" : "Refresh"}
        </button>
      </div>

      {error ? (
        <p className="mt-6 text-sm text-[color:var(--danger-strong)]">{error}</p>
      ) : null}

      {loading ? (
        <p className="mt-6 text-sm text-[color:var(--ink-muted)]">Loading study behavior…</p>
      ) : null}

      {data ? (
        <div className="mt-8 grid gap-4">
          {data.items.map((item) => (
            <BehaviorCard key={item.student.id} item={item} windowDays={data.window_days} />
          ))}
        </div>
      ) : null}
    </main>
  );
}
