import type { Model } from "@mariozechner/pi-ai";

export function getMinimaxAnthropicModel(): Model<"anthropic-messages"> {
  return {
    id: "MiniMax-M2.1",
    name: "MiniMax M2.1 (Anthropic Compatible)",
    api: "anthropic-messages",
    provider: "minimax-anthropic",
    baseUrl: "https://api.minimaxi.com/anthropic",
    reasoning: false,
    input: ["text"],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: 200000,
    maxTokens: 8192,
  };
}
