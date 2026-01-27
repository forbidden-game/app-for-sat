import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { scoreAttempt } from "./scoring.ts";

Deno.test("scoreAttempt - mcq correct", () => {
  const result = scoreAttempt(
    { questionType: "mcq", answerKey: { correct: "B" } },
    { answer: "B" },
  );
  assertEquals(result.isCorrect, true);
});

Deno.test("scoreAttempt - numeric correct (single)", () => {
  const result = scoreAttempt(
    { questionType: "numeric", answerKey: { correct: 12 } },
    { answer: 12 },
  );
  assertEquals(result.isCorrect, true);
});

Deno.test("scoreAttempt - numeric correct (accepted list)", () => {
  const result = scoreAttempt(
    { questionType: "numeric", answerKey: { correct: 45.12, accepted: [45.125, 45.12, 45.13] } },
    { answer: 45.12 },
  );
  assertEquals(result.isCorrect, true);
});

Deno.test("scoreAttempt - numeric correct (accepted list, float tolerance)", () => {
  const result = scoreAttempt(
    { questionType: "numeric", answerKey: { correct: 0.2, accepted: [0.2] } },
    { answer: 0.20000000000000004 },
  );
  assertEquals(result.isCorrect, true);
});

Deno.test("scoreAttempt - numeric wrong", () => {
  const result = scoreAttempt(
    { questionType: "numeric", answerKey: { correct: 12, accepted: [12] } },
    { answer: 13 },
  );
  assertEquals(result.isCorrect, false);
});
