import type { SupabaseClient } from "@supabase/supabase-js";

import type { CoachConfig } from "./config.js";
import { logger } from "./logger.js";

const DAY_MS = 24 * 60 * 60 * 1000;
const BATCH_SIZE = 200;

type ActiveStudentRow = {
  student_id: string;
};

type JobInsertPayload = {
  kind: string;
  status: "queued";
  student_id: string;
  payload: Record<string, unknown>;
  run_after: string;
  dedupe_key: string | null;
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

async function enqueueJobs(supabase: SupabaseClient, payloads: JobInsertPayload[]): Promise<void> {
  if (payloads.length === 0) return;

  const { error } = await supabase.from("ai_jobs").upsert(payloads, {
    onConflict: "kind,dedupe_key",
    ignoreDuplicates: true,
  });

  if (error) {
    throw new Error(error.message);
  }
}

function buildSnapshotRefreshJob(studentId: string, periodEnd: Date): JobInsertPayload {
  const key = `snapshot:${studentId}:${dateKey(periodEnd)}`;
  return {
    kind: "snapshot_refresh",
    status: "queued",
    student_id: studentId,
    payload: { student_id: studentId, period_end: periodEnd.toISOString() },
    run_after: new Date().toISOString(),
    dedupe_key: key,
  };
}

function buildProgressReportJob(
  studentId: string,
  periodKind: "weekly" | "monthly",
  periodDays: number,
  periodEnd: Date,
): JobInsertPayload {
  const periodStart = subDays(periodEnd, periodDays);
  const periodKey = `${periodKind}-${dateKey(periodEnd)}`;
  const key = `report:${studentId}:${periodKey}`;

  return {
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
  };
}

export async function scheduleRecurringJobs(config: CoachConfig, supabase: SupabaseClient): Promise<void> {
  const since = new Date(Date.now() - config.activeLookbackDays * DAY_MS).toISOString();
  const studentIds = await listActiveStudents(supabase, since);
  if (studentIds.length === 0) return;

  const periodEnd = startOfDayUtc(new Date());
  const payloads: JobInsertPayload[] = [];

  for (const studentId of studentIds) {
    payloads.push(buildSnapshotRefreshJob(studentId, periodEnd));
    payloads.push(buildProgressReportJob(studentId, "weekly", config.reportWeeklyDays, periodEnd));
    payloads.push(buildProgressReportJob(studentId, "monthly", config.reportMonthlyDays, periodEnd));
  }

  for (let i = 0; i < payloads.length; i += BATCH_SIZE) {
    const batch = payloads.slice(i, i + BATCH_SIZE);
    try {
      await enqueueJobs(supabase, batch);
    } catch (err) {
      logger.warn({ err, batchSize: batch.length }, "failed to enqueue scheduled jobs");
    }
  }
}
