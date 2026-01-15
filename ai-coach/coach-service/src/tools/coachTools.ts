import { Type } from "@sinclair/typebox";
import type { AgentTool, AgentToolResult } from "@mariozechner/pi-agent-core";
import type { SupabaseClient } from "@supabase/supabase-js";

import { buildCoachContext, type CoachContextPacket } from "../context/coachContext.js";
import { errorModeEnum, type ErrorModeEnum } from "../domain/errorModes.js";
import { logger } from "../logger.js";

type SearchProcedureCandidate = {
  procedure_id: string;
  name: string;
  similarity: number;
  steps_version: number;
  steps: unknown;
  description: string | null;
};

type SimilarMistake = {
  attempt_id: string;
  created_at: string;
  error_step_index: number;
  error_mode_enum: string;
  explanation_short: string;
  student_selected_step_index: number | null;
  student_selected_step_is_unknown: boolean;
};

export type CoachToolOptions = {
  modelId?: string;
  promptVersion?: string;
  allowWriteInsight?: boolean;
  includeMemoryTools?: boolean;
  includeContextTool?: boolean;
};

async function enqueueSnapshotRefresh(supabase: SupabaseClient, studentId: string): Promise<void> {
  const dedupeKey = `snapshot:${studentId}:${new Date().toISOString().slice(0, 10)}`;
  const { error } = await supabase.from("ai_jobs").insert({
    kind: "snapshot_refresh",
    status: "queued",
    student_id: studentId,
    payload: { student_id: studentId },
    run_after: new Date().toISOString(),
    dedupe_key: dedupeKey,
  });

  if (error) {
    if (error.code === "23505") return;
    logger.warn({ err: error, studentId }, "failed to enqueue snapshot_refresh");
  }
}

export function buildCoachTools(supabase: SupabaseClient, options: CoachToolOptions = {}): AgentTool<any>[] {
  const allowWriteInsight = options.allowWriteInsight ?? true;
  const includeMemoryTools = options.includeMemoryTools ?? true;
  const includeContextTool = options.includeContextTool ?? true;

  const searchProcedureCandidates: AgentTool<
    typeof SearchProcedureCandidatesSchema,
    { candidates: SearchProcedureCandidate[] }
  > = {
    name: "search_procedure_candidates",
    label: "Search procedure candidates",
    description: "Search existing SAT Math procedures before creating a new one.",
    parameters: SearchProcedureCandidatesSchema,
    execute: async (_toolCallId, params): Promise<AgentToolResult<{ candidates: SearchProcedureCandidate[] }>> => {
      const { data, error } = await supabase.rpc("search_procedure_candidates", {
        p_subject: params.subject,
        p_query: params.query,
        p_limit: params.limit ?? 5,
      });

      if (error) throw new Error(error.message);
      const candidates = (data ?? []) as SearchProcedureCandidate[];

      return {
        content: [{ type: "text", text: JSON.stringify({ candidates }) }],
        details: { candidates },
      };
    },
  };

  const getCoachContext: AgentTool<typeof GetCoachContextSchema, { context: CoachContextPacket }> = {
    name: "get_coach_context",
    label: "Get coach context",
    description: "Load a compact context packet for the student (optionally linked to an attempt).",
    parameters: GetCoachContextSchema,
    execute: async (_toolCallId, params) => {
      const context = await buildCoachContext({
        supabase,
        studentId: params.student_id,
        linkedAttemptId: params.linked_attempt_id ?? null,
        includeMessages: params.include_messages ?? true,
        messageLimit: params.message_limit ?? 30,
        insightLimit: params.insight_limit ?? 5,
        reportLimit: params.report_limit ?? 2,
      });

      return {
        content: [{ type: "text", text: JSON.stringify({ context }) }],
        details: { context },
      };
    },
  };

  const createProcedure: AgentTool<typeof CreateProcedureSchema, { procedure_id: string; steps_version: number }> = {
    name: "create_procedure",
    label: "Create procedure",
    description: "Create a new SAT Math procedure with 3-7 steps.",
    parameters: CreateProcedureSchema,
    execute: async (_toolCallId, params) => {
      const insertPayload = {
        subject: params.subject,
        name: params.name,
        description: params.description ?? null,
        steps: params.steps,
        steps_version: 1,
        created_by: "ai",
        updated_at: new Date().toISOString(),
      };

      const { data, error } = await supabase.from("procedures").insert(insertPayload).select("id,steps_version").single();

      if (error) throw new Error(error.message);

      return {
        content: [{ type: "text", text: JSON.stringify({ procedure_id: data.id, steps_version: data.steps_version }) }],
        details: { procedure_id: data.id, steps_version: data.steps_version },
      };
    },
  };

  const searchSimilarMistakes: AgentTool<typeof SearchSimilarMistakesSchema, { matches: SimilarMistake[] }> = {
    name: "search_similar_mistakes",
    label: "Search similar mistakes",
    description: "Search this student's historical mistakes by procedure + step.",
    parameters: SearchSimilarMistakesSchema,
    execute: async (_toolCallId, params) => {
      const { data, error } = await supabase
        .from("attempt_insights")
        .select(
          "attempt_id,created_at,error_step_index,error_mode_enum,explanation_short,student_selected_step_index,student_selected_step_is_unknown",
        )
        .eq("student_id", params.student_id)
        .eq("procedure_id", params.procedure_id)
        .eq("error_step_index", params.error_step_index)
        .order("created_at", { ascending: false })
        .limit(params.limit ?? 5);

      if (error) throw new Error(error.message);

      const matches = (data ?? []) as SimilarMistake[];

      return {
        content: [{ type: "text", text: JSON.stringify({ matches }) }],
        details: { matches },
      };
    },
  };

  const writeAttemptInsight: AgentTool<typeof WriteAttemptInsightSchema, { ok: true }> = {
    name: "write_attempt_insight",
    label: "Write attempt insight",
    description: "Persist a structured insight for a wrong attempt.",
    parameters: WriteAttemptInsightSchema,
    execute: async (_toolCallId, params) => {
      const errorMode = params.error_mode_enum as ErrorModeEnum;
      if (!errorModeEnum.includes(errorMode)) {
        throw new Error(`invalid error_mode_enum: ${params.error_mode_enum}`);
      }

      const { error } = await supabase.from("attempt_insights").insert({
        attempt_id: params.attempt_id,
        student_id: params.student_id,
        question_id: params.question_id,
        procedure_id: params.procedure_id,
        procedure_steps_version: params.procedure_steps_version,
        error_step_index: params.error_step_index,
        student_selected_step_index: params.student_selected_step_index,
        student_selected_step_is_unknown: params.student_selected_step_is_unknown,
        error_mode_enum: params.error_mode_enum,
        error_mode_detail: params.error_mode_detail ?? null,
        evidence: params.evidence,
        explanation_short: params.explanation_short,
        followups: params.followups,
        confidence: params.confidence ?? null,
        model: options.modelId ?? null,
        prompt_version: options.promptVersion ?? "ai-coach-insight-v2",
        cost_usd: null,
      });

      if (error) throw new Error(error.message);

      try {
        await enqueueSnapshotRefresh(supabase, params.student_id);
      } catch (e) {
        logger.warn({ err: e, studentId: params.student_id }, "failed to enqueue snapshot refresh");
      }

      return {
        content: [{ type: "text", text: JSON.stringify({ ok: true }) }],
        details: { ok: true },
      };
    },
  };

  const memorySearch: AgentTool<typeof MemorySearchSchema, { results: MemorySearchResult[]; disabled?: boolean; error?: string }> =
    {
      name: "memory_search",
      label: "Memory search",
      description: "Search teacher memory entries for this student.",
      parameters: MemorySearchSchema,
      execute: async (_toolCallId, params) => {
        const { data, error } = await supabase
          .from("coach_memory_entries")
          .select("id,scope,content,tags,source,created_at")
          .eq("student_id", params.student_id)
          .ilike("content", `%${params.query}%`)
          .order("created_at", { ascending: false })
          .limit(params.limit ?? 5);

        if (error) {
          if (isMissingRelationError(error)) {
            const details = { results: [], disabled: true, error: error.message };
            return {
              content: [{ type: "text", text: JSON.stringify(details) }],
              details,
            };
          }
          throw new Error(error.message);
        }

        const results = (data ?? []).map((row) => ({
          id: row.id as string,
          scope: row.scope as string,
          tags: (row.tags as string[] | null) ?? [],
          source: (row.source as string | null) ?? null,
          created_at: row.created_at as string,
          snippet: String(row.content ?? "").slice(0, 200),
        }));

        return {
          content: [{ type: "text", text: JSON.stringify({ results }) }],
          details: { results },
        };
      },
    };

  const memoryGet: AgentTool<typeof MemoryGetSchema, { entry: MemoryEntry | null; disabled?: boolean; error?: string }> = {
    name: "memory_get",
    label: "Memory get",
    description: "Fetch a full memory entry by id.",
    parameters: MemoryGetSchema,
    execute: async (_toolCallId, params) => {
      const { data, error } = await supabase
        .from("coach_memory_entries")
        .select("id,scope,content,tags,source,created_at")
        .eq("id", params.memory_id)
        .maybeSingle();

      if (error) {
        if (isMissingRelationError(error)) {
          const details = { entry: null, disabled: true, error: error.message };
          return {
            content: [{ type: "text", text: JSON.stringify(details) }],
            details,
          };
        }
        throw new Error(error.message);
      }

      const entry = data
        ? {
            id: data.id as string,
            scope: data.scope as string,
            content: data.content as string,
            tags: (data.tags as string[] | null) ?? [],
            source: (data.source as string | null) ?? null,
            created_at: data.created_at as string,
          }
        : null;

      return {
        content: [{ type: "text", text: JSON.stringify({ entry }) }],
        details: { entry },
      };
    },
  };

  const memoryWrite: AgentTool<
    typeof MemoryWriteSchema,
    { ok: boolean; id?: string; disabled?: boolean; error?: string }
  > = {
    name: "memory_write",
    label: "Memory write",
    description: "Write a teacher memory entry for the student.",
    parameters: MemoryWriteSchema,
    execute: async (_toolCallId, params) => {
      const { data, error } = await supabase
        .from("coach_memory_entries")
        .insert({
          student_id: params.student_id,
          scope: params.scope,
          content: params.content,
          tags: params.tags ?? null,
          source: params.source ?? null,
        })
        .select("id")
        .single();

      if (error) {
        if (isMissingRelationError(error)) {
          const details = { ok: true, disabled: true, error: error.message };
          return {
            content: [{ type: "text", text: JSON.stringify(details) }],
            details,
          };
        }
        throw new Error(error.message);
      }

      return {
        content: [{ type: "text", text: JSON.stringify({ ok: true, id: data.id }) }],
        details: { ok: true, id: data.id as string },
      };
    },
  };

  const tools: AgentTool<any>[] = [
    searchProcedureCandidates,
    createProcedure,
    searchSimilarMistakes,
    ...(includeContextTool ? [getCoachContext] : []),
    ...(allowWriteInsight ? [writeAttemptInsight] : []),
    ...(includeMemoryTools ? [memorySearch, memoryGet, memoryWrite] : []),
  ];

  return tools;
}

const SearchProcedureCandidatesSchema = Type.Object({
  subject: Type.String({ minLength: 1 }),
  query: Type.String({ minLength: 1 }),
  limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 20 })),
});

const CreateProcedureSchema = Type.Object({
  subject: Type.String({ minLength: 1 }),
  name: Type.String({ minLength: 1 }),
  description: Type.Optional(Type.String()),
  steps: Type.Array(Type.String({ minLength: 1 }), { minItems: 3, maxItems: 7 }),
});

const SearchSimilarMistakesSchema = Type.Object({
  student_id: Type.String({ minLength: 1 }),
  procedure_id: Type.String({ minLength: 1 }),
  error_step_index: Type.Integer({ minimum: 0, maximum: 20 }),
  limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 20 })),
});

const GetCoachContextSchema = Type.Object({
  student_id: Type.String({ minLength: 1 }),
  linked_attempt_id: Type.Optional(Type.String({ minLength: 1 })),
  include_messages: Type.Optional(Type.Boolean()),
  message_limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 50 })),
  insight_limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 20 })),
  report_limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 10 })),
});

const FollowupSchema = Type.Object({
  question: Type.String({ minLength: 1 }),
  expected: Type.Optional(Type.String()),
});

const EvidenceSchema = Type.Object({}, { additionalProperties: true });

const MemorySearchSchema = Type.Object({
  student_id: Type.String({ minLength: 1 }),
  query: Type.String({ minLength: 1 }),
  limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 20 })),
});

const MemoryGetSchema = Type.Object({
  memory_id: Type.String({ minLength: 1 }),
});

const MemoryWriteSchema = Type.Object({
  student_id: Type.String({ minLength: 1 }),
  scope: Type.Union([Type.Literal("daily"), Type.Literal("curated")]),
  content: Type.String({ minLength: 1, maxLength: 2000 }),
  tags: Type.Optional(Type.Array(Type.String({ minLength: 1 }), { maxItems: 12 })),
  source: Type.Optional(Type.String({ minLength: 1, maxLength: 80 })),
});

const WriteAttemptInsightSchema = Type.Object({
  attempt_id: Type.String({ minLength: 1 }),
  student_id: Type.String({ minLength: 1 }),
  question_id: Type.String({ minLength: 1 }),
  procedure_id: Type.String({ minLength: 1 }),
  procedure_steps_version: Type.Integer({ minimum: 1 }),
  error_step_index: Type.Integer({ minimum: 0, maximum: 20 }),
  student_selected_step_index: Type.Optional(Type.Union([Type.Integer({ minimum: 0, maximum: 20 }), Type.Null()])),
  student_selected_step_is_unknown: Type.Boolean(),
  error_mode_enum: Type.String({ minLength: 1 }),
  error_mode_detail: Type.Optional(Type.String()),
  evidence: EvidenceSchema,
  explanation_short: Type.String({ minLength: 1, maxLength: 200 }),
  followups: Type.Array(FollowupSchema, { minItems: 0, maxItems: 2 }),
  confidence: Type.Optional(Type.Number({ minimum: 0, maximum: 1 })),
});

type MemorySearchResult = {
  id: string;
  scope: string;
  tags: string[];
  source: string | null;
  created_at: string;
  snippet: string;
};

type MemoryEntry = {
  id: string;
  scope: string;
  content: string;
  tags: string[];
  source: string | null;
  created_at: string;
};

function isMissingRelationError(error: { code?: string | null; message?: string | null }): boolean {
  const code = typeof error.code === "string" ? error.code : "";
  if (code === "42P01") return true;
  const message = typeof error.message === "string" ? error.message.toLowerCase() : "";
  return message.includes("does not exist") || message.includes("undefined");
}
