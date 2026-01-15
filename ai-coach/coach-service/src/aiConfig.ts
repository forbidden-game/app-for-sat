import type { SupabaseClient } from "@supabase/supabase-js";

export type AiPromptKind = "attempt_insight" | "coach_reply" | "progress_report";

export type AiPromptConfig = {
  id: string;
  kind: AiPromptKind;
  promptVersion: string;
  systemPrompt: string;
  modelProvider: string;
  modelId: string;
  status: "draft" | "published" | "archived";
  updatedAt: string | null;
};

const CACHE_TTL_MS = 60_000;
let cachedAt = 0;
let cachedConfigs: Partial<Record<AiPromptKind, AiPromptConfig>> | null = null;

function isAiPromptKind(value: string): value is AiPromptKind {
  return value === "attempt_insight" || value === "coach_reply" || value === "progress_report";
}

export async function getPublishedAiPromptConfigs(
  supabase: SupabaseClient,
): Promise<Partial<Record<AiPromptKind, AiPromptConfig>> | null> {
  if (cachedConfigs && Date.now() - cachedAt < CACHE_TTL_MS) {
    return cachedConfigs;
  }

  const { data, error } = await supabase
    .from("ai_prompt_configs")
    .select(
      "id, kind, prompt_version, system_prompt, model_provider, model_id, status, updated_at",
    )
    .eq("status", "published");

  if (error) {
    return cachedConfigs;
  }

  const configs: Partial<Record<AiPromptKind, AiPromptConfig>> = {};

  for (const row of data ?? []) {
    if (!row || typeof row.kind !== "string" || !isAiPromptKind(row.kind)) continue;
    configs[row.kind] = {
      id: row.id as string,
      kind: row.kind as AiPromptKind,
      promptVersion: (row.prompt_version as string) ?? "",
      systemPrompt: (row.system_prompt as string) ?? "",
      modelProvider: (row.model_provider as string) ?? "",
      modelId: (row.model_id as string) ?? "",
      status: (row.status as AiPromptConfig["status"]) ?? "published",
      updatedAt: (row.updated_at as string) ?? null,
    };
  }

  cachedConfigs = configs;
  cachedAt = Date.now();

  return cachedConfigs;
}

export function buildModelSpec(
  config: Pick<AiPromptConfig, "modelProvider" | "modelId"> | null,
): string | null {
  if (!config?.modelProvider || !config.modelId) return null;
  return `${config.modelProvider}/${config.modelId}`;
}
