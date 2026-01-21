export type AiJobKind =
  | "attempt_insight"
  | "thread_summary"
  | "procedure_merge"
  | "coach_reply"
  | "snapshot_refresh"
  | "progress_report";

export type AiJobStatus = "queued" | "running" | "done" | "error";

export type AiJobRow = {
  id: string;
  kind: AiJobKind;
  status: AiJobStatus;
  attempt_id: string | null;
  student_id: string | null;
  payload: unknown;
  error: string | null;
  last_error: string | null;
  last_error_at: string | null;
  last_error_code: string | null;
  attempt_count: number | null;
  completed_at: string | null;
  locked_at: string | null;
  locked_by: string | null;
  run_after: string | null;
  dedupe_key: string | null;
  created_at: string;
  updated_at: string;
};
