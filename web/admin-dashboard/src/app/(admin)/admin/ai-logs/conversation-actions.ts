"use server";

import "server-only";

import { requireAdmin } from "@/lib/adminAuth";

import { estimateTokens } from "./ai-log-utils";

export type CoachThreadRole = "user" | "assistant" | "tool";

type CoachThreadMessageRow = {
  id: string;
  student_id: string;
  role: CoachThreadRole;
  content: unknown;
  created_at: string;
  linked_attempt_id: string | null;
  reply_to_message_id: string | null;
};

export type CoachThreadListItem = {
  student_id: string;
  display_name: string | null;
  last_message_at: string;
  last_message_role: CoachThreadRole;
  last_message_preview: string;
  last_message_status: "streaming" | "done" | "error" | null;
};

export type CoachThreadMessage = CoachThreadMessageRow;

export type CoachReplyLogMeta = {
  log_id: string;
  job_id: string;
  user_message_id: string;
  model_provider: string;
  model_id: string;
  prompt_version: string | null;
  status: "done" | "error";
  error: string | null;
  created_at: string;
  estimated_prompt_tokens: number;
};

export type CoachThreadDetail = {
  student: {
    id: string;
    display_name: string | null;
  };
  messages: CoachThreadMessage[];
  coachReplyLogsByUserMessageId: Record<string, CoachReplyLogMeta>;
};

export type CoachMessageSearchResult = {
  id: string;
  student_id: string;
  display_name: string | null;
  role: CoachThreadRole;
  created_at: string;
  linked_attempt_id: string | null;
  text_preview: string;
};

function extractText(content: unknown): string {
  if (!content || typeof content !== "object") return "";
  const maybeText = (content as { text?: unknown }).text;
  return typeof maybeText === "string" ? maybeText : "";
}

function extractStatus(content: unknown): "streaming" | "done" | "error" | null {
  if (!content || typeof content !== "object") return null;
  const value = (content as { status?: unknown }).status;
  return value === "streaming" || value === "done" || value === "error" ? value : null;
}

function previewText(text: string, maxChars = 140): string {
  const normalized = text.replace(/\s+/g, " ").trim();
  if (!normalized) return "";
  if (normalized.length <= maxChars) return normalized;
  return `${normalized.slice(0, maxChars - 1)}…`;
}

function normalizePromptText(systemPrompt: unknown, prompts: unknown): string {
  const system = typeof systemPrompt === "string" ? systemPrompt : "";

  if (Array.isArray(prompts)) {
    const chunks = prompts.filter((item) => typeof item === "string");
    const joined = chunks.join("\n\n");
    return `${system}\n\n${joined}`.trim();
  }

  if (typeof prompts === "string") {
    return `${system}\n\n${prompts}`.trim();
  }

  return system.trim();
}

export async function listCoachThreads(accessToken: string, limit: number = 60): Promise<CoachThreadListItem[]> {
  const { supabase } = await requireAdmin(accessToken);

  // We sample a larger slice of recent messages and then collapse per-student.
  // This keeps the UI fast without requiring new SQL views/migrations.
  const sampleLimit = Math.max(200, limit * 20);

  const { data, error } = await supabase
    .from("coach_thread_messages")
    .select("id, student_id, role, content, created_at")
    .order("created_at", { ascending: false })
    .limit(sampleLimit);

  if (error) {
    throw new Error("Failed to load coach threads.");
  }

  const map = new Map<string, Omit<CoachThreadListItem, "display_name">>();
  for (const row of (data ?? []) as Array<Pick<CoachThreadMessageRow, "student_id" | "role" | "content" | "created_at">>) {
    if (map.has(row.student_id)) continue;
    const text = extractText(row.content);
    map.set(row.student_id, {
      student_id: row.student_id,
      last_message_at: row.created_at,
      last_message_role: row.role,
      last_message_preview: previewText(text || (row.role === "tool" ? "[tool]" : "")),
      last_message_status: row.role === "assistant" ? extractStatus(row.content) : null,
    });
    if (map.size >= limit) break;
  }

  const studentIds = Array.from(map.keys());
  let profiles: Array<{ id: string; display_name: string | null }> = [];
  if (studentIds.length > 0) {
    const { data: profileData, error: profileError } = await supabase
      .from("profiles")
      .select("id, display_name")
      .in("id", studentIds);

    if (profileError) {
      throw new Error("Failed to load student profiles.");
    }

    profiles = (profileData ?? []) as Array<{ id: string; display_name: string | null }>;
  }

  const displayNameById = profiles.reduce((acc, profile) => {
    acc[profile.id] = profile.display_name;
    return acc;
  }, {} as Record<string, string | null>);

  return studentIds
    .map((studentId) => {
      const base = map.get(studentId);
      if (!base) return null;
      return {
        ...base,
        display_name: displayNameById[studentId] ?? null,
      };
    })
    .filter(Boolean) as CoachThreadListItem[];
}

export async function getCoachThreadDetail(
  accessToken: string,
  studentId: string,
  limitMessages: number = 240,
): Promise<CoachThreadDetail> {
  const { supabase } = await requireAdmin(accessToken);

  const { data: profileData, error: profileError } = await supabase
    .from("profiles")
    .select("id, display_name")
    .eq("id", studentId)
    .maybeSingle();

  if (profileError) {
    throw new Error("Failed to load student profile.");
  }

  const { data: messageData, error: messageError } = await supabase
    .from("coach_thread_messages")
    .select("id, student_id, role, content, created_at, linked_attempt_id, reply_to_message_id")
    .eq("student_id", studentId)
    .order("created_at", { ascending: false })
    .limit(Math.max(20, limitMessages));

  if (messageError) {
    throw new Error("Failed to load coach messages.");
  }

  const messages = ((messageData ?? []) as CoachThreadMessageRow[]).slice().reverse();

  const userMessageIds = messages.filter((msg) => msg.role === "user").map((msg) => msg.id);

  type AiJobRow = {
    id: string;
    kind: string;
    status: string;
    error: string | null;
    dedupe_key: string | null;
    created_at: string;
  };

  type AiAgentLogRow = {
    id: string;
    job_id: string | null;
    model_provider: string;
    model_id: string;
    prompt_version: string | null;
    system_prompt: string | null;
    prompts: unknown;
    status: "done" | "error";
    error: string | null;
    created_at: string;
  };

  const coachReplyLogsByUserMessageId: Record<string, CoachReplyLogMeta> = {};

  if (userMessageIds.length > 0) {
    const { data: jobData, error: jobError } = await supabase
      .from("ai_jobs")
      .select("id, kind, status, error, dedupe_key, created_at")
      .eq("kind", "coach_reply")
      .in("dedupe_key", userMessageIds);

    if (jobError) {
      throw new Error("Failed to load coach reply jobs.");
    }

    const jobs = (jobData ?? []) as AiJobRow[];
    const jobByUserMessageId = jobs.reduce((acc, job) => {
      if (job.dedupe_key) acc[job.dedupe_key] = job;
      return acc;
    }, {} as Record<string, AiJobRow>);

    const jobIds = jobs.map((job) => job.id);

    if (jobIds.length > 0) {
      const { data: logData, error: logError } = await supabase
        .from("ai_agent_logs")
        .select("id, job_id, model_provider, model_id, prompt_version, system_prompt, prompts, status, error, created_at")
        .in("job_id", jobIds);

      if (logError) {
        throw new Error("Failed to load coach reply logs.");
      }

      const logs = (logData ?? []) as AiAgentLogRow[];
      const logByJobId = logs.reduce((acc, log) => {
        if (!log.job_id) return acc;
        const existing = acc[log.job_id];
        if (!existing) {
          acc[log.job_id] = log;
          return acc;
        }

        // Keep the newest one if duplicates exist.
        acc[log.job_id] = existing.created_at >= log.created_at ? existing : log;
        return acc;
      }, {} as Record<string, AiAgentLogRow>);

      for (const userMessageId of userMessageIds) {
        const job = jobByUserMessageId[userMessageId];
        if (!job) continue;
        const log = logByJobId[job.id];
        if (!log) continue;

        const promptText = normalizePromptText(log.system_prompt, log.prompts);

        coachReplyLogsByUserMessageId[userMessageId] = {
          log_id: log.id,
          job_id: job.id,
          user_message_id: userMessageId,
          model_provider: log.model_provider,
          model_id: log.model_id,
          prompt_version: log.prompt_version,
          status: log.status,
          error: log.error,
          created_at: log.created_at,
          estimated_prompt_tokens: estimateTokens(promptText),
        };
      }
    }
  }

  return {
    student: {
      id: studentId,
      display_name: (profileData as { display_name?: string | null } | null)?.display_name ?? null,
    },
    messages,
    coachReplyLogsByUserMessageId,
  };
}

export async function searchCoachMessages(
  accessToken: string,
  query: string,
  limit: number = 60,
): Promise<CoachMessageSearchResult[]> {
  const { supabase } = await requireAdmin(accessToken);

  const normalized = query.trim();
  if (!normalized) return [];

  const { data, error } = await supabase
    .from("coach_thread_messages")
    .select("id, student_id, role, content, created_at, linked_attempt_id")
    .filter("content->>text", "ilike", `%${normalized}%`)
    .order("created_at", { ascending: false })
    .limit(Math.max(10, limit));

  if (error) {
    throw new Error("Failed to search coach messages.");
  }

  const rows = (data ?? []) as Array<Pick<CoachThreadMessageRow, "id" | "student_id" | "role" | "content" | "created_at" | "linked_attempt_id">>;

  const studentIds = Array.from(new Set(rows.map((row) => row.student_id)));
  let profiles: Array<{ id: string; display_name: string | null }> = [];
  if (studentIds.length > 0) {
    const { data: profileData, error: profileError } = await supabase
      .from("profiles")
      .select("id, display_name")
      .in("id", studentIds);

    if (profileError) {
      throw new Error("Failed to load student profiles.");
    }

    profiles = (profileData ?? []) as Array<{ id: string; display_name: string | null }>;
  }

  const displayNameById = profiles.reduce((acc, profile) => {
    acc[profile.id] = profile.display_name;
    return acc;
  }, {} as Record<string, string | null>);

  return rows.map((row) => {
    const text = extractText(row.content);
    return {
      id: row.id,
      student_id: row.student_id,
      display_name: displayNameById[row.student_id] ?? null,
      role: row.role,
      created_at: row.created_at,
      linked_attempt_id: row.linked_attempt_id ?? null,
      text_preview: previewText(text),
    };
  });
}
