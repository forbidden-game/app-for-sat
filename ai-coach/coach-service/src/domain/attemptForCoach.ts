export type AttemptForCoach = {
  attempt: {
    id: string;
    student_id: string;
    session_id: string;
    question_id: string;
    answer: unknown;
    is_correct: boolean | null;
    duration_ms: number | null;
    skipped: boolean;
    student_selected_step_index: number | null;
    student_selected_step_is_unknown: boolean;
    created_at: string;
  };
  question: {
    id: string;
    subject: string;
    module: string;
    difficulty: number;
    question_type: string;
    stem: string;
    answer_key: unknown;
    metadata: unknown;
    options: { label: string; content: string }[];
    tags: { id: string; name: string; category: string }[];
  };
};
