import { assertEquals, assertExists } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

function getEnv(...names: string[]): string {
  for (const name of names) {
    const value = Deno.env.get(name);
    if (value && value.trim().length > 0) {
      return value.trim();
    }
  }
  throw new Error(`Missing required env var (any of): ${names.join(", ")}`);
}

const supabaseUrl = getEnv("NEXT_PUBLIC_SUPABASE_URL", "SUPABASE_URL");
const supabaseAnonKey = getEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY", "SUPABASE_ANON_KEY");
const supabaseServiceRoleKey = getEnv("SUPABASE_SERVICE_ROLE_KEY");

const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
  auth: { persistSession: false },
});
const anon = createClient(supabaseUrl, supabaseAnonKey, {
  auth: { persistSession: false },
});

type TestUser = {
  id: string;
  email: string;
  password: string;
  accessToken: string;
};

type BankAndQuestion = {
  bankId: string;
  bankSlug: string;
  questionId: string;
};

type TestResources = {
  userId?: string;
  bankId?: string;
  questionId?: string;
  sessionId?: string;
};

async function delay(ms: number) {
  await new Promise((resolve) => setTimeout(resolve, ms));
}

async function retry<T>(fn: () => Promise<T>, opts?: { timeoutMs?: number; intervalMs?: number }): Promise<T> {
  const timeoutMs = opts?.timeoutMs ?? 15_000;
  const intervalMs = opts?.intervalMs ?? 500;
  const startedAt = Date.now();

  while (true) {
    try {
      return await fn();
    } catch (err) {
      if (Date.now() - startedAt > timeoutMs) {
        throw err;
      }
      await delay(intervalMs);
    }
  }
}

async function createTestUser(): Promise<TestUser> {
  const runId = crypto.randomUUID().slice(0, 8);
  const email = `e2e+coach-${Date.now()}-${runId}@example.com`;
  const password = `E2E-${crypto.randomUUID()}!aA1`;

  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });
  if (createError || !created.user) {
    throw new Error(`Failed to create test user: ${createError?.message ?? "unknown"}`);
  }

  const { data: signInData, error: signInError } = await anon.auth.signInWithPassword({ email, password });
  if (signInError || !signInData.session?.access_token) {
    throw new Error(`Failed to sign in test user: ${signInError?.message ?? "unknown"}`);
  }

  return {
    id: created.user.id,
    email,
    password,
    accessToken: signInData.session.access_token,
  };
}

async function createBankAndQuestion(): Promise<BankAndQuestion> {
  const runId = crypto.randomUUID().slice(0, 8);
  const bankSlug = `e2e-coach-${Date.now()}-${runId}`;

  const { data: question, error: questionError } = await admin
    .from("questions")
    .insert({
      subject: "math",
      module: "algebra",
      difficulty: 1,
      question_type: "mcq",
      stem: `E2E: What is 2 + 2? (${runId})`,
      answer_key: { correct: "A" },
      metadata: { source: "cloud-e2e", runId },
    })
    .select("id")
    .single();

  if (questionError || !question) {
    throw new Error(`Failed to create question: ${questionError?.message ?? "unknown"}`);
  }

  const questionId = question.id as string;

  const { error: optionsError } = await admin.from("question_options").insert([
    { question_id: questionId, label: "A", content: "4" },
    { question_id: questionId, label: "B", content: "5" },
    { question_id: questionId, label: "C", content: "3" },
    { question_id: questionId, label: "D", content: "2" },
  ]);
  if (optionsError) {
    throw new Error(`Failed to create question options: ${optionsError.message}`);
  }

  const { data: bank, error: bankError } = await admin
    .from("question_banks")
    .insert({
      slug: bankSlug,
      title: `E2E Coach Bank (${runId})`,
      subtitle: "cloud e2e",
      mode: "fixed",
      question_limit: 1,
      rule_json: {},
      is_active: true,
      sort_order: 999,
    })
    .select("id")
    .single();

  if (bankError || !bank) {
    throw new Error(`Failed to create question bank: ${bankError?.message ?? "unknown"}`);
  }

  const bankId = bank.id as string;

  const { error: linkError } = await admin.from("question_bank_questions").insert({
    bank_id: bankId,
    question_id: questionId,
    position: 1,
  });
  if (linkError) {
    throw new Error(`Failed to link question to bank: ${linkError.message}`);
  }

  return { bankId, bankSlug, questionId };
}

async function createSessionWithQuestion(studentId: string, bank: BankAndQuestion): Promise<string> {
  const { data: session, error: sessionError } = await admin
    .from("sessions")
    .insert({
      student_id: studentId,
      mode: "practice",
      total_questions: 1,
      correct_count: 0,
      bank_id: bank.bankId,
    })
    .select("id")
    .single();

  if (sessionError || !session) {
    throw new Error(`Failed to create session: ${sessionError?.message ?? "unknown"}`);
  }

  const sessionId = session.id as string;

  const { error: sessionQuestionError } = await admin.from("session_questions").insert({
    session_id: sessionId,
    question_id: bank.questionId,
    position: 1,
  });

  if (sessionQuestionError) {
    throw new Error(`Failed to create session question: ${sessionQuestionError.message}`);
  }

  return sessionId;
}

async function cleanupResources(resources: TestResources) {
  const { userId, bankId, questionId, sessionId } = resources;

  if (sessionId) {
    await admin.from("sessions").delete().eq("id", sessionId);
  }

  if (bankId) {
    await admin.from("question_banks").delete().eq("id", bankId);
  }

  if (questionId) {
    await admin.from("questions").delete().eq("id", questionId);
  }

  if (userId) {
    await admin.auth.admin.deleteUser(userId);
  }
}

async function postEdgeFunction(name: string, accessToken: string, body: Record<string, unknown>) {
  const url = `${supabaseUrl.replace(/\/$/, "")}/functions/v1/${name}`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify(body),
  });

  const json = await res.json().catch(() => ({}));
  return { status: res.status, json };
}

function requireFunctionDeployed(status: number, json: unknown, functionName: string) {
  const payload = JSON.stringify(json);
  if (status === 404 && payload.includes("Requested function was not found")) {
    throw new Error(
      `${functionName} is not deployed to this Supabase project. Deploy the edge function before running cloud E2E.
Run: ENV_FILE=web/admin-dashboard/.env.local ai-coach/scripts/deploy-cloud.sh`,
    );
  }
}

function parseAttemptIdAndCorrect(json: unknown): { attemptId: string; isCorrect: boolean } {
  const payload = json as Record<string, unknown>;
  const attemptId = (payload.attemptId ?? payload.attempt_id) as string | undefined;
  const isCorrect = (payload.isCorrect ?? payload.is_correct) as boolean | undefined;

  if (typeof isCorrect !== "boolean") {
    throw new Error(`submit_attempt response missing isCorrect. Keys: ${Object.keys(payload).join(", ")}`);
  }
  if (typeof attemptId !== "string" || attemptId.length === 0) {
    throw new Error(
      `submit_attempt response missing attemptId. Keys: ${Object.keys(payload).join(", ")}. Deploy updated submit_attempt.`,
    );
  }

  return { attemptId, isCorrect };
}

Deno.test({
  name: "cloud e2e: submit_attempt enqueues attempt_insight job",
  sanitizeResources: false,
  sanitizeOps: false,
  fn: async () => {
    const resources: TestResources = {};

    try {
      const testUser = await createTestUser();
      resources.userId = testUser.id;

      const bank = await createBankAndQuestion();
      resources.bankId = bank.bankId;
      resources.questionId = bank.questionId;

      const sessionId = await createSessionWithQuestion(testUser.id, bank);
      resources.sessionId = sessionId;

      const { status, json } = await postEdgeFunction("submit_attempt", testUser.accessToken, {
        session_id: sessionId,
        question_id: bank.questionId,
        answer: "B",
        duration_ms: 5000,
        skipped: false,
        student_selected_step_index: 0,
        student_selected_step_is_unknown: false,
      });

      if (status !== 200) {
        requireFunctionDeployed(status, json, "submit_attempt");
        throw new Error(`submit_attempt failed: HTTP ${status} ${JSON.stringify(json)}`);
      }

      const { attemptId, isCorrect } = parseAttemptIdAndCorrect(json);
      assertEquals(isCorrect, false);

      const job = await retry(async () => {
        const { data, error } = await admin
          .from("ai_jobs")
          .select("id, status, kind")
          .eq("attempt_id", attemptId)
          .eq("kind", "attempt_insight")
          .maybeSingle();
        if (error) {
          throw new Error(error.message);
        }
        if (!data) {
          throw new Error("job_not_found");
        }
        return data;
      });

      assertEquals(job.kind, "attempt_insight");
      assertExists(job.id);
    } finally {
      await cleanupResources(resources);
    }
  },
});

Deno.test({
  name: "cloud e2e: set_attempt_step updates attempt selection and bumps job",
  sanitizeResources: false,
  sanitizeOps: false,
  fn: async () => {
    const resources: TestResources = {};

    try {
      const testUser = await createTestUser();
      resources.userId = testUser.id;

      const bank = await createBankAndQuestion();
      resources.bankId = bank.bankId;
      resources.questionId = bank.questionId;

      const sessionId = await createSessionWithQuestion(testUser.id, bank);
      resources.sessionId = sessionId;

      const { status, json } = await postEdgeFunction("submit_attempt", testUser.accessToken, {
        session_id: sessionId,
        question_id: bank.questionId,
        answer: "B",
        duration_ms: 5000,
        skipped: false,
        // No step selection initially.
      });

      if (status !== 200) {
        requireFunctionDeployed(status, json, "submit_attempt");
        throw new Error(`submit_attempt failed: HTTP ${status} ${JSON.stringify(json)}`);
      }

      const { attemptId, isCorrect } = parseAttemptIdAndCorrect(json);
      assertEquals(isCorrect, false);

      const jobBefore = await retry(async () => {
        const { data, error } = await admin
          .from("ai_jobs")
          .select("id, status, kind, run_after")
          .eq("attempt_id", attemptId)
          .eq("kind", "attempt_insight")
          .maybeSingle();
        if (error) {
          throw new Error(error.message);
        }
        if (!data) {
          throw new Error("job_not_found");
        }
        return data as { id: string; status: string; kind: string; run_after: string };
      });

      await delay(1100);

      const { status: setStatus, json: setJson } = await postEdgeFunction("set_attempt_step", testUser.accessToken, {
        attempt_id: attemptId,
        student_selected_step_index: 2,
        student_selected_step_is_unknown: false,
      });

      if (setStatus !== 200) {
        requireFunctionDeployed(setStatus, setJson, "set_attempt_step");
        throw new Error(`set_attempt_step failed: HTTP ${setStatus} ${JSON.stringify(setJson)}`);
      }

      const attemptRow = await retry(async () => {
        const { data, error } = await admin
          .from("attempts")
          .select("id, student_selected_step_index, student_selected_step_is_unknown")
          .eq("id", attemptId)
          .maybeSingle();
        if (error) {
          throw new Error(error.message);
        }
        if (!data) {
          throw new Error("attempt_not_found");
        }
        return data as {
          id: string;
          student_selected_step_index: number | null;
          student_selected_step_is_unknown: boolean;
        };
      });

      assertEquals(attemptRow.student_selected_step_index, 2);
      assertEquals(attemptRow.student_selected_step_is_unknown, false);

      const { data: jobAfter, error: jobAfterError } = await admin
        .from("ai_jobs")
        .select("id, status, run_after")
        .eq("id", jobBefore.id)
        .maybeSingle();

      if (jobAfterError) {
        throw new Error(jobAfterError.message);
      }

      if (jobAfter && jobAfter.status === "queued") {
        // If a worker is running, job may have moved to running/done. In that case, we only assert the attempt update.
        const before = new Date(jobBefore.run_after).getTime();
        const after = new Date(jobAfter.run_after as string).getTime();
        if (Number.isFinite(before) && Number.isFinite(after)) {
          if (after < before) {
            throw new Error(`Expected run_after to bump forward (before=${jobBefore.run_after}, after=${jobAfter.run_after})`);
          }
        }
      }
    } finally {
      await cleanupResources(resources);
    }
  },
});

Deno.test({
  name: "cloud e2e: coach_chat writes user message and enqueues coach_reply job",
  sanitizeResources: false,
  sanitizeOps: false,
  fn: async () => {
    const resources: TestResources = {};

    try {
      const testUser = await createTestUser();
      resources.userId = testUser.id;

      const text = `E2E coach chat (${Date.now()})`;
      const { status, json } = await postEdgeFunction("coach_chat", testUser.accessToken, {
        text,
        linked_attempt_id: null,
      });

      if (status !== 200) {
        requireFunctionDeployed(status, json, "coach_chat");
        throw new Error(`coach_chat failed: HTTP ${status} ${JSON.stringify(json)}`);
      }

      const userMessageId = (json as Record<string, unknown>).userMessageId as string;
      assertExists(userMessageId);

      const message = await retry(async () => {
        const { data, error } = await admin
          .from("coach_thread_messages")
          .select("id, student_id, role, content")
          .eq("id", userMessageId)
          .maybeSingle();
        if (error) {
          throw new Error(error.message);
        }
        if (!data) {
          throw new Error("message_not_found");
        }
        return data as {
          id: string;
          student_id: string;
          role: string;
          content: { text?: string };
        };
      });

      assertEquals(message.student_id, testUser.id);
      assertEquals(message.role, "user");
      assertEquals(message.content.text, text);

      const job = await retry(async () => {
        const { data, error } = await admin
          .from("ai_jobs")
          .select("id, status, kind")
          .eq("student_id", testUser.id)
          .eq("kind", "coach_reply")
          .order("created_at", { ascending: false })
          .limit(1)
          .maybeSingle();
        if (error) {
          throw new Error(error.message);
        }
        if (!data) {
          throw new Error("job_not_found");
        }
        return data;
      });

      assertEquals(job.kind, "coach_reply");
      assertExists(job.id);
    } finally {
      await cleanupResources(resources);
    }
  },
});

Deno.test({
  name: "cloud e2e: coach_chat supports linked_attempt_id",
  sanitizeResources: false,
  sanitizeOps: false,
  fn: async () => {
    const resources: TestResources = {};

    try {
      const testUser = await createTestUser();
      resources.userId = testUser.id;

      const bank = await createBankAndQuestion();
      resources.bankId = bank.bankId;
      resources.questionId = bank.questionId;

      const sessionId = await createSessionWithQuestion(testUser.id, bank);
      resources.sessionId = sessionId;

      const { status: submitStatus, json: submitJson } = await postEdgeFunction("submit_attempt", testUser.accessToken, {
        session_id: sessionId,
        question_id: bank.questionId,
        answer: "B",
        duration_ms: 1000,
        skipped: false,
        student_selected_step_is_unknown: true,
      });

      if (submitStatus !== 200) {
        requireFunctionDeployed(submitStatus, submitJson, "submit_attempt");
        throw new Error(`submit_attempt failed: HTTP ${submitStatus} ${JSON.stringify(submitJson)}`);
      }

      const { attemptId } = parseAttemptIdAndCorrect(submitJson);

      const text = `E2E linked attempt (${Date.now()})`;
      const { status: chatStatus, json: chatJson } = await postEdgeFunction("coach_chat", testUser.accessToken, {
        text,
        linked_attempt_id: attemptId,
      });

      if (chatStatus !== 200) {
        requireFunctionDeployed(chatStatus, chatJson, "coach_chat");
        throw new Error(`coach_chat failed: HTTP ${chatStatus} ${JSON.stringify(chatJson)}`);
      }

      const userMessageId = (chatJson as Record<string, unknown>).userMessageId as string;
      assertExists(userMessageId);

      const message = await retry(async () => {
        const { data, error } = await admin
          .from("coach_thread_messages")
          .select("id, student_id, role, content, linked_attempt_id")
          .eq("id", userMessageId)
          .maybeSingle();
        if (error) {
          throw new Error(error.message);
        }
        if (!data) {
          throw new Error("message_not_found");
        }
        return data as {
          id: string;
          student_id: string;
          role: string;
          content: { text?: string };
          linked_attempt_id: string | null;
        };
      });

      assertEquals(message.student_id, testUser.id);
      assertEquals(message.role, "user");
      assertEquals(message.content.text, text);
      assertEquals(message.linked_attempt_id, attemptId);
    } finally {
      await cleanupResources(resources);
    }
  },
});
