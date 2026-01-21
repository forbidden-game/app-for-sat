import { getModel, type KnownProvider, type Model } from "@mariozechner/pi-ai";

export type ModelSpec = {
  provider: KnownProvider;
  modelId: string;
};

function getMinimaxBaseUrl(): string | undefined {
  const raw = process.env.MINIMAX_BASE_URL?.trim();
  return raw && raw.length > 0 ? raw : undefined;
}

export function parseModelSpec(spec: string, fallbackProvider: KnownProvider = "minimax"): ModelSpec {
  const trimmed = spec.trim();
  if (!trimmed) {
    return { provider: fallbackProvider, modelId: "MiniMax-M2.1" };
  }

  const parts = trimmed.split("/");
  if (parts.length >= 2) {
    const provider = parts[0] as KnownProvider;
    const modelId = parts.slice(1).join("/");
    return { provider, modelId };
  }

  return { provider: fallbackProvider, modelId: trimmed };
}

function cloneModel<T extends Model<any>>(model: T): T {
  return {
    ...model,
    cost: { ...model.cost },
    headers: model.headers ? { ...model.headers } : undefined,
  };
}

export function resolveModel(spec: string, fallbackProvider: KnownProvider = "minimax"): Model<any> {
  const parsed = parseModelSpec(spec, fallbackProvider);
  const model = (getModel as any)(parsed.provider, parsed.modelId) as Model<any>;
  if (!model) {
    throw new Error(`Unknown model: ${parsed.provider}/${parsed.modelId}`);
  }

  const resolved = cloneModel(model);
  const minimaxBaseUrl = getMinimaxBaseUrl();
  if (parsed.provider === "minimax" && minimaxBaseUrl) {
    resolved.baseUrl = minimaxBaseUrl;
  }
  return resolved;
}

export function applyMinimaxAuth<T extends Model<any>>(model: T, apiKey?: string | null): T {
  if (model.provider !== "minimax" || !apiKey) return model;

  const headers = {
    ...model.headers,
    Authorization: `Bearer ${apiKey}`,
  };

  return {
    ...model,
    headers,
    baseUrl: getMinimaxBaseUrl() ?? model.baseUrl,
  };
}
