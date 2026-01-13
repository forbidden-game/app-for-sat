import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { randomUUID } from "crypto";
import * as dotenv from "dotenv";

dotenv.config({ path: ".env" });
dotenv.config({ path: ".env.local" });
dotenv.config({ path: ".env.test" });

type ProfileRow = { id: string; role: string; display_name: string | null };

type QuestionRow = { id: string };

type SessionRow = { id: string };

type AttemptRow = { id: string };

type ProcedureRow = { id: string; steps_version: number };

type AttemptInsightRow = { attempt_id: string };

type NotificationEventRow = { id: string };

type PushTokenRow = { id: string };

const DEFAULT_SUPABASE_URL = "http://127.0.0.1:54321";
const DEFAULT_SERVICE_ROLE_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU";

export function getEnv(name: string, fallback?: string): string {
  const value = process.env[name];
  if (value && value.length > 0) return value;
  if (fallback) return fallback;
  throw new Error(`Missing env var: ${name}`);
}

export function createLocalSupabase(): SupabaseClient {
  const supabaseUrl = getEnv("SUPABASE_URL", DEFAULT_SUPABASE_URL);
  const serviceRole = getEnv("SUPABASE_SERVICE_ROLE_KEY", DEFAULT_SERVICE_ROLE_KEY);

  return createClient(supabaseUrl, serviceRole, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}

export async function createProfile(
  supabase: SupabaseClient,
  overrides: Partial<ProfileRow> = {},
): Promise<ProfileRow> {
  const email = `test-${randomUUID()}@example.com`;
  const { data: created, error } = await supabase.auth.admin.createUser({
    email,
    password: `Test-${randomUUID()}`,
    email_confirm: true,
    user_metadata: { role: overrides.role ?? "student" },
  });

  if (error || !created.user) {
    throw new Error(`Failed to insert profile: ${error?.message ?? "unknown"}`);
  }

  const userId = created.user.id;
  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("id, role, display_name")
    .eq("id", userId)
    .single();

  if (profileError || !profile) {
    throw new Error(`Failed to load profile: ${profileError?.message ?? "unknown"}`);
  }

  if (overrides.display_name) {
    await supabase
      .from("profiles")
      .update({ display_name: overrides.display_name })
      .eq("id", userId);
  }

  if (overrides.role) {
    await supabase.from("profiles").update({ role: overrides.role }).eq("id", userId);
  }

  const { data: updated } = await supabase
    .from("profiles")
    .select("id, role, display_name")
    .eq("id", userId)
    .single();

  return (updated ?? profile) as ProfileRow;
}

export async function deleteProfile(supabase: SupabaseClient, id: string): Promise<void> {
  const { error } = await supabase.auth.admin.deleteUser(id);
  if (error) throw new Error(`Failed to delete profile: ${error.message}`);
}

export async function createQuestion(
  supabase: SupabaseClient,
  overrides: Partial<{ id: string; subject: string; module: string; difficulty: number; stem: string }> = {},
): Promise<QuestionRow> {
  const question = {
    id: overrides.id ?? randomUUID(),
    subject: overrides.subject ?? "math",
    module: overrides.module ?? "algebra",
    difficulty: overrides.difficulty ?? 1,
    question_type: "mcq",
    stem: overrides.stem ?? "Test question?",
    answer_key: { correct: "A" },
    metadata: {},
  };

  const { data, error } = await supabase.from("questions").insert(question).select("id").single();
  if (error || !data) {
    throw new Error(`Failed to insert question: ${error?.message ?? "unknown"}`);
  }

  return data as QuestionRow;
}

export async function createQuestionOptions(
  supabase: SupabaseClient,
  questionId: string,
  labels: string[] = ["A", "B", "C", "D"],
): Promise<void> {
  const rows = labels.map((label) => ({
    question_id: questionId,
    label,
    content: `Option ${label}`,
  }));

  const { error } = await supabase.from("question_options").insert(rows);
  if (error) throw new Error(`Failed to insert question options: ${error.message}`);
}

export async function createSession(
  supabase: SupabaseClient,
  studentId: string,
  overrides: Partial<{ id: string; total_questions: number; correct_count: number; mode: string }> = {},
): Promise<SessionRow> {
  const payload = {
    id: overrides.id ?? randomUUID(),
    student_id: studentId,
    total_questions: overrides.total_questions ?? 1,
    correct_count: overrides.correct_count ?? 0,
    mode: overrides.mode ?? "practice",
  };

  const { data, error } = await supabase.from("sessions").insert(payload).select("id").single();
  if (error || !data) {
    throw new Error(`Failed to insert session: ${error?.message ?? "unknown"}`);
  }

  return data as SessionRow;
}

export async function createAttempt(
  supabase: SupabaseClient,
  params: {
    studentId: string;
    sessionId: string;
    questionId: string;
    isCorrect?: boolean | null;
    createdAt?: string;
    skipped?: boolean;
  },
): Promise<AttemptRow> {
  const payload = {
    id: randomUUID(),
    student_id: params.studentId,
    session_id: params.sessionId,
    question_id: params.questionId,
    answer: { choice: "B" },
    is_correct: params.isCorrect ?? false,
    duration_ms: 12000,
    skipped: params.skipped ?? false,
    created_at: params.createdAt ?? new Date().toISOString(),
  };

  const { data, error } = await supabase.from("attempts").insert(payload).select("id").single();
  if (error || !data) {
    throw new Error(`Failed to insert attempt: ${error?.message ?? "unknown"}`);
  }

  return data as AttemptRow;
}

export async function createProcedure(
  supabase: SupabaseClient,
  overrides: Partial<{ id: string; subject: string; name: string; steps: string[]; steps_version: number }> = {},
): Promise<ProcedureRow> {
  const payload = {
    id: overrides.id ?? randomUUID(),
    subject: overrides.subject ?? "math",
    name: overrides.name ?? `Procedure-${randomUUID().slice(0, 6)}`,
    steps: overrides.steps ?? ["Step 1", "Step 2", "Step 3"],
    steps_version: overrides.steps_version ?? 1,
    aliases: [],
    status: "active",
    created_by: "test",
  };

  const { data, error } = await supabase.from("procedures").insert(payload).select("id, steps_version").single();
  if (error || !data) {
    throw new Error(`Failed to insert procedure: ${error?.message ?? "unknown"}`);
  }

  return data as ProcedureRow;
}

export async function createAttemptInsight(
  supabase: SupabaseClient,
  params: {
    attemptId: string;
    studentId: string;
    questionId: string;
    procedureId: string;
    errorStepIndex?: number;
    createdAt?: string;
  },
): Promise<AttemptInsightRow> {
  const payload = {
    attempt_id: params.attemptId,
    student_id: params.studentId,
    question_id: params.questionId,
    procedure_id: params.procedureId,
    procedure_steps_version: 1,
    error_step_index: params.errorStepIndex ?? 0,
    student_selected_step_index: null,
    student_selected_step_is_unknown: true,
    error_mode_enum: "unknown",
    evidence: {},
    explanation_short: "Test explanation",
    followups: [],
    created_at: params.createdAt ?? new Date().toISOString(),
  };

  const { data, error } = await supabase.from("attempt_insights").insert(payload).select("attempt_id").single();
  if (error || !data) {
    throw new Error(`Failed to insert attempt_insights: ${error?.message ?? "unknown"}`);
  }

  return data as AttemptInsightRow;
}

export async function createNotificationEvent(
  supabase: SupabaseClient,
  params: {
    studentId: string;
    status?: string;
    eventType?: string;
    createdAt?: string;
  },
): Promise<NotificationEventRow> {
  const payload = {
    student_id: params.studentId,
    event_type: params.eventType ?? "attempt_insight_ready",
    payload: {},
    status: params.status ?? "queued",
    created_at: params.createdAt ?? new Date().toISOString(),
    updated_at: params.createdAt ?? new Date().toISOString(),
  };

  const { data, error } = await supabase
    .from("notification_events")
    .insert(payload)
    .select("id")
    .single();
  if (error || !data) {
    throw new Error(`Failed to insert notification_event: ${error?.message ?? "unknown"}`);
  }

  return data as NotificationEventRow;
}

export async function createPushToken(
  supabase: SupabaseClient,
  params: { studentId: string; platform?: string; deviceToken?: string },
): Promise<PushTokenRow> {
  const payload = {
    student_id: params.studentId,
    device_token: params.deviceToken ?? `token-${randomUUID()}`,
    platform: params.platform ?? "apns",
    last_seen_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };

  const { data, error } = await supabase.from("push_tokens").insert(payload).select("id").single();
  if (error || !data) {
    throw new Error(`Failed to insert push_token: ${error?.message ?? "unknown"}`);
  }

  return data as PushTokenRow;
}

export async function cleanupByIds(
  supabase: SupabaseClient,
  table: string,
  ids: string[],
): Promise<void> {
  if (ids.length === 0) return;
  const { error } = await supabase.from(table).delete().in("id", ids);
  if (error) throw new Error(`Failed to cleanup ${table}: ${error.message}`);
}

export async function cleanupAttempts(supabase: SupabaseClient, ids: string[]): Promise<void> {
  if (ids.length === 0) return;
  const { error } = await supabase.from("attempts").delete().in("id", ids);
  if (error) throw new Error(`Failed to cleanup attempts: ${error.message}`);
}

export async function cleanupAttemptInsights(supabase: SupabaseClient, attemptIds: string[]): Promise<void> {
  if (attemptIds.length === 0) return;
  const { error } = await supabase.from("attempt_insights").delete().in("attempt_id", attemptIds);
  if (error) throw new Error(`Failed to cleanup attempt_insights: ${error.message}`);
}

export async function cleanupStudentSnapshots(supabase: SupabaseClient, studentIds: string[]): Promise<void> {
  if (studentIds.length === 0) return;
  const { error } = await supabase.from("student_snapshots").delete().in("student_id", studentIds);
  if (error) throw new Error(`Failed to cleanup student_snapshots: ${error.message}`);
}

export async function cleanupStudentReports(supabase: SupabaseClient, reportIds: string[]): Promise<void> {
  await cleanupByIds(supabase, "student_reports", reportIds);
}

export async function cleanupAiJobs(supabase: SupabaseClient, jobIds: string[]): Promise<void> {
  await cleanupByIds(supabase, "ai_jobs", jobIds);
}

export async function cleanupNotificationEvents(supabase: SupabaseClient, eventIds: string[]): Promise<void> {
  await cleanupByIds(supabase, "notification_events", eventIds);
}
