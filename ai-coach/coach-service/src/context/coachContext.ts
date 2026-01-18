import type { SupabaseClient } from "@supabase/supabase-js";

import type { AttemptForCoach } from "../domain/attemptForCoach.js";
import { logger } from "../logger.js";

export type CoachMessage = {
  role: "user" | "assistant" | "tool";
  text: string;
  created_at: string;
  linked_attempt_id: string | null;
};

export type CoachContextPacket = {
  student: {
    id: string;
    display_name: string | null;
    time_zone: string;
    time_of_day: "morning" | "afternoon" | "evening" | "night";
    local_time_iso: string;
    recent_accuracy: number | null;
    accuracy_delta: number | null;
  };
  linked_attempt_id: string | null;
  attempt: AttemptForCoach["attempt"] | null;
  question: AttemptForCoach["question"] | null;
  linked_attempt_insight: unknown | null;
  snapshot: unknown | null;
  reports: unknown[];
  recent_insights: unknown[];
  recent_messages: CoachMessage[];
};

export type BuildCoachContextParams = {
  supabase: SupabaseClient;
  studentId?: string | null;
  attemptId?: string | null;
  linkedAttemptId?: string | null;
  messagesBeforeCreatedAt?: string | null;
  includeMessages?: boolean;
  includeReports?: boolean;
  includeInsights?: boolean;
  includeSnapshot?: boolean;
  messageLimit?: number;
  reportLimit?: number;
  insightLimit?: number;
  requireAttempt?: boolean;
};

type CoachThreadMessageRow = {
  id: string;
  student_id: string;
  role: "user" | "assistant" | "tool";
  content: unknown;
  created_at: string;
  linked_attempt_id: string | null;
};

type ProfileRow = { display_name: string | null };

const DEFAULT_TIME_ZONE = "UTC";

function extractText(content: unknown): string {
  if (!content || typeof content !== "object") return "";
  const maybeText = (content as { text?: unknown }).text;
  return typeof maybeText === "string" ? maybeText : "";
}

function resolveTimeOfDay(date: Date): "morning" | "afternoon" | "evening" | "night" {
  const hour = date.getUTCHours();
  if (hour >= 5 && hour < 12) return "morning";
  if (hour >= 12 && hour < 17) return "afternoon";
  if (hour >= 17 && hour < 22) return "evening";
  return "night";
}

function readAccuracy(reports: unknown[]): { recentAccuracy: number | null; accuracyDelta: number | null } {
  const latest = reports[0] as Record<string, unknown> | undefined;
  const metrics = (latest?.metrics as Record<string, unknown> | undefined) ?? undefined;
  const attempts = (metrics?.attempts as Record<string, unknown> | undefined) ?? undefined;
  const accuracy =
    typeof attempts?.accuracy === "number" && Number.isFinite(attempts.accuracy)
      ? attempts.accuracy
      : null;
  const delta = (latest?.delta as Record<string, unknown> | undefined) ?? undefined;
  const deltaAttempts = (delta?.attempts as Record<string, unknown> | undefined) ?? undefined;
  const accuracyDelta =
    typeof deltaAttempts?.accuracy === "number" && Number.isFinite(deltaAttempts.accuracy)
      ? deltaAttempts.accuracy
      : null;
  return { recentAccuracy: accuracy, accuracyDelta };
}

async function fetchAttemptContext(
  supabase: SupabaseClient,
  attemptId: string,
): Promise<AttemptForCoach | null> {
  const { data, error } = await supabase.rpc("get_attempt_for_coach", {
    p_attempt_id: attemptId,
  });
  if (error) {
    logger.warn({ err: error, attemptId }, "get_attempt_for_coach failed");
    return null;
  }
  return data as AttemptForCoach;
}

export async function buildCoachContext(params: BuildCoachContextParams): Promise<CoachContextPacket> {
  const attemptLookupId = params.attemptId ?? params.linkedAttemptId ?? null;
  const attemptContext = attemptLookupId ? await fetchAttemptContext(params.supabase, attemptLookupId) : null;

  if (params.requireAttempt && !attemptContext?.attempt?.id) {
    throw new Error("missing_attempt_context");
  }

  const resolvedStudentId =
    params.studentId ??
    attemptContext?.attempt?.student_id ??
    null;

  if (!resolvedStudentId) {
    throw new Error("missing_student_id");
  }

  const now = new Date();
  const timeOfDay = resolveTimeOfDay(now);

  let displayName: string | null = null;
  const { data: profileRow, error: profileError } = await params.supabase
    .from("profiles")
    .select("display_name")
    .eq("id", resolvedStudentId)
    .maybeSingle();
  if (profileError) {
    logger.warn({ err: profileError, studentId: resolvedStudentId }, "profile lookup failed");
  } else if (profileRow) {
    displayName = (profileRow as ProfileRow).display_name ?? null;
  }

  let snapshot: unknown | null = null;
  if (params.includeSnapshot !== false) {
    const { data, error } = await params.supabase
      .from("student_snapshots")
      .select("*")
      .eq("student_id", resolvedStudentId)
      .maybeSingle();
    if (error) {
      logger.warn({ err: error, studentId: resolvedStudentId }, "student snapshot lookup failed");
    } else {
      snapshot = data ?? null;
    }
  }

  let reports: unknown[] = [];
  if (params.includeReports !== false) {
    const { data, error } = await params.supabase
      .from("student_reports")
      .select("id, period_kind, period_key, period_start, period_end, summary, plan, metrics, delta, created_at")
      .eq("student_id", resolvedStudentId)
      .order("created_at", { ascending: false })
      .limit(params.reportLimit ?? 2);
    if (error) {
      logger.warn({ err: error, studentId: resolvedStudentId }, "student reports lookup failed");
    } else {
      reports = data ?? [];
    }
  }

  let recentInsights: unknown[] = [];
  if (params.includeInsights !== false) {
    const { data, error } = await params.supabase
      .from("attempt_insights")
      .select("attempt_id, procedure_id, error_step_index, error_mode_enum, explanation_short, created_at")
      .eq("student_id", resolvedStudentId)
      .order("created_at", { ascending: false })
      .limit(params.insightLimit ?? 5);
    if (error) {
      logger.warn({ err: error, studentId: resolvedStudentId }, "recent insights lookup failed");
    } else {
      recentInsights = data ?? [];
    }
  }

  let recentMessages: CoachMessage[] = [];
  if (params.includeMessages !== false) {
    let query = params.supabase
      .from("coach_thread_messages")
      .select("id,student_id,role,content,created_at,linked_attempt_id")
      .eq("student_id", resolvedStudentId);

    if (params.messagesBeforeCreatedAt) {
      query = query.lte("created_at", params.messagesBeforeCreatedAt);
    }

    const { data, error } = await query
      .order("created_at", { ascending: false })
      .limit(params.messageLimit ?? 30);
    if (error) {
      logger.warn({ err: error, studentId: resolvedStudentId }, "recent messages lookup failed");
    } else {
      const chronological = (data ?? []).slice().reverse() as CoachThreadMessageRow[];
      recentMessages = chronological.map((row) => ({
        role: row.role,
        text: extractText(row.content),
        created_at: row.created_at,
        linked_attempt_id: row.linked_attempt_id,
      }));
    }
  }

  let linkedAttemptInsight: unknown | null = null;
  if (attemptLookupId) {
    const { data, error } = await params.supabase
      .from("attempt_insights")
      .select("attempt_id,explanation_short,followups,error_step_index,error_mode_enum,procedure_id")
      .eq("attempt_id", attemptLookupId)
      .maybeSingle();
    if (error) {
      logger.warn({ err: error, attemptId: attemptLookupId }, "linked attempt insight lookup failed");
    } else {
      linkedAttemptInsight = data ?? null;
    }
  }

  const { recentAccuracy, accuracyDelta } = readAccuracy(reports);

  return {
    student: {
      id: resolvedStudentId,
      display_name: displayName,
      time_zone: DEFAULT_TIME_ZONE,
      time_of_day: timeOfDay,
      local_time_iso: now.toISOString(),
      recent_accuracy: recentAccuracy,
      accuracy_delta: accuracyDelta,
    },
    linked_attempt_id: attemptLookupId,
    attempt: attemptContext?.attempt ?? null,
    question: attemptContext?.question ?? null,
    linked_attempt_insight: linkedAttemptInsight,
    snapshot,
    reports,
    recent_insights: recentInsights,
    recent_messages: recentMessages,
  };
}
