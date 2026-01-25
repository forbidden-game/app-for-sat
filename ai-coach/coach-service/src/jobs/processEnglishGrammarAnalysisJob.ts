import { createHash } from "node:crypto";
import type { Agent } from "@mariozechner/pi-agent-core";
import type { SupabaseClient } from "@supabase/supabase-js";

import { buildEnglishGrammarPrompt, type GrammarSentenceInput } from "../prompts/englishGrammarPrompt.js";
import { logger } from "../logger.js";
import type { AiJobRow } from "../types.js";

export const ENGLISH_GRAMMAR_PROMPT_VERSION = "english-grammar-v1";
const CHUNK_SIZE = 6;
const CHUNK_OVERLAP = 1;
const MAX_IMPORTANT_WORDS = 20;

type GrammarComponent = {
  id: string;
  type: string;
  start: number;
  end: number;
  label_en: string;
  label_zh: string;
  explanation_en?: string;
  explanation_zh?: string;
};

type SentenceResult = {
  sentence_index: number;
  components?: GrammarComponent[];
};

type ImportantWord = {
  word: string;
  lemma?: string;
  pos?: string;
  meaning_en?: string;
  meaning_zh?: string;
  why_en?: string;
  why_zh?: string;
};

type ChunkResult = {
  sentences?: SentenceResult[];
  important_words?: ImportantWord[];
};

type QuestionRow = {
  id: string;
  subject: string | null;
  stem: string;
};

type AnalysisSentence = {
  sentence_index: number;
  source: "passage" | "prompt";
  text: string;
  components: GrammarComponent[];
};

type AnalysisResult = {
  question_id: string;
  text_hash: string;
  prompt_version: string;
  language: "bilingual";
  passage: string | null;
  prompt: string;
  sentences: AnalysisSentence[];
  important_words: ImportantWord[];
};

export type EnglishGrammarAnalysisLogSink = {
  recordPrompt?: (prompt: string) => void;
};

function normalizeWhitespace(text: string): string {
  return text.replace(/\s+/g, " ").trim();
}

function derivePromptAndPassage(stem: string): { prompt: string; passage: string | null } {
  const trimmed = stem.trim();
  if (!trimmed) {
    return { prompt: "", passage: null };
  }

  const promptEndIndex = preferredPromptEndIndex(trimmed);
  const endIndex = promptEndIndex >= 0 ? promptEndIndex : trimmed.length - 1;
  const startIndex = sentenceStartIndex(trimmed, endIndex);

  const promptRaw = trimmed.slice(startIndex, endIndex + 1);
  const prompt = normalizeWhitespace(promptRaw);
  const passageRaw = trimmed.slice(0, startIndex).trim();
  const passage = passageRaw.length > 0 ? passageRaw : null;

  return { prompt, passage };
}

function sentenceStartIndex(text: string, endIndex: number): number {
  for (let index = endIndex; index > 0; index -= 1) {
    const prev = text[index - 1];
    if (prev === "." || prev === "!" || prev === "?" || prev === "\n") {
      return index;
    }
  }
  return 0;
}

function preferredPromptEndIndex(text: string): number {
  const q = text.lastIndexOf("?");
  if (q >= 0) return q;
  const ex = text.lastIndexOf("!");
  if (ex >= 0) return ex;
  return text.lastIndexOf(".");
}

function splitSentences(text: string): string[] {
  const normalized = normalizeWhitespace(text);
  if (!normalized) return [];
  const parts = normalized.split(/(?<=[.!?])\s+/g);
  return parts.map((part) => part.trim()).filter((part) => part.length > 0);
}

function chunkSentences<T>(sentences: T[], size: number, overlap: number): T[][] {
  const chunks: T[][] = [];
  if (sentences.length === 0) return chunks;

  for (let start = 0; start < sentences.length; start += size) {
    const sliceStart = Math.max(0, start - (start === 0 ? 0 : overlap));
    const sliceEnd = Math.min(sentences.length, start + size);
    chunks.push(sentences.slice(sliceStart, sliceEnd));
  }

  return chunks;
}

function stripJsonFence(text: string): string {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fenced && fenced[1]) return fenced[1].trim();
  return text.trim();
}

function sanitizeComponents(text: string, components: GrammarComponent[]): GrammarComponent[] {
  const length = text.length;
  return components
    .filter((component) => {
      if (!component) return false;
      if (typeof component.start !== "number" || typeof component.end !== "number") return false;
      if (component.start < 0 || component.end > length || component.end <= component.start) return false;
      return true;
    })
    .map((component, index) => {
      const id = component.id?.length ? component.id : `span-${index}-${component.start}-${component.end}`;
      return { ...component, id };
    });
}

function mergeImportantWords(
  existing: Map<string, ImportantWord>,
  incoming: ImportantWord[] | undefined,
): void {
  if (!incoming) return;
  for (const word of incoming) {
    if (!word?.word) continue;
    const key = (word.lemma || word.word).toLowerCase();
    if (!existing.has(key)) {
      existing.set(key, word);
    }
  }
}

function finalizeImportantWords(wordMap: Map<string, ImportantWord>): ImportantWord[] {
  return Array.from(wordMap.values()).slice(0, MAX_IMPORTANT_WORDS);
}

async function collectAgentText(agent: Agent, prompt: string): Promise<string> {
  let buffer = "";
  const unsubscribe = agent.subscribe((event) => {
    if (event.type !== "message_update") return;
    const message = (event as any).assistantMessageEvent;
    if (!message || message.type !== "text_delta") return;
    const delta = message.delta;
    if (typeof delta !== "string" || delta.length === 0) return;
    buffer += delta;
  });

  try {
    await agent.prompt(prompt);
  } finally {
    unsubscribe();
  }

  return buffer.trim();
}

async function updateAnalysisRow(
  supabase: SupabaseClient,
  params: {
    questionId: string;
    textHash: string;
    promptVersion: string;
    status: "queued" | "running" | "done" | "error";
    result?: AnalysisResult | null;
    error?: string | null;
    model?: string | null;
    costUsd?: number | null;
  },
): Promise<void> {
  const { error } = await supabase
    .from("english_grammar_analyses")
    .upsert(
      {
        question_id: params.questionId,
        text_hash: params.textHash,
        prompt_version: params.promptVersion,
        status: params.status,
        result: params.result ?? null,
        error: params.error ?? null,
        model: params.model ?? null,
        cost_usd: params.costUsd ?? null,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "question_id,text_hash,prompt_version" },
    );

  if (error) throw new Error(error.message);
}

export async function processEnglishGrammarAnalysisJob(
  supabase: SupabaseClient,
  agent: Agent,
  job: AiJobRow,
  log?: EnglishGrammarAnalysisLogSink,
  modelLabel?: string,
): Promise<void> {
  const payload = (job.payload ?? {}) as Record<string, unknown>;
  const questionId = typeof payload.question_id === "string" ? payload.question_id : null;
  const promptVersion =
    typeof payload.prompt_version === "string" && payload.prompt_version.length > 0
      ? payload.prompt_version
      : ENGLISH_GRAMMAR_PROMPT_VERSION;

  if (!questionId) throw new Error("missing question_id");

  const { data: questionRow, error: questionError } = await supabase
    .from("questions")
    .select("id, subject, stem")
    .eq("id", questionId)
    .single();

  if (questionError || !questionRow) {
    throw new Error(questionError?.message ?? "question_not_found");
  }

  const question = questionRow as QuestionRow;
  if (question.subject !== "reading") {
    await updateAnalysisRow(supabase, {
      questionId,
      textHash: "unsupported",
      promptVersion,
      status: "error",
      error: "unsupported_subject",
    });
    return;
  }

  const { prompt, passage } = derivePromptAndPassage(question.stem);
  const textHash = hashText(question.stem);

  const { data: existingRow } = await supabase
    .from("english_grammar_analyses")
    .select("status, result")
    .eq("question_id", questionId)
    .eq("text_hash", textHash)
    .eq("prompt_version", promptVersion)
    .maybeSingle();

  if ((existingRow as { status?: string } | null)?.status === "done") {
    return;
  }

  await updateAnalysisRow(supabase, {
    questionId,
    textHash,
    promptVersion,
    status: "running",
  });

  try {
    const sentenceInputs: GrammarSentenceInput[] = [];
    let sentenceIndex = 0;

    const passageSentences = passage ? splitSentences(passage) : [];
    for (const sentence of passageSentences) {
      sentenceInputs.push({ sentence_index: sentenceIndex, source: "passage", text: sentence });
      sentenceIndex += 1;
    }

    const promptSentences = splitSentences(prompt);
    for (const sentence of promptSentences) {
      sentenceInputs.push({ sentence_index: sentenceIndex, source: "prompt", text: sentence });
      sentenceIndex += 1;
    }

    if (sentenceInputs.length === 0) {
      throw new Error("no_sentence_inputs");
    }

    const chunks = chunkSentences(sentenceInputs, CHUNK_SIZE, CHUNK_OVERLAP);
    const sentenceMap = new Map<number, AnalysisSentence>();
    const wordMap = new Map<string, ImportantWord>();

    for (const chunk of chunks) {
      const promptText = buildEnglishGrammarPrompt({ sentences: chunk, language: "bilingual" });
      log?.recordPrompt?.(promptText);

      const responseText = await collectAgentText(agent, promptText);
      const cleaned = stripJsonFence(responseText);

      let parsed: ChunkResult;
      try {
        parsed = JSON.parse(cleaned) as ChunkResult;
      } catch (err) {
        logger.warn({ err, jobId: job.id }, "english grammar analysis json parse failed");
        throw new Error("english_grammar_invalid_json");
      }

      const sentenceResults = parsed.sentences ?? [];
      for (const result of sentenceResults) {
        if (typeof result?.sentence_index !== "number") continue;
        const input = sentenceInputs.find((item) => item.sentence_index === result.sentence_index);
        if (!input) continue;

        const sanitized = sanitizeComponents(input.text, result.components ?? []);
        const current = sentenceMap.get(result.sentence_index);
        const merged = current ? current.components.concat(sanitized) : sanitized;

        sentenceMap.set(result.sentence_index, {
          sentence_index: result.sentence_index,
          source: input.source,
          text: input.text,
          components: merged,
        });
      }

      mergeImportantWords(wordMap, parsed.important_words);
    }

    const sentences: AnalysisSentence[] = sentenceInputs.map((input) => {
      const stored = sentenceMap.get(input.sentence_index);
      return {
        sentence_index: input.sentence_index,
        source: input.source,
        text: input.text,
        components: stored?.components ?? [],
      };
    });

    const result: AnalysisResult = {
      question_id: questionId,
      text_hash: textHash,
      prompt_version: promptVersion,
      language: "bilingual",
      passage,
      prompt,
      sentences,
      important_words: finalizeImportantWords(wordMap),
    };

    await updateAnalysisRow(supabase, {
      questionId,
      textHash,
      promptVersion,
      status: "done",
      result,
      model: modelLabel ?? null,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    await updateAnalysisRow(supabase, {
      questionId,
      textHash,
      promptVersion,
      status: "error",
      error: message,
      model: modelLabel ?? null,
    });
    throw err;
  }
}

function hashText(text: string): string {
  const normalized = normalizeWhitespace(text);
  return normalized.length > 0 ? md5(normalized) : "";
}

function md5(input: string): string {
  return createHash("md5").update(input).digest("hex");
}
