export type GrammarSentenceInput = {
  sentence_index: number;
  source: "passage" | "prompt";
  text: string;
};

type EnglishGrammarPromptParams = {
  sentences: GrammarSentenceInput[];
  language: "bilingual";
};

export function buildEnglishGrammarPrompt(params: EnglishGrammarPromptParams): string {
  const sentencesJson = JSON.stringify(params.sentences, null, 2);

  return [
    "You are an expert English grammar analyst for SAT reading.",
    "Analyze each sentence and return a strict JSON object only.",
    "All text spans must use UTF-16 indices within sentence.text (start inclusive, end exclusive).",
    "Provide bilingual labels and explanations in English and Chinese.",
    "Do not include markdown fences.",
    "",
    "Output schema:",
    "{",
    "  \"sentences\": [",
    "    {",
    "      \"sentence_index\": number,",
    "      \"components\": [",
    "        {",
    "          \"id\": string,",
    "          \"type\": string,",
    "          \"start\": number,",
    "          \"end\": number,",
    "          \"label_en\": string,",
    "          \"label_zh\": string,",
    "          \"explanation_en\": string,",
    "          \"explanation_zh\": string",
    "        }",
    "      ]",
    "    }",
    "  ],",
    "  \"important_words\": [",
    "    {",
    "      \"word\": string,",
    "      \"lemma\": string,",
    "      \"pos\": string,",
    "      \"meaning_en\": string,",
    "      \"meaning_zh\": string,",
    "      \"why_en\": string,",
    "      \"why_zh\": string",
    "    }",
    "  ]",
    "}",
    "",
    "Components should cover clause structure, subject/predicate, objects, modifiers, phrases, and key grammar roles.",
    "Use concise explanations (1-2 sentences).",
    "",
    "Sentences:",
    sentencesJson,
  ].join("\n");
}
