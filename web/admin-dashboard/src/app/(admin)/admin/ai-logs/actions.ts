"use server";

import "server-only";
import { requireAdmin } from "@/lib/adminAuth";

export type AiAgentLog = {
  id: string;
  job_id: string | null;
  kind: string;
  student_id: string | null;
  attempt_id: string | null;
  model_provider: string;
  model_id: string;
  prompt_version: string | null;
  system_prompt: string | null;
  prompts: unknown;
  events: unknown;
  status: "done" | "error";
  error: string | null;
  created_at: string;
};

export async function listAiAgentLogs(
  accessToken: string,
  limit: number = 200,
): Promise<AiAgentLog[]> {
  const { supabase } = await requireAdmin(accessToken);

  const { data, error } = await supabase
    .from("ai_agent_logs")
    .select(
      "id, job_id, kind, student_id, attempt_id, model_provider, model_id, prompt_version, system_prompt, prompts, events, status, error, created_at",
    )
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) {
    throw new Error("Failed to load agent logs.");
  }

  return (data ?? []) as AiAgentLog[];
}
