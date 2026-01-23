import type { SupabaseClient } from "@supabase/supabase-js";

import type { PeriodStats } from "../stats.js";
import { fetchPeriodStats } from "../stats.js";

const DAY_MS = 24 * 60 * 60 * 1000;

function subDays(date: Date, days: number): Date {
  return new Date(date.getTime() - days * DAY_MS);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function extractName(value: unknown): string | null {
  if (!isRecord(value)) return null;
  const name = value.name ?? value.procedure_name;
  return typeof name === "string" ? name : null;
}

function extractErrorMode(value: unknown): string | null {
  if (!isRecord(value)) return null;
  const mode = value.error_mode ?? value.error_mode_enum;
  return typeof mode === "string" ? mode : null;
}

function buildSnapshotNotes(stats: PeriodStats): string | null {
  const topProcedures = stats.mistakes.top_procedures
    .map(extractName)
    .filter((name): name is string => !!name)
    .slice(0, 2);

  const topModes = stats.mistakes.top_error_modes
    .map(extractErrorMode)
    .filter((name): name is string => !!name)
    .slice(0, 2);

  if (topProcedures.length === 0 && topModes.length === 0) return null;

  const procedureText = topProcedures.length > 0 ? `常见题型：${topProcedures.join("、")}` : "";
  const modeText = topModes.length > 0 ? `常见错误：${topModes.join("、")}` : "";

  return [procedureText, modeText].filter((item) => item.length > 0).join("；");
}

export async function processSnapshotRefreshJob(
  supabase: SupabaseClient,
  studentId: string,
  periodEndIso?: string | null,
): Promise<void> {
  let periodEnd = periodEndIso ? new Date(periodEndIso) : new Date();
  if (Number.isNaN(periodEnd.getTime())) {
    periodEnd = new Date();
  }
  const endIso = periodEnd.toISOString();

  const stats7 = await fetchPeriodStats(
    supabase,
    studentId,
    subDays(periodEnd, 7).toISOString(),
    endIso,
  );
  const stats30 = await fetchPeriodStats(
    supabase,
    studentId,
    subDays(periodEnd, 30).toISOString(),
    endIso,
  );
  const stats90 = await fetchPeriodStats(
    supabase,
    studentId,
    subDays(periodEnd, 90).toISOString(),
    endIso,
  );

  const snapshotPayload = {
    student_id: studentId,
    subject_scope: "all",
    weak_procedures_top: stats30.mistakes.top_procedures,
    weak_steps_top: stats30.mistakes.top_steps,
    common_error_modes_top: stats30.mistakes.top_error_modes,
    recent_trend: {
      window_7d: stats7,
      window_30d: stats30,
      window_90d: stats90,
    },
    notes: buildSnapshotNotes(stats30),
    updated_at: new Date().toISOString(),
  };

  const { error } = await supabase.from("student_snapshots").upsert(snapshotPayload, {
    onConflict: "student_id",
  });

  if (error) throw new Error(error.message);
}
