export type AiJobKind = "attempt_insight" | "thread_summary" | "procedure_merge" | "coach_reply";

export type AiJobStatus = "queued" | "running" | "done" | "error";

export type AiJobRow = {
  id: string;
  kind: AiJobKind;
  status: AiJobStatus;
  attempt_id: string | null;
  student_id: string | null;
  payload: unknown;
  error: string | null;
  locked_at: string | null;
  locked_by: string | null;
  run_after: string | null;
  created_at: string;
  updated_at: string;
};
