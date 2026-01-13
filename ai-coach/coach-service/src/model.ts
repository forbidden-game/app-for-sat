import { getModel, type KnownProvider, type Model } from "@mariozechner/pi-ai";

export type ModelSpec = {
  provider: KnownProvider;
  modelId: string;
};

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

export function resolveModel(spec: string, fallbackProvider: KnownProvider = "minimax"): Model<any> {
  const parsed = parseModelSpec(spec, fallbackProvider);
  const model = getModel(parsed.provider, parsed.modelId as any);
  if (!model) {
    throw new Error(`Unknown model: ${parsed.provider}/${parsed.modelId}`);
  }
  return model;
}
