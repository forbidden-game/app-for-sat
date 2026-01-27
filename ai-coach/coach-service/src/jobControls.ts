import type { SupabaseClient } from "@supabase/supabase-js";

import type { AiJobKind } from "./types.js";

const ALL_JOB_KINDS: AiJobKind[] = [
  "attempt_insight",
  "thread_summary",
  "procedure_merge",
  "coach_reply",
  "snapshot_refresh",
  "progress_report",
  "english_grammar_analysis",
];

type JobControl = {
  allow_enqueue: boolean;
  allow_process: boolean;
};

type JobControlMap = Partial<Record<AiJobKind, JobControl>>;

const CACHE_TTL_MS = 60_000;
let cachedAt = 0;
let cachedControls: JobControlMap | null = null;

function isAiJobKind(value: string): value is AiJobKind {
  return ALL_JOB_KINDS.includes(value as AiJobKind);
}

export async function getAiJobControls(
  supabase: SupabaseClient,
): Promise<JobControlMap | null> {
  if (cachedControls && Date.now() - cachedAt < CACHE_TTL_MS) {
    return cachedControls;
  }

  const { data, error } = await supabase
    .from("ai_job_controls")
    .select("kind, allow_enqueue, allow_process");

  if (error) {
    return cachedControls;
  }

  const controls: JobControlMap = {};
  for (const row of data ?? []) {
    const kind = row.kind as string;
    if (!kind || !isAiJobKind(kind)) continue;
    controls[kind] = {
      allow_enqueue: Boolean(row.allow_enqueue),
      allow_process: Boolean(row.allow_process),
    };
  }

  cachedControls = controls;
  cachedAt = Date.now();

  return cachedControls;
}

export function isEnqueueEnabled(kind: AiJobKind, controls: JobControlMap | null): boolean {
  return controls?.[kind]?.allow_enqueue ?? true;
}

export function isProcessEnabled(kind: AiJobKind, controls: JobControlMap | null): boolean {
  return controls?.[kind]?.allow_process ?? true;
}

export async function getAllowedProcessKinds(
  supabase: SupabaseClient,
  requestedKinds: AiJobKind[] | null,
): Promise<AiJobKind[] | null> {
  const controls = await getAiJobControls(supabase);
  if (!controls) {
    return requestedKinds;
  }

  const baseList = requestedKinds ?? ALL_JOB_KINDS;
  const allowed = baseList.filter((kind) => isProcessEnabled(kind, controls));
  return allowed;
}

