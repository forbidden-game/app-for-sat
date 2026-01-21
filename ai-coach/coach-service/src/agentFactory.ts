import { Agent } from "@mariozechner/pi-agent-core";
import { getEnvApiKey, type Model } from "@mariozechner/pi-ai";
import type { SupabaseClient } from "@supabase/supabase-js";

import type { CoachConfig } from "./config.js";
import { applyMinimaxAuth, resolveModel } from "./model.js";
import type { AiJobRow } from "./types.js";
import { buildCoachTools, type CoachToolOptions } from "./tools/coachTools.js";
import { DEFAULT_PROMPT_VERSIONS, DEFAULT_SYSTEM_PROMPTS } from "./prompts/promptOverrides.js";

const modelCache = new Map<string, Model<any>>();

export function modelForSpec(spec: string): Model<any> {
  const cached = modelCache.get(spec);
  if (cached) return cached;
  const model = resolveModel(spec, "minimax");
  modelCache.set(spec, model);
  return model;
}

export function resolveJobModel(config: CoachConfig, kind: AiJobRow["kind"]): Model<any> {
  if (kind === "attempt_insight") return modelForSpec(config.modelInsight);
  if (kind === "coach_reply") return modelForSpec(config.modelChat);
  if (kind === "progress_report") return modelForSpec(config.modelReport);
  return modelForSpec(config.modelDefault);
}

type CoachToolOverrides = Omit<CoachToolOptions, "modelId" | "promptVersion">;

export function createCoachAgent(
  config: CoachConfig,
  supabase: SupabaseClient,
  model: Model<any>,
  systemPrompt?: string,
  promptVersion?: string,
  toolOverrides?: CoachToolOverrides,
  apiKeyResolver?: (provider: string) => Promise<string | undefined> | string | undefined,
): Agent {
  const tools = buildCoachTools(supabase, {
    modelId: model.id,
    promptVersion: promptVersion ?? DEFAULT_PROMPT_VERSIONS.attempt_insight,
    ...toolOverrides,
  });

  return new Agent({
    initialState: {
      systemPrompt: systemPrompt ?? DEFAULT_SYSTEM_PROMPTS.attempt_insight,
      model,
      thinkingLevel: "off",
      tools,
      messages: [],
    },
    getApiKey: apiKeyResolver
      ? apiKeyResolver
      : async (provider) => (provider === "minimax" ? config.minimaxApiKey ?? undefined : getEnvApiKey(provider)),
  });
}

export function createChatAgent(
  config: CoachConfig,
  model: Model<any>,
  systemPrompt?: string,
  apiKeyResolver?: (provider: string) => Promise<string | undefined> | string | undefined,
): Agent {
  return new Agent({
    initialState: {
      systemPrompt: systemPrompt ?? DEFAULT_SYSTEM_PROMPTS.coach_reply,
      model,
      thinkingLevel: "off",
      tools: [],
      messages: [],
    },
    getApiKey: apiKeyResolver
      ? apiKeyResolver
      : async (provider) => (provider === "minimax" ? config.minimaxApiKey ?? undefined : getEnvApiKey(provider)),
  });
}

export function applyProviderAuth(model: Model<any>, providerKey?: string | null): Model<any> {
  if (model.provider === "minimax") {
    return applyMinimaxAuth(model, providerKey ?? undefined);
  }
  return model;
}
