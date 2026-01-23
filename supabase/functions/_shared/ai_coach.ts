export type AttemptSnapshot = {
  attempt: {
    id: string;
    student_id: string;
    question_id: string;
    answer: unknown | null;
    student_selected_step_index: number | null;
    student_selected_step_is_unknown: boolean;
  };
  question: {
    id: string;
    subject?: string | null;
    question_type: string;
    stem: string;
    answer_key?: { correct?: string | number } | null;
    options?: Array<{ label: string; content: string }> | null;
  };
};

export type AttemptInsightDraft = {
  explanationShort: string;
  followups: Array<{ question: string; expected?: string | null }>;
  errorStepIndex: number;
  errorModeEnum: string;
  errorModeDetail?: string | null;
  procedureName: string;
  procedureSteps: string[];
  procedureStepsVersion: number;
  confidence: number;
  model: string;
  promptVersion: string;
  costUsd: number;
};

const defaultSteps = [
  "Identify target and given conditions",
  "Model the problem with equations",
  "Transform to a solvable form",
  "Solve for the target quantity",
  "Check constraints and substitute back",
  "Match options and eliminate traps",
];

export function buildProcedureSteps(): string[] {
  return [...defaultSteps];
}

function clampIndex(value: number, max: number) {
  return Math.min(Math.max(value, 0), Math.max(max, 0));
}

export function buildAttemptInsightDraft(snapshot: AttemptSnapshot): AttemptInsightDraft {
  const steps = buildProcedureSteps();
  const selected = snapshot.attempt.student_selected_step_is_unknown
    ? null
    : snapshot.attempt.student_selected_step_index;
  const errorStepIndex =
    typeof selected === "number" && Number.isFinite(selected)
      ? clampIndex(selected, steps.length - 1)
      : 0;
  const stepName = steps[errorStepIndex] ?? "Unknown step";

  const explanationShort =
    selected !== null
      ? `You flagged difficulty near step ${errorStepIndex + 1}: ${stepName}. Focus on clarifying that transition before moving on.`
      : "You were unsure where the mistake began. Start by writing the target and checking each intermediate result for consistency.";

  const followups =
    selected !== null
      ? [
          { question: `Which part of "${stepName}" felt most confusing?` },
          { question: "What intermediate value did you compute right before the mistake?" },
        ]
      : [
          { question: "Which step felt most uncertain?" },
          { question: "What was your last confident intermediate result?" },
        ];

  return {
    explanationShort,
    followups,
    errorStepIndex,
    errorModeEnum: selected !== null ? "student_selected_step" : "unknown_step",
    errorModeDetail: selected !== null ? `step_${errorStepIndex}` : null,
    procedureName: "General Problem Solving",
    procedureSteps: steps,
    procedureStepsVersion: 1,
    confidence: 0.35,
    model: "draft",
    promptVersion: "v0",
    costUsd: 0,
  };
}

export function buildCoachReplyDraft(params: {
  userText: string;
  linkedAttemptId?: string | null;
}): { text: string; chunks: string[] } {
  const clipped = params.userText.trim().slice(0, 160);
  const contextHint = params.linkedAttemptId
    ? "I can see your linked attempt."
    : "I do not see a linked attempt yet.";
  const text = `${contextHint} Based on your message, start by restating the target and the key constraint. Then we can check the exact step that broke: "${clipped}".`;

  const chunkSize = Math.max(24, Math.min(64, Math.floor(text.length / 2)));
  const chunks = [text.slice(0, chunkSize), text];

  return { text, chunks };
}
