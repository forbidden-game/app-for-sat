"use server";

import "server-only";
import { requireAdmin } from "@/lib/adminAuth";
import { recordAdminEvent } from "@/lib/adminAudit";

export type AiPromptKind = "attempt_insight" | "coach_reply" | "progress_report";

export type AiPromptConfig = {
  id: string;
  kind: AiPromptKind;
  prompt_version: string;
  system_prompt: string;
  model_provider: string;
  model_id: string;
  status: "draft" | "published" | "archived";
  created_at: string;
  updated_at: string | null;
  published_at: string | null;
};

export type AiPromptConfigInput = {
  kind: AiPromptKind;
  prompt_version: string;
  system_prompt: string;
  model_provider: "minimax" | "openai";
  model_id: string;
  notes?: string;
};

export async function listAiPromptConfigs(accessToken: string): Promise<AiPromptConfig[]> {
  const { supabase } = await requireAdmin(accessToken);

  const { data, error } = await supabase
    .from("ai_prompt_configs")
    .select(
      "id, kind, prompt_version, system_prompt, model_provider, model_id, status, created_at, updated_at, published_at",
    )
    .order("created_at", { ascending: false });

  if (error) {
    throw new Error("Failed to load AI prompt configs.");
  }

  return (data ?? []) as AiPromptConfig[];
}

export async function publishAiPromptConfig(
  accessToken: string,
  input: AiPromptConfigInput,
): Promise<AiPromptConfig> {
  const context = await requireAdmin(accessToken);
  const now = new Date().toISOString();

  const promptVersion = input.prompt_version.trim();
  const systemPrompt = input.system_prompt.trim();
  const modelId = input.model_id.trim();

  if (!promptVersion || !systemPrompt || !modelId) {
    throw new Error("Prompt version, system prompt, and model are required.");
  }

  const { error: archiveError } = await context.supabase
    .from("ai_prompt_configs")
    .update({ status: "archived", updated_at: now })
    .eq("kind", input.kind)
    .eq("status", "published");

  if (archiveError) {
    throw new Error("Failed to archive existing config.");
  }

  const { data, error } = await context.supabase
    .from("ai_prompt_configs")
    .insert({
      kind: input.kind,
      prompt_version: promptVersion,
      system_prompt: systemPrompt,
      model_provider: input.model_provider,
      model_id: modelId,
      status: "published",
      notes: input.notes ?? null,
      created_by: context.admin.id,
      created_at: now,
      updated_at: now,
      published_at: now,
    })
    .select(
      "id, kind, prompt_version, system_prompt, model_provider, model_id, status, created_at, updated_at, published_at",
    )
    .single();

  if (error || !data) {
    throw new Error("Failed to publish AI prompt config.");
  }

  await recordAdminEvent(context, {
    action: "ai_config.publish",
    resourceType: "ai_prompt_configs",
    resourceId: data.id,
    metadata: {
      kind: input.kind,
      prompt_version: promptVersion,
      model_provider: input.model_provider,
      model_id: modelId,
    },
  });

  return data as AiPromptConfig;
}

export async function archiveAiPromptConfig(
  accessToken: string,
  configId: string,
): Promise<void> {
  const context = await requireAdmin(accessToken);
  const now = new Date().toISOString();

  const { data, error } = await context.supabase
    .from("ai_prompt_configs")
    .update({ status: "archived", updated_at: now })
    .eq("id", configId)
    .select("id, kind")
    .single();

  if (error || !data) {
    throw new Error("Failed to archive AI prompt config.");
  }

  await recordAdminEvent(context, {
    action: "ai_config.archive",
    resourceType: "ai_prompt_configs",
    resourceId: data.id,
    metadata: { kind: data.kind },
  });
}
