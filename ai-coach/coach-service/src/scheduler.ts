import type { SupabaseClient } from "@supabase/supabase-js";

import type { CoachConfig } from "./config.js";
import { logger } from "./logger.js";

const DAY_MS = 24 * 60 * 60 * 1000;

type ActiveStudentRow = {
  student_id: string;
};

function startOfDayUtc(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

function dateKey(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function subDays(date: Date, days: number): Date {
  return new Date(date.getTime() - days * DAY_MS);
}

async function listActiveStudents(supabase: SupabaseClient, sinceIso: string): Promise<string[]> {
  const { data, error } = await supabase.rpc("list_active_students", { p_since: sinceIso });
  if (error) throw new Error(error.message);
  return (data as ActiveStudentRow[] | null)?.map((row) => row.student_id) ?? [];
}

async function enqueueJob(
  supabase: SupabaseClient,
  payload: {
    kind: string;
    status: "queued";
    student_id: string;
    payload: Record<string, unknown>;
    run_after: string;
    dedupe_key: string | null;
  },
): Promise<void> {
  const { error } = await supabase.from("ai_jobs").insert(payload);

  if (error) {
    if (error.code === "23505") return;
    throw new Error(error.message);
  }
}

async function enqueueSnapshotRefresh(
  supabase: SupabaseClient,
  studentId: string,
  periodEnd: Date,
): Promise<void> {
  const key = `snapshot:${studentId}:${dateKey(periodEnd)}`;
  await enqueueJob(supabase, {
    kind: "snapshot_refresh",
    status: "queued",
    student_id: studentId,
    payload: { student_id: studentId, period_end: periodEnd.toISOString() },
    run_after: new Date().toISOString(),
    dedupe_key: key,
  });
}

async function enqueueProgressReport(
  supabase: SupabaseClient,
  studentId: string,
  periodKind: "weekly" | "monthly",
  periodDays: number,
  periodEnd: Date,
): Promise<void> {
  const periodStart = subDays(periodEnd, periodDays);
  const periodKey = `${periodKind}-${dateKey(periodEnd)}`;
  const key = `report:${studentId}:${periodKey}`;

  await enqueueJob(supabase, {
    kind: "progress_report",
    status: "queued",
    student_id: studentId,
    payload: {
      student_id: studentId,
      period_kind: periodKind,
      period_key: periodKey,
      period_start: periodStart.toISOString(),
      period_end: periodEnd.toISOString(),
    },
    run_after: new Date().toISOString(),
    dedupe_key: key,
  });
}

export async function scheduleRecurringJobs(config: CoachConfig, supabase: SupabaseClient): Promise<void> {
  const since = new Date(Date.now() - config.activeLookbackDays * DAY_MS).toISOString();
  const studentIds = await listActiveStudents(supabase, since);
  if (studentIds.length === 0) return;

  const periodEnd = startOfDayUtc(new Date());

  for (const studentId of studentIds) {
    try {
      await enqueueSnapshotRefresh(supabase, studentId, periodEnd);
      await enqueueProgressReport(supabase, studentId, "weekly", config.reportWeeklyDays, periodEnd);
      await enqueueProgressReport(supabase, studentId, "monthly", config.reportMonthlyDays, periodEnd);
    } catch (err) {
      logger.warn({ err, studentId }, "failed to enqueue scheduled jobs");
    }
  }
}
