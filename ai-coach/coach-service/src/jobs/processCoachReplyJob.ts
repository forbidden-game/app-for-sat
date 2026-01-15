import type { Agent } from "@mariozechner/pi-agent-core";
import type { SupabaseClient } from "@supabase/supabase-js";

import { buildCoachContext } from "../context/coachContext.js";
import { logger } from "../logger.js";
import type { AiJobRow } from "../types.js";
import { buildCoachReplyPrompt } from "../prompts/coachReplyPrompt.js";

type CoachContent = {
  text?: string;
  status?: "streaming" | "done" | "error";
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

export async function processCoachReplyJob(
  supabase: SupabaseClient,
  agent: Agent,
  job: AiJobRow,
): Promise<void> {
  if (!job.student_id) throw new Error("missing student_id");
  const studentId = job.student_id;

  const payload = (job.payload ?? {}) as any;
  const linkedAttemptId = typeof payload.linked_attempt_id === "string" ? payload.linked_attempt_id : null;

  const context = await buildCoachContext({
    supabase,
    studentId,
    linkedAttemptId,
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
    const prompt = buildCoachReplyPrompt(context);

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
