import type { JobHandlerContext } from "./types.js";
import { processSnapshotRefreshJob } from "../processSnapshotRefreshJob.js";

function getStudentId(payload: unknown, jobStudentId: string | null): string | null {
  if (jobStudentId) return jobStudentId;
  const record = (payload ?? {}) as Record<string, unknown>;
  return typeof record.student_id === "string" ? record.student_id : null;
}

export async function handleSnapshotRefreshJob(ctx: JobHandlerContext): Promise<void> {
  const { supabase, job } = ctx;
  const studentId = getStudentId(job.payload, job.student_id);
  if (!studentId) throw new Error("missing student_id");

  const payload = (job.payload ?? {}) as Record<string, unknown>;
  const periodEnd = typeof payload.period_end === "string" ? payload.period_end : null;
  await processSnapshotRefreshJob(supabase, studentId, periodEnd);
}
