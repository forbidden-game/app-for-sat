import type { Agent } from "@mariozechner/pi-agent-core";
import type { SupabaseClient } from "@supabase/supabase-js";

import { logger } from "../logger.js";
import type { AiJobRow } from "../types.js";
import { buildCoachReplyPrompt } from "../prompts/coachReplyPrompt.js";

type CoachContent = {
  text?: string;
  status?: "streaming" | "done" | "error";
};

type CoachThreadMessageRow = {
  id: string;
  student_id: string;
  role: "user" | "assistant" | "tool";
  content: CoachContent;
  created_at: string;
  linked_attempt_id: string | null;
};

function extractText(content: unknown): string {
  if (!content || typeof content !== "object") return "";
  const maybeText = (content as any).text;
  return typeof maybeText === "string" ? maybeText : "";
}

async function insertAssistantMessage(
  supabase: SupabaseClient,
  studentId: string,
  linkedAttemptId: string | null,
): Promise<string> {
  const { data, error } = await supabase
    .from("coach_thread_messages")
    .insert({
      student_id: studentId,
      role: "assistant",
      content: { text: "", status: "streaming" },
      linked_attempt_id: linkedAttemptId,
    })
    .select("id")
    .single();

  if (error || !data) throw new Error(error?.message ?? "assistant_message_insert_failed");
  return data.id as string;
}

async function updateAssistantMessage(
  supabase: SupabaseClient,
  messageId: string,
  content: CoachContent,
): Promise<void> {
  const { error } = await supabase.from("coach_thread_messages").update({ content }).eq("id", messageId);
  if (error) throw new Error(error.message);
}

export async function processCoachReplyJob(
  supabase: SupabaseClient,
  agent: Agent,
  job: AiJobRow,
): Promise<void> {
  if (!job.student_id) throw new Error("missing student_id");
  const studentId = job.student_id;

  const payload = (job.payload ?? {}) as any;
  const linkedAttemptId = typeof payload.linked_attempt_id === "string" ? payload.linked_attempt_id : null;

  const { data: snapshotRow, error: snapshotError } = await supabase
    .from("student_snapshots")
    .select("*")
    .eq("student_id", studentId)
    .maybeSingle();
  if (snapshotError) throw new Error(snapshotError.message);

  const { data: recentReports, error: reportError } = await supabase
    .from("student_reports")
    .select("id, period_kind, period_key, period_start, period_end, summary, plan, metrics, delta, created_at")
    .eq("student_id", studentId)
    .order("created_at", { ascending: false })
    .limit(2);
  if (reportError) throw new Error(reportError.message);

  const { data: recentInsights, error: insightError } = await supabase
    .from("attempt_insights")
    .select("attempt_id, procedure_id, error_step_index, error_mode_enum, explanation_short, created_at")
    .eq("student_id", studentId)
    .order("created_at", { ascending: false })
    .limit(5);
  if (insightError) throw new Error(insightError.message);

  const { data: recentMessages, error: msgError } = await supabase
    .from("coach_thread_messages")
    .select("id,student_id,role,content,created_at,linked_attempt_id")
    .eq("student_id", studentId)
    .order("created_at", { ascending: false })
    .limit(30);
  if (msgError) throw new Error(msgError.message);

  const chronological = (recentMessages ?? []).slice().reverse() as CoachThreadMessageRow[];

  const messages = chronological.map((m) => ({
    role: m.role,
    text: extractText(m.content),
    created_at: m.created_at,
  }));

  let linkedAttemptInsight: unknown | null = null;
  if (linkedAttemptId) {
    const { data: insight, error: linkedError } = await supabase
      .from("attempt_insights")
      .select("attempt_id,explanation_short,followups,error_step_index,error_mode_enum,procedure_id")
      .eq("attempt_id", linkedAttemptId)
      .maybeSingle();

    if (linkedError) {
      logger.warn({ err: linkedError, linkedAttemptId }, "failed to load linked attempt insight");
    } else {
      linkedAttemptInsight = insight ?? null;
    }
  }

  const assistantMessageId = await insertAssistantMessage(supabase, studentId, linkedAttemptId);

  let buffer = "";
  let lastFlushAt = 0;
  let lastFlushedLength = 0;

  const flush = async (status: CoachContent["status"], force: boolean): Promise<void> => {
    const now = Date.now();
    if (!force && now - lastFlushAt < 250 && buffer.length - lastFlushedLength < 40) return;
    lastFlushAt = now;
    lastFlushedLength = buffer.length;

    await updateAssistantMessage(supabase, assistantMessageId, { text: buffer, status: status ?? "streaming" });
  };

  const unsubscribe = agent.subscribe((event) => {
    if (event.type !== "message_update") return;
    const a = (event as any).assistantMessageEvent;
    if (!a || a.type !== "text_delta") return;
    const delta = a.delta;
    if (typeof delta !== "string" || delta.length === 0) return;
    buffer += delta;

    void flush("streaming", false).catch((err) => {
      logger.warn({ err, assistantMessageId }, "failed to stream update");
    });
  });

  try {
    const prompt = buildCoachReplyPrompt({
      studentId,
      snapshot: snapshotRow ?? null,
      reports: recentReports ?? [],
      recentInsights: recentInsights ?? [],
      messages,
      linkedAttemptInsight,
    });

    await agent.prompt(prompt);

    await flush("done", true);
  } catch (err) {
    logger.error({ err, jobId: job.id }, "coach reply generation failed");
    buffer = buffer.trim().length > 0 ? buffer : "我先确认一下：你是卡在题意理解、列式，还是计算这一步？";
    await updateAssistantMessage(supabase, assistantMessageId, { text: buffer, status: "error" });
    throw err;
  } finally {
    unsubscribe();
  }
}
