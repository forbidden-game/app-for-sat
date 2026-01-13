export type NotificationStatus = "queued" | "sending" | "sent" | "error";

export type NotificationEventRow = {
  id: string;
  student_id: string;
  event_type: string;
  payload: Record<string, unknown>;
  status: NotificationStatus;
  error: string | null;
  locked_at: string | null;
  locked_by: string | null;
  created_at: string;
  updated_at: string;
};
