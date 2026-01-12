import { Type } from "@mariozechner/pi-ai";
import type { AgentTool, AgentToolResult } from "@mariozechner/pi-agent-core";
import type { SupabaseClient } from "@supabase/supabase-js";

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

type SnapshotEntry = {
  key: string;
  count: number;
};

async function upsertStudentSnapshot(supabase: SupabaseClient, studentId: string): Promise<void> {
  const { data: insights, error } = await supabase
    .from("attempt_insights")
    .select("procedure_id,error_step_index,error_mode_enum,created_at")
    .eq("student_id", studentId)
    .order("created_at", { ascending: false })
    .limit(200);

  if (error) throw new Error(error.message);

  const procedureCounts = new Map<string, number>();
  const stepCounts = new Map<string, number>();
  const modeCounts = new Map<string, number>();

  for (const row of insights ?? []) {
    procedureCounts.set(row.procedure_id, (procedureCounts.get(row.procedure_id) ?? 0) + 1);
    const stepKey = `${row.procedure_id}#${row.error_step_index}`;
    stepCounts.set(stepKey, (stepCounts.get(stepKey) ?? 0) + 1);
    modeCounts.set(row.error_mode_enum, (modeCounts.get(row.error_mode_enum) ?? 0) + 1);
  }

  const toTop = (m: Map<string, number>, limit: number): SnapshotEntry[] =>
    [...m.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, limit)
      .map(([key, count]) => ({ key, count }));

  const weakProceduresTop = toTop(procedureCounts, 10);
  const weakStepsTop = toTop(stepCounts, 10);
  const commonErrorModesTop = toTop(modeCounts, 10);

  const { error: upsertError } = await supabase.from("student_snapshots").upsert({
    student_id: studentId,
    subject_scope: "all",
    weak_procedures_top: weakProceduresTop,
    weak_steps_top: weakStepsTop,
    common_error_modes_top: commonErrorModesTop,
    recent_trend: {},
    updated_at: new Date().toISOString(),
  });

  if (upsertError) throw new Error(upsertError.message);
}

export function buildCoachTools(supabase: SupabaseClient): AgentTool<any>[] {
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
        model: null,
        prompt_version: "ai-coach-v1",
        cost_usd: null,
      });

      if (error) throw new Error(error.message);

      try {
        await upsertStudentSnapshot(supabase, params.student_id);
      } catch (e) {
        logger.warn({ err: e, studentId: params.student_id }, "failed to update student snapshot");
      }

      return {
        content: [{ type: "text", text: JSON.stringify({ ok: true }) }],
        details: { ok: true },
      };
    },
  };

  return [searchProcedureCandidates, createProcedure, searchSimilarMistakes, writeAttemptInsight];
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

const FollowupSchema = Type.Object({
  question: Type.String({ minLength: 1 }),
  expected: Type.Optional(Type.String()),
});

const EvidenceSchema = Type.Object({}, { additionalProperties: true });

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
