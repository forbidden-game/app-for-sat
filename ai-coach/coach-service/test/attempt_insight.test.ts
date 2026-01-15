import { describe, expect, it } from "vitest";

import { processAttemptInsightJob } from "../src/jobs/processAttemptInsightJob.js";
import { JobDeferredError } from "../src/jobs/jobErrors.js";
import { createSupabaseMock } from "./helpers.js";

type Snapshot = {
  attempt: {
    id: string;
    student_id: string;
    question_id: string;
    is_correct: boolean | null;
    student_selected_step_index: number | null;
    student_selected_step_is_unknown: boolean;
    duration_ms: number | null;
    skipped: boolean;
    answer: unknown;
  };
  question: {
    subject: string;
    module: string;
    difficulty: number;
    question_type: string;
    stem: string;
    options: Array<{ label: string; content: string }>;
    answer_key: { correct: string };
    tags: Array<{ id: string; name: string; category: string }>;
  };
};

function makeSnapshot(overrides: Partial<Snapshot> = {}): Snapshot {
  return {
    attempt: {
      id: "attempt-1",
      student_id: "student-1",
      question_id: "question-1",
      is_correct: false,
      student_selected_step_index: 2,
      student_selected_step_is_unknown: false,
      duration_ms: 12000,
      skipped: false,
      answer: { choice: "B" },
    },
    question: {
      subject: "math",
      module: "algebra",
      difficulty: 1,
      question_type: "mcq",
      stem: "Test stem",
      options: [{ label: "A", content: "Option" }],
      answer_key: { correct: "A" },
      tags: [{ id: "t1", name: "tag", category: "math" }],
    },
    ...overrides,
  };
}

class StubAgent {
  prompts: string[] = [];

  async prompt(text: string): Promise<void> {
    this.prompts.push(text);
  }
}

function makeJob(createdAt: string = new Date().toISOString()) {
  return {
    id: "job-1",
    kind: "attempt_insight",
    attempt_id: "attempt-1",
    student_id: "student-1",
    created_at: createdAt,
  };
}

function buildSupabaseForAttempt(snapshot: Snapshot, attemptInsightSelect?: Array<{ data: any; error: any }>) {
  return createSupabaseMock({
    rpc: {
      get_attempt_for_coach: [{ data: snapshot, error: null }],
    },
    from: {
      profiles: { select: [{ data: { display_name: null }, error: null }] },
      student_snapshots: { select: [{ data: null, error: null }] },
      student_reports: { select: [{ data: [], error: null }] },
      attempt_insights: {
        select:
          attemptInsightSelect ??
          [
            { data: [], error: null }, // recent_insights
            { data: null, error: null }, // linked attempt insight
            { data: { attempt_id: "attempt-1" }, error: null }, // hasInsight
          ],
      },
    },
  });
}

describe("processAttemptInsightJob", () => {
  it("throws when get_attempt_for_coach errors", async () => {
    const { supabase } = createSupabaseMock({
      rpc: {
        get_attempt_for_coach: [{ data: null, error: { message: "rpc_failed" } }],
      },
    });
    const agent = new StubAgent();

    await expect(processAttemptInsightJob(supabase, agent as any, makeJob())).rejects.toThrow(
      /missing_attempt_context/,
    );
  });

  it("throws when snapshot missing", async () => {
    const { supabase } = createSupabaseMock({
      rpc: {
        get_attempt_for_coach: [{ data: null, error: null }],
      },
    });
    const agent = new StubAgent();

    await expect(processAttemptInsightJob(supabase, agent as any, makeJob())).rejects.toThrow(
      /missing_attempt_context/,
    );
  });

  it("skips when attempt is correct", async () => {
    const snapshot = makeSnapshot({ attempt: { ...makeSnapshot().attempt, is_correct: true } });
    const { supabase } = buildSupabaseForAttempt(snapshot);
    const agent = new StubAgent();

    await processAttemptInsightJob(supabase, agent as any, makeJob());

    expect(agent.prompts).toHaveLength(0);
  });

  it("defers when step missing and job is fresh", async () => {
    const snapshot = makeSnapshot({
      attempt: { ...makeSnapshot().attempt, student_selected_step_index: null, student_selected_step_is_unknown: false },
    });
    const { supabase } = buildSupabaseForAttempt(snapshot);
    const agent = new StubAgent();

    await expect(processAttemptInsightJob(supabase, agent as any, makeJob())).rejects.toBeInstanceOf(
      JobDeferredError,
    );
  });

  it("proceeds when step missing but job is old", async () => {
    const snapshot = makeSnapshot({
      attempt: { ...makeSnapshot().attempt, student_selected_step_index: null, student_selected_step_is_unknown: false },
    });
    const { supabase } = buildSupabaseForAttempt(snapshot);
    const agent = new StubAgent();
    const old = new Date(Date.now() - 5 * 60 * 1000).toISOString();

    await processAttemptInsightJob(supabase, agent as any, makeJob(old));

    expect(agent.prompts.length).toBeGreaterThan(0);
  });

  it("does not defer when step explicitly unknown", async () => {
    const snapshot = makeSnapshot({
      attempt: { ...makeSnapshot().attempt, student_selected_step_index: null, student_selected_step_is_unknown: true },
    });
    const { supabase } = buildSupabaseForAttempt(snapshot);
    const agent = new StubAgent();

    await processAttemptInsightJob(supabase, agent as any, makeJob());

    expect(agent.prompts.length).toBeGreaterThan(0);
  });

  it("calls agent prompt", async () => {
    const snapshot = makeSnapshot();
    const { supabase } = buildSupabaseForAttempt(snapshot);
    const agent = new StubAgent();

    await processAttemptInsightJob(supabase, agent as any, makeJob());

    expect(agent.prompts).toHaveLength(1);
  });

  it("includes student_selected_step in prompt", async () => {
    const snapshot = makeSnapshot({
      attempt: { ...makeSnapshot().attempt, student_selected_step_index: 3 },
    });
    const { supabase } = buildSupabaseForAttempt(snapshot);
    const agent = new StubAgent();

    await processAttemptInsightJob(supabase, agent as any, makeJob());

    expect(agent.prompts[0]).toContain("\"student_selected_step\": \"3\"");
  });

  it("includes unknown step in prompt", async () => {
    const snapshot = makeSnapshot({
      attempt: { ...makeSnapshot().attempt, student_selected_step_index: null, student_selected_step_is_unknown: true },
    });
    const { supabase } = buildSupabaseForAttempt(snapshot);
    const agent = new StubAgent();

    await processAttemptInsightJob(supabase, agent as any, makeJob());

    expect(agent.prompts[0]).toContain("\"student_selected_step\": \"unknown\"");
  });

  it("retries when insight missing after first prompt", async () => {
    const snapshot = makeSnapshot();
    const { supabase } = buildSupabaseForAttempt(snapshot, [
      { data: [], error: null }, // recent_insights
      { data: null, error: null }, // linked insight
      { data: null, error: null }, // hasInsight (first)
      { data: { attempt_id: "attempt-1" }, error: null }, // hasInsight (retry)
    ]);
    const agent = new StubAgent();

    await processAttemptInsightJob(supabase, agent as any, makeJob());

    expect(agent.prompts).toHaveLength(2);
    expect(agent.prompts[1]).toContain("write_attempt_insight");
  });

  it("throws when insight still missing after retry", async () => {
    const snapshot = makeSnapshot();
    const { supabase } = buildSupabaseForAttempt(snapshot, [
      { data: [], error: null },
      { data: null, error: null },
      { data: null, error: null },
      { data: null, error: null },
    ]);
    const agent = new StubAgent();

    await expect(processAttemptInsightJob(supabase, agent as any, makeJob())).rejects.toThrow(
      /attempt_insight_not_written/,
    );
  });

  it("includes attempt_id in retry prompt", async () => {
    const snapshot = makeSnapshot();
    const { supabase } = buildSupabaseForAttempt(snapshot, [
      { data: [], error: null },
      { data: null, error: null },
      { data: null, error: null },
      { data: { attempt_id: "attempt-1" }, error: null },
    ]);
    const agent = new StubAgent();

    await processAttemptInsightJob(supabase, agent as any, makeJob());

    expect(agent.prompts[1]).toContain("attempt_id=attempt-1");
  });

  it("includes student_id in retry prompt", async () => {
    const snapshot = makeSnapshot();
    const { supabase } = buildSupabaseForAttempt(snapshot, [
      { data: [], error: null },
      { data: null, error: null },
      { data: null, error: null },
      { data: { attempt_id: "attempt-1" }, error: null },
    ]);
    const agent = new StubAgent();

    await processAttemptInsightJob(supabase, agent as any, makeJob());

    expect(agent.prompts[1]).toContain("student_id=student-1");
  });

  it("includes question_id in retry prompt", async () => {
    const snapshot = makeSnapshot();
    const { supabase } = buildSupabaseForAttempt(snapshot, [
      { data: [], error: null },
      { data: null, error: null },
      { data: null, error: null },
      { data: { attempt_id: "attempt-1" }, error: null },
    ]);
    const agent = new StubAgent();

    await processAttemptInsightJob(supabase, agent as any, makeJob());

    expect(agent.prompts[1]).toContain("question_id=question-1");
  });

  it("handles skipped attempts", async () => {
    const snapshot = makeSnapshot({ attempt: { ...makeSnapshot().attempt, skipped: true } });
    const { supabase } = buildSupabaseForAttempt(snapshot);
    const agent = new StubAgent();

    await processAttemptInsightJob(supabase, agent as any, makeJob());

    expect(agent.prompts).toHaveLength(1);
  });

  it("handles null duration", async () => {
    const snapshot = makeSnapshot({ attempt: { ...makeSnapshot().attempt, duration_ms: null } });
    const { supabase } = buildSupabaseForAttempt(snapshot);
    const agent = new StubAgent();

    await processAttemptInsightJob(supabase, agent as any, makeJob());

    expect(agent.prompts).toHaveLength(1);
  });

  it("supports numeric answer_key", async () => {
    const snapshot = makeSnapshot({ question: { ...makeSnapshot().question, answer_key: { correct: 42 } as any } });
    const { supabase } = buildSupabaseForAttempt(snapshot);
    const agent = new StubAgent();

    await processAttemptInsightJob(supabase, agent as any, makeJob());

    expect(agent.prompts).toHaveLength(1);
  });

  it("handles empty tags array", async () => {
    const snapshot = makeSnapshot({ question: { ...makeSnapshot().question, tags: [] } });
    const { supabase } = buildSupabaseForAttempt(snapshot);
    const agent = new StubAgent();

    await processAttemptInsightJob(supabase, agent as any, makeJob());

    expect(agent.prompts).toHaveLength(1);
  });

  it("handles null is_correct by skipping", async () => {
    const snapshot = makeSnapshot({ attempt: { ...makeSnapshot().attempt, is_correct: null } });
    const { supabase } = buildSupabaseForAttempt(snapshot);
    const agent = new StubAgent();

    await processAttemptInsightJob(supabase, agent as any, makeJob());

    expect(agent.prompts).toHaveLength(0);
  });

  it("handles correct attempt without prompting", async () => {
    const snapshot = makeSnapshot({ attempt: { ...makeSnapshot().attempt, is_correct: true } });
    const { supabase } = buildSupabaseForAttempt(snapshot);
    const agent = new StubAgent();

    await processAttemptInsightJob(supabase, agent as any, makeJob());

    expect(agent.prompts).toHaveLength(0);
  });
});
