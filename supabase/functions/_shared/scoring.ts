type QuestionType = "mcq" | "numeric";

type AnswerKey = {
  // Backwards-compatible single correct answer.
  correct: string | number;
  // For numeric questions, allow multiple accepted numeric values.
  accepted?: Array<number>;
};

function normalizeAccepted(values: unknown): number[] {
  if (!Array.isArray(values)) {
    return [];
  }
  const out: number[] = [];
  for (const v of values) {
    if (typeof v === "number" && Number.isFinite(v)) {
      out.push(v);
    }
  }
  return out;
}

function numericEquals(a: number, b: number, epsilon = 1e-9): boolean {
  return Math.abs(a - b) <= epsilon;
}

export function scoreAttempt(
  question: { questionType: QuestionType; answerKey: AnswerKey },
  attempt: { answer: string | number | null },
) {
  // Multiple-choice: exact match.
  if (question.questionType === "mcq") {
    const isCorrect = attempt.answer === question.answerKey.correct;
    return { isCorrect };
  }

  // Numeric: prefer accepted list if present.
  if (typeof attempt.answer !== "number" || !Number.isFinite(attempt.answer)) {
    return { isCorrect: false };
  }

  const accepted = normalizeAccepted((question.answerKey as { accepted?: unknown }).accepted);
  if (accepted.length > 0) {
    const isCorrect = accepted.some((v) => numericEquals(attempt.answer as number, v));
    return { isCorrect };
  }

  if (typeof question.answerKey.correct === "number") {
    const isCorrect = numericEquals(attempt.answer, question.answerKey.correct);
    return { isCorrect };
  }

  return { isCorrect: false };
}
