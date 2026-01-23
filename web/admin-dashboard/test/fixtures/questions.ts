let counter = 0;

export interface QuestionInput {
  subject?: string;
  module?: string;
  difficulty?: number;
  question_type?: string;
  stem?: string;
  answer_key?: Record<string, unknown>;
  options?: Array<{ label: string; content: string }>;
  metadata?: Record<string, unknown>;
}

export const questionFactory = {
  mcq: (overrides: Partial<QuestionInput> = {}): QuestionInput => ({
    subject: "Math",
    module: "Algebra",
    difficulty: 3,
    question_type: "mcq",
    stem: `Test MCQ Question ${Date.now()}_${counter++}`,
    answer_key: { correct: "A" },
    options: [
      { label: "A", content: "Option A" },
      { label: "B", content: "Option B" },
      { label: "C", content: "Option C" },
      { label: "D", content: "Option D" },
    ],
    ...overrides,
  }),

  numeric: (overrides: Partial<QuestionInput> = {}): QuestionInput => ({
    subject: "Math",
    module: "Arithmetic",
    difficulty: 2,
    question_type: "numeric",
    stem: `Test Numeric Question ${Date.now()}_${counter++}`,
    answer_key: { correct: 42 },
    ...overrides,
  }),

  withTags: (base: QuestionInput, tagIds: string[]): QuestionInput & { tag_ids: string[] } => ({
    ...base,
    tag_ids: tagIds,
  }),
};

export function resetQuestionCounter(): void {
  counter = 0;
}
