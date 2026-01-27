import type { AiPromptKind } from "../aiConfig.js";
import { buildModelSpec } from "../aiConfig.js";
import type { AiJobRow } from "../types.js";

export const DEFAULT_SYSTEM_PROMPTS: Record<AiPromptKind, string> = {
  attempt_insight:
    "You are a strict, concise SAT tutor. Prefer short, step-by-step guidance and ask questions instead of long explanations.",
  coach_reply:
    "你是一位严格、精要的 SAT 全科老师。默认用中文，先给最小可执行下一步，再问一个澄清问题。避免长篇大论。",
  progress_report: "你是严格、精要的 SAT 一对一老师，只输出 JSON。",
  english_grammar_analysis:
    "You are an expert English grammar analyst. Output only valid JSON per the schema.",
};

export const DEFAULT_PROMPT_VERSIONS: Record<AiPromptKind, string> = {
  attempt_insight: "ai-coach-insight-v2",
  coach_reply: "ai-coach-chat-v2",
  progress_report: "ai-coach-report-v1",
  english_grammar_analysis: "english-grammar-v2",
};

export type PromptOverrides = {
  systemPrompt: string;
  promptVersion: string;
  modelSpec: string | null;
};

export function resolvePromptOverrides(
  kind: AiJobRow["kind"],
  configs: Partial<
    Record<
      AiPromptKind,
      { systemPrompt: string; promptVersion: string; modelProvider: string; modelId: string }
    >
  > | null,
): PromptOverrides | null {
  if (
    kind !== "attempt_insight" &&
    kind !== "coach_reply" &&
    kind !== "progress_report" &&
    kind !== "english_grammar_analysis"
  ) {
    return null;
  }

  const config = configs?.[kind];

  return {
    systemPrompt: config?.systemPrompt ?? DEFAULT_SYSTEM_PROMPTS[kind],
    promptVersion: config?.promptVersion ?? DEFAULT_PROMPT_VERSIONS[kind],
    modelSpec: buildModelSpec(config ?? null),
  };
}
