import type { CoachContextPacket } from "../context/coachContext.js";

export function buildAttemptInsightPrompt(context: CoachContextPacket): string {
  if (!context.attempt || !context.question) {
    throw new Error("missing_attempt_context");
  }

  const selectedStepText = context.attempt.student_selected_step_is_unknown
    ? "unknown"
    : context.attempt.student_selected_step_index === null
      ? "unknown"
      : String(context.attempt.student_selected_step_index);

  const procedureSubject = "sat_math";

  return [
    "You are an SAT Math coach.",
    "Your job: for a wrong attempt, produce a SHORT, step-based correction.",
    "You MUST use tool calls.",
    "Language: Chinese only for explanation_short and followups.",
    "Indexing: error_step_index is 0-based.",
    "Rules:",
    "- Output must be short. explanation_short <= 120 Chinese characters.",
    "- Ask 1-2 follow-up questions max.",
    "- Use procedure + step as the primary similarity key.",
    "- If student_selected_step is known, prefer it for error_step_index.",
    "",
    "Context (JSON):",
    JSON.stringify(
      {
        procedure_subject: procedureSubject,
        student: context.student,
        attempt: {
          id: context.attempt.id,
          student_id: context.attempt.student_id,
          question_id: context.attempt.question_id,
          answer: context.attempt.answer,
          duration_ms: context.attempt.duration_ms,
          skipped: context.attempt.skipped,
          student_selected_step: selectedStepText,
        },
        question: {
          subject: context.question.subject,
          module: context.question.module,
          difficulty: context.question.difficulty,
          question_type: context.question.question_type,
          stem: context.question.stem,
          options: context.question.options,
          answer_key: context.question.answer_key,
          tags: context.question.tags,
        },
        snapshot: context.snapshot,
        recent_insights: context.recent_insights,
      },
      null,
      2,
    ),
    "",
    "Steps:",
    `1) Call search_procedure_candidates(subject=\"${procedureSubject}\", query=...) with a short query.`,
    `2) If no candidate is a good match, call create_procedure(subject=\"${procedureSubject}\", name, description, steps).`,
    "3) Decide error_step_index (0-based).",
    "4) Call search_similar_mistakes(student_id, procedure_id, error_step_index).",
    "5) Call write_attempt_insight(...) with: procedure_id, procedure_steps_version, error_step_index, error_mode_enum, evidence, explanation_short, followups.",
  ].join("\n");
}
