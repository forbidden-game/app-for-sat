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
  model_provider: AiProvider;
  model_id: string;
  notes?: string;
};

export type AiProvider = "minimax" | "openai" | "openrouter";

export type AiProviderKeyStatus = {
  provider: AiProvider;
  hasKey: boolean;
  last4: string | null;
  updatedAt: string | null;
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

  const archivePayload = {
    status: "archived",
    updated_at: now,
  } as unknown as never;
  const { error: archiveError } = await context.supabase
    .from("ai_prompt_configs")
    .update(archivePayload)
    .eq("kind", input.kind)
    .eq("status", "published");

  if (archiveError) {
    throw new Error("Failed to archive existing config.");
  }

  const insertPayload = {
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
  } as unknown as never;

  const { data, error } = await context.supabase
    .from("ai_prompt_configs")
    .insert(insertPayload)
    .select(
      "id, kind, prompt_version, system_prompt, model_provider, model_id, status, created_at, updated_at, published_at",
    )
    .single();

  if (error || !data) {
    throw new Error("Failed to publish AI prompt config.");
  }

  // Supabase table typings for ai_prompt_configs are missing, so cast the selected row.
  const publishedConfig = data as unknown as AiPromptConfig;

  await recordAdminEvent(context, {
    action: "ai_config.publish",
    resourceType: "ai_prompt_configs",
    resourceId: publishedConfig.id,
    metadata: {
      kind: input.kind,
      prompt_version: promptVersion,
      model_provider: input.model_provider,
      model_id: modelId,
    },
  });

  return publishedConfig;
}

export async function archiveAiPromptConfig(
  accessToken: string,
  configId: string,
): Promise<void> {
  const context = await requireAdmin(accessToken);
  const now = new Date().toISOString();

  const archivePayload = {
    status: "archived",
    updated_at: now,
  } as unknown as never;
  const { data, error } = await context.supabase
    .from("ai_prompt_configs")
    .update(archivePayload)
    .eq("id", configId)
    .select("id, kind")
    .single();

  if (error || !data) {
    throw new Error("Failed to archive AI prompt config.");
  }

  const archivedConfig = data as unknown as Pick<AiPromptConfig, "id" | "kind">;

  await recordAdminEvent(context, {
    action: "ai_config.archive",
    resourceType: "ai_prompt_configs",
    resourceId: archivedConfig.id,
    metadata: { kind: archivedConfig.kind },
  });
}

export async function getAiProviderKeyStatus(
  accessToken: string,
  provider: AiProvider,
): Promise<AiProviderKeyStatus> {
  const { supabase } = await requireAdmin(accessToken);

  const { data, error } = await supabase
    .from("ai_provider_keys")
    .select("api_key, updated_at")
    .eq("provider", provider)
    .maybeSingle();

  if (error) {
    throw new Error("Failed to load provider key status.");
  }

  const apiKey = (data?.api_key as string | undefined) ?? "";
  return {
    provider,
    hasKey: apiKey.length > 0,
    last4: apiKey.length >= 4 ? apiKey.slice(-4) : null,
    updatedAt: (data?.updated_at as string | null) ?? null,
  };
}

export async function upsertAiProviderKey(
  accessToken: string,
  provider: AiProvider,
  apiKey: string,
): Promise<AiProviderKeyStatus> {
  const context = await requireAdmin(accessToken);
  const now = new Date().toISOString();
  const trimmed = apiKey.trim();

  if (!trimmed) {
    throw new Error("API key is required.");
  }

  const { data: existing, error: lookupError } = await context.supabase
    .from("ai_provider_keys")
    .select("id")
    .eq("provider", provider)
    .maybeSingle();

  if (lookupError) {
    throw new Error("Failed to verify provider key.");
  }

  if (existing?.id) {
    const updatePayload = {
      api_key: trimmed,
      updated_at: now,
      updated_by: context.admin.id,
    } as unknown as never;
    const { error } = await context.supabase
      .from("ai_provider_keys")
      .update(updatePayload)
      .eq("id", existing.id);

    if (error) {
      throw new Error("Failed to update provider key.");
    }
  } else {
    const { error } = await context.supabase.from("ai_provider_keys").insert({
      provider,
      api_key: trimmed,
      created_at: now,
      updated_at: now,
      created_by: context.admin.id,
      updated_by: context.admin.id,
    });

    if (error) {
      throw new Error("Failed to save provider key.");
    }
  }

  await recordAdminEvent(context, {
    action: "ai_provider_key.upsert",
    resourceType: "ai_provider_keys",
    resourceId: provider,
    metadata: { provider },
  });

  return {
    provider,
    hasKey: true,
    last4: trimmed.slice(-4),
    updatedAt: now,
  };
}
