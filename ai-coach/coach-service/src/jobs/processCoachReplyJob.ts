import type { Agent } from "@mariozechner/pi-agent-core";
import type { SupabaseClient } from "@supabase/supabase-js";

import { buildCoachContext } from "../context/coachContext.js";
import { logger } from "../logger.js";
import type { AiJobRow } from "../types.js";
import { buildCoachReplyPrompt, type CoachReplyTargetMessage } from "../prompts/coachReplyPrompt.js";

type CoachContent = {
  text?: string;
  status?: "streaming" | "done" | "error";
};

type CoachThreadMessageRow = {
  id: string;
  student_id: string;
  role: "user" | "assistant" | "tool";
  content: unknown;
  created_at: string;
  linked_attempt_id: string | null;
  reply_to_message_id: string | null;
};

function extractText(content: unknown): string {
  if (!content || typeof content !== "object") return "";
  const maybeText = (content as { text?: unknown }).text;
  return typeof maybeText === "string" ? maybeText : "";
}

export type CoachReplyLogSink = {
  recordPrompt?: (prompt: string) => void;
};

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

async function fetchThreadMessage(
  supabase: SupabaseClient,
  studentId: string,
  messageId: string,
): Promise<CoachThreadMessageRow | null> {
  const { data, error } = await supabase
    .from("coach_thread_messages")
    .select("id,student_id,role,content,created_at,linked_attempt_id,reply_to_message_id")
    .eq("id", messageId)
    .maybeSingle();

  if (error) throw new Error(error.message);
  if (!data) return null;

  const row = data as CoachThreadMessageRow;
  if (row.student_id !== studentId) {
    // The worker runs with service role; enforce ownership at the application layer.
    throw new Error("user_message_forbidden");
  }

  return row;
}

async function fetchTargetUserMessage(
  supabase: SupabaseClient,
  studentId: string,
  userMessageId: string,
): Promise<CoachThreadMessageRow> {
  const row = await fetchThreadMessage(supabase, studentId, userMessageId);
  if (!row) throw new Error("user_message_not_found");
  return row;
}

export async function processCoachReplyJob(
  supabase: SupabaseClient,
  agent: Agent,
  job: AiJobRow,
  log?: CoachReplyLogSink,
): Promise<void> {
  if (!job.student_id) throw new Error("missing student_id");
  const studentId = job.student_id;

  const payload = (job.payload ?? {}) as Record<string, unknown>;
  const userMessageId = typeof payload.user_message_id === "string" ? payload.user_message_id : null;

  let linkedAttemptId = typeof payload.linked_attempt_id === "string" ? payload.linked_attempt_id : null;
  let messagesBeforeCreatedAt: string | null = null;
  let target: CoachReplyTargetMessage = null;

  if (userMessageId) {
    const row = await fetchTargetUserMessage(supabase, studentId, userMessageId);
    messagesBeforeCreatedAt = row.created_at;
    if (row.linked_attempt_id) {
      linkedAttemptId = row.linked_attempt_id;
    }

    let replyTo: CoachReplyTargetMessage["reply_to"] | null = null;
    if (row.reply_to_message_id) {
      const replyRow = await fetchThreadMessage(supabase, studentId, row.reply_to_message_id);
      if (replyRow) {
        replyTo = {
          id: replyRow.id,
          role: replyRow.role,
          text: extractText(replyRow.content),
        };
      }
    }

    target = { id: row.id, text: extractText(row.content), reply_to: replyTo };
  }

  const context = await buildCoachContext({
    supabase,
    studentId,
    linkedAttemptId,
    messagesBeforeCreatedAt,
    includeMessages: true,
    includeReports: true,
    includeInsights: true,
    includeSnapshot: true,
  });

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
    const prompt = buildCoachReplyPrompt(context, target);
    log?.recordPrompt?.(prompt);

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
