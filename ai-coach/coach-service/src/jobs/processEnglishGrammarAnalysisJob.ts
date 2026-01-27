import { createHash } from "node:crypto";
import type { Agent } from "@mariozechner/pi-agent-core";
import type { SupabaseClient } from "@supabase/supabase-js";

import { buildEnglishGrammarPrompt } from "../prompts/englishGrammarPrompt.js";
import { logger } from "../logger.js";
import type { AiJobRow } from "../types.js";

export const ENGLISH_GRAMMAR_PROMPT_VERSION = "english-grammar-v2";
const MAX_RESPONSE_CHARS = 200_000;
const MAX_SIMPLE_SENTENCES = 30;

type QuestionRow = {
  id: string;
  subject: string | null;
  stem: string;
};

type SentencePair = {
  zh: string;
  en: string;
};

type AnalysisPayload = {
  core_sentence?: SentencePair;
  simple_sentences?: SentencePair[];
};

type AnalysisResult = {
  question_id: string;
  text_hash: string;
  prompt_version: string;
  language: "bilingual";
  core_sentence: SentencePair;
  simple_sentences: SentencePair[];
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

function stripJsonFence(text: string): string {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fenced && fenced[1]) return fenced[1].trim();
  return text.trim();
}

function normalizeSentencePair(pair: SentencePair | null | undefined): SentencePair | null {
  if (!pair) return null;
  const zh = typeof pair.zh === "string" ? pair.zh.trim() : "";
  const en = typeof pair.en === "string" ? pair.en.trim() : "";
  if (!zh && !en) return null;
  return { zh, en };
}

function requireBilingualPair(pair: SentencePair | null, errorCode: string): SentencePair {
  if (!pair || !pair.zh || !pair.en) {
    throw new Error(errorCode);
  }
  return pair;
}

function finalizeSimpleSentences(items: SentencePair[] | undefined): SentencePair[] {
  if (!items || items.length === 0) return [];
  const sanitized = items
    .map((item) => normalizeSentencePair(item))
    .filter((pair): pair is SentencePair => Boolean(pair && pair.zh && pair.en));

  return sanitized.slice(0, MAX_SIMPLE_SENTENCES);
}

async function collectAgentText(agent: Agent, prompt: string): Promise<string> {
  let buffer = "";
  let exceeded = false;
  const unsubscribe = agent.subscribe((event) => {
    if (event.type !== "message_update") return;
    const message = (event as any).assistantMessageEvent;
    if (!message || message.type !== "text_delta") return;
    const delta = message.delta;
    if (typeof delta !== "string" || delta.length === 0) return;
    if (exceeded) return;
    buffer += delta;
    if (buffer.length > MAX_RESPONSE_CHARS) {
      exceeded = true;
    }
  });

  try {
    await agent.prompt(prompt);
  } finally {
    unsubscribe();
  }

  if (exceeded) {
    throw new Error("english_grammar_response_too_large");
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
  const analysisText = normalizeWhitespace([passage, prompt].filter(Boolean).join(" "));
  const textHash = hashText(question.stem);

  if (!analysisText) {
    await updateAnalysisRow(supabase, {
      questionId,
      textHash,
      promptVersion,
      status: "error",
      error: "no_analysis_text",
    });
    return;
  }

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
    const promptText = buildEnglishGrammarPrompt({ text: analysisText, language: "bilingual" });
    log?.recordPrompt?.(promptText);

    const responseText = await collectAgentText(agent, promptText);
    const cleaned = stripJsonFence(responseText);

    let parsed: AnalysisPayload;
    try {
      parsed = JSON.parse(cleaned) as AnalysisPayload;
    } catch (err) {
      logger.warn({ err, jobId: job.id }, "english grammar analysis json parse failed");
      throw new Error("english_grammar_invalid_json");
    }

    const coreSentence = requireBilingualPair(
      normalizeSentencePair(parsed.core_sentence),
      "english_grammar_missing_core_sentence",
    );
    const simpleSentences = finalizeSimpleSentences(parsed.simple_sentences);

    const result: AnalysisResult = {
      question_id: questionId,
      text_hash: textHash,
      prompt_version: promptVersion,
      language: "bilingual",
      core_sentence: coreSentence,
      simple_sentences: simpleSentences,
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
