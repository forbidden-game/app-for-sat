import { maskPII, serializeJson } from "./ai-log-utils";
import type { AiAgentLog } from "./actions";

export const CONTEXT_KEYS = [
  "studentSnapshot",
  "attemptContext",
  "recentPerformance",
  "curriculumState",
] as const;

export type ContextKey = (typeof CONTEXT_KEYS)[number];

export type PromptPack = {
  system_prompt: string;
  prompts: unknown;
  model: string;
  prompt_version: string;
};

export type ContextEntry = {
  key: ContextKey;
  title: string;
  data: unknown;
  source?: string;
  timestamp?: string;
};

type ProvenanceEntry = {
  label: string;
  timestamp?: string;
  raw: unknown;
};

export type ProvenanceMap = Record<string, ProvenanceEntry[]>;

const CONTEXT_CANDIDATES: Record<ContextKey, string[]> = {
  studentSnapshot: ["student_snapshot", "studentSnapshot", "snapshot"],
  attemptContext: ["attempt_context", "attemptContext"],
  recentPerformance: ["recent_performance", "recentPerformance", "performance"],
  curriculumState: ["curriculum_state", "curriculumState"],
};

const PROVENANCE_KEYS = [
  "provenance",
  "prompt_provenance",
  "promptProvenance",
  "sources",
  "source_map",
  "sourceMap",
];

export const CONTEXT_LABELS: Record<ContextKey, string> = {
  studentSnapshot: "Student Snapshot",
  attemptContext: "Attempt Context",
  recentPerformance: "Recent Performance",
  curriculumState: "Curriculum State",
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function getCandidate(record: Record<string, unknown>, keys: string[]) {
  for (const key of keys) {
    if (key in record) return record[key];
  }
  return undefined;
}

function getSourceLabel(value: unknown) {
  if (!isRecord(value)) return undefined;
  const candidate =
    value.source ??
    value.source_label ??
    value.sourceLabel ??
    value.origin ??
    value.provider ??
    value.table ??
    value.collection;
  return typeof candidate === "string" ? candidate : undefined;
}

function getTimestamp(value: unknown) {
  if (!isRecord(value)) return undefined;
  const candidate =
    value.captured_at ?? value.logged_at ?? value.timestamp ?? value.created_at ?? value.updated_at;
  return typeof candidate === "string" ? candidate : undefined;
}

function unwrapData(value: unknown) {
  if (!isRecord(value)) return value;
  if ("data" in value) return value.data;
  return value;
}

export function buildPromptPack(log: AiAgentLog): PromptPack {
  return {
    system_prompt: log.system_prompt ?? "",
    prompts: log.prompts ?? [],
    model: `${log.model_provider}/${log.model_id}`,
    prompt_version: log.prompt_version ?? "—",
  };
}

export function stringifyWithMask(value: unknown, maskEnabled: boolean) {
  const text = typeof value === "string" ? value : serializeJson(value, 2);
  return maskEnabled ? maskPII(text) : text;
}

export function formatPlain(value: string, maskEnabled: boolean) {
  return maskEnabled ? maskPII(value) : value;
}

export function extractContextStack(events: unknown): ContextEntry[] {
  if (!Array.isArray(events)) return [];
  const output: Partial<Record<ContextKey, ContextEntry>> = {};

  for (const event of events) {
    if (!isRecord(event)) continue;
    const stack = getCandidate(event, ["context_stack", "contextStack", "context"]);

    if (isRecord(stack)) {
      for (const key of CONTEXT_KEYS) {
        if (output[key]) continue;
        const raw = getCandidate(stack, CONTEXT_CANDIDATES[key]);
        if (raw !== undefined) {
          output[key] = {
            key,
            title: CONTEXT_LABELS[key],
            data: unwrapData(raw),
            source: getSourceLabel(raw) ?? getSourceLabel(stack) ?? getSourceLabel(event),
            timestamp: getTimestamp(raw) ?? getTimestamp(stack) ?? getTimestamp(event),
          };
        }
      }
    }

    for (const key of CONTEXT_KEYS) {
      if (output[key]) continue;
      const raw = getCandidate(event, CONTEXT_CANDIDATES[key]);
      if (raw !== undefined) {
        output[key] = {
          key,
          title: CONTEXT_LABELS[key],
          data: unwrapData(raw),
          source: getSourceLabel(raw) ?? getSourceLabel(event),
          timestamp: getTimestamp(raw) ?? getTimestamp(event),
        };
      }
    }
  }

  return CONTEXT_KEYS.map((key) => output[key]).filter(Boolean) as ContextEntry[];
}

function normalizeProvenanceItem(value: unknown, fallbackLabel: string): ProvenanceEntry {
  if (typeof value === "string") {
    return { label: value, raw: value };
  }
  if (!isRecord(value)) {
    return { label: fallbackLabel, raw: value };
  }
  const label =
    (typeof value.label === "string" && value.label) ||
    (typeof value.source === "string" && value.source) ||
    (typeof value.table === "string" && value.table) ||
    (typeof value.collection === "string" && value.collection) ||
    fallbackLabel;
  return {
    label,
    timestamp: getTimestamp(value),
    raw: value,
  };
}

function appendProvenance(map: ProvenanceMap, key: string, entry: ProvenanceEntry) {
  if (!map[key]) map[key] = [];
  map[key].push(entry);
}

export function extractProvenance(events: unknown): ProvenanceMap {
  if (!Array.isArray(events)) return {};
  const map: ProvenanceMap = {};

  for (const event of events) {
    if (!isRecord(event)) continue;
    for (const key of PROVENANCE_KEYS) {
      const candidate = event[key];
      if (!candidate) continue;
      if (Array.isArray(candidate)) {
        for (const entry of candidate) {
          appendProvenance(map, key, normalizeProvenanceItem(entry, key));
        }
      } else if (isRecord(candidate)) {
        for (const [subKey, value] of Object.entries(candidate)) {
          if (Array.isArray(value)) {
            for (const item of value) {
              appendProvenance(map, subKey, normalizeProvenanceItem(item, subKey));
            }
          } else {
            appendProvenance(map, subKey, normalizeProvenanceItem(value, subKey));
          }
        }
      } else {
        appendProvenance(map, key, normalizeProvenanceItem(candidate, key));
      }
    }
  }

  return map;
}

export function diffLines(currentText: string, previousText: string) {
  const currentLines = currentText.split("\n");
  const previousLines = previousText.split("\n");
  const maxLength = Math.max(currentLines.length, previousLines.length);
  const rows = [] as Array<{ current: string; previous: string; changed: boolean }>;

  for (let index = 0; index < maxLength; index += 1) {
    const current = currentLines[index] ?? "";
    const previous = previousLines[index] ?? "";
    rows.push({
      current,
      previous,
      changed: current !== previous,
    });
  }

  return rows;
}

export function parseOverride(value: string) {
  if (!value.trim()) return { value: null, error: null };
  try {
    return { value: JSON.parse(value), error: null };
  } catch {
    return { value: null, error: "Invalid JSON" };
  }
}
