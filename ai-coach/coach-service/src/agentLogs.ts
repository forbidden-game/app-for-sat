import type { Agent, AgentEvent } from "@mariozechner/pi-agent-core";
import type { Model } from "@mariozechner/pi-ai";
import type { SupabaseClient } from "@supabase/supabase-js";

import { logger } from "./logger.js";
import type { AiJobRow } from "./types.js";

export type AgentLogSession = {
  attach: (agent: Agent) => void;
  detach: () => void;
  recordPrompt: (prompt: string) => void;
  flush: (supabase: SupabaseClient, status: "done" | "error", err?: unknown) => Promise<void>;
  hasData: () => boolean;
};

type AgentLogMeta = {
  job: Pick<AiJobRow, "id" | "kind" | "student_id" | "attempt_id">;
  model: Model<any>;
  promptVersion: string | null;
  systemPrompt: string | null;
};

function serializeEvent(event: AgentEvent): Record<string, unknown> {
  const safe = JSON.parse(JSON.stringify(event)) as Record<string, unknown>;
  safe.logged_at = new Date().toISOString();
  return safe;
}

export function createAgentLogSession(meta: AgentLogMeta): AgentLogSession {
  const events: Array<Record<string, unknown>> = [];
  const prompts: string[] = [];
  let unsubscribe: (() => void) | null = null;

  function attach(agent: Agent) {
    if (unsubscribe) return;
    unsubscribe = agent.subscribe((event) => {
      events.push(serializeEvent(event));
    });
  }

  function detach() {
    unsubscribe?.();
    unsubscribe = null;
  }

  function recordPrompt(prompt: string) {
    if (prompt.trim().length === 0) return;
    prompts.push(prompt);
  }

  function hasData() {
    return events.length > 0 || prompts.length > 0;
  }

  async function flush(
    supabase: SupabaseClient,
    status: "done" | "error",
    err?: unknown,
  ): Promise<void> {
    if (!hasData()) return;

    const errorMessage = err instanceof Error ? err.message : err ? String(err) : null;

    const { error } = await supabase.from("ai_agent_logs").insert({
      job_id: meta.job.id,
      kind: meta.job.kind,
      student_id: meta.job.student_id ?? null,
      attempt_id: meta.job.attempt_id ?? null,
      model_provider: meta.model.provider,
      model_id: meta.model.id,
      prompt_version: meta.promptVersion,
      system_prompt: meta.systemPrompt,
      prompts,
      events,
      status,
      error: errorMessage,
      created_at: new Date().toISOString(),
    });

    if (error) {
      logger.warn({ err: error }, "failed to write agent log");
    }
  }

  return { attach, detach, recordPrompt, flush, hasData };
}
