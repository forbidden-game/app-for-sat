export type EnglishGrammarPromptParams = {
  text: string;
  language: "bilingual";
};

export function buildEnglishGrammarPrompt(params: EnglishGrammarPromptParams): string {
  const text = params.text.trim();

  return [
    "You are an expert English sentence simplifier for SAT reading.",
    "Given an English passage that may contain multiple sentences, do two tasks:",
    "1) Provide one core simple sentence capturing the main idea.",
    "2) Rewrite the passage into multiple simple sentences.",
    "Each sentence must be a single sentence in both Chinese and English.",
    "Use concise wording and keep the meaning faithful.",
    "Return a strict JSON object only. Do not include markdown fences.",
    "Do not add numbering or extra keys.",
    "",
    "Output schema:",
    "{",
    "  \"core_sentence\": {",
    "    \"zh\": string,",
    "    \"en\": string",
    "  },",
    "  \"simple_sentences\": [",
    "    {",
    "      \"zh\": string,",
    "      \"en\": string",
    "    }",
    "  ]",
    "}",
    "",
    "Text:",
    text,
  ].join("\n");
}
