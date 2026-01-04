export function scoreAttempt(
  question: { questionType: "mcq" | "numeric"; answerKey: { correct: string | number } },
  attempt: { answer: string | number | null }
) {
  const isCorrect = attempt.answer === question.answerKey.correct;
  return { isCorrect };
}
