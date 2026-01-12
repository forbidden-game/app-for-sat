import type { AttemptForCoach } from "../domain/attemptForCoach.js";

export function buildAttemptInsightPrompt(input: AttemptForCoach): string {
  const selectedStepText = input.attempt.student_selected_step_is_unknown
    ? "unknown"
    : input.attempt.student_selected_step_index === null
      ? "unknown"
      : String(input.attempt.student_selected_step_index);

  return [
    "You are an SAT Math coach.",
    "Your job: for a wrong attempt, produce a SHORT, step-based correction.",
    "You MUST use tool calls.",
    "Rules:",
    "- Output must be short. explanation_short <= 120 Chinese characters.",
    "- Ask 1-2 follow-up questions max.",
    "- Use procedure + step as the primary similarity key.",
    "- If student_selected_step is known, prefer it for error_step_index.",
    "",
    "Context (JSON):",
    JSON.stringify(
      {
        attempt: {
          id: input.attempt.id,
          student_id: input.attempt.student_id,
          question_id: input.attempt.question_id,
          answer: input.attempt.answer,
          duration_ms: input.attempt.duration_ms,
          skipped: input.attempt.skipped,
          student_selected_step: selectedStepText,
        },
        question: {
          subject: input.question.subject,
          module: input.question.module,
          difficulty: input.question.difficulty,
          question_type: input.question.question_type,
          stem: input.question.stem,
          options: input.question.options,
          answer_key: input.question.answer_key,
          tags: input.question.tags,
        },
      },
      null,
      2,
    ),
    "",
    "Steps:",
    "1) Call search_procedure_candidates(subject, query) with a short query.",
    "2) If no candidate is a good match, call create_procedure(subject, name, description, steps).",
    "3) Call search_similar_mistakes(student_id, procedure_id, error_step_index).",
    "4) Call write_attempt_insight(...) with: procedure_id, error_step_index, error_mode_enum, evidence, explanation_short, followups.",
  ].join("\n");
}
