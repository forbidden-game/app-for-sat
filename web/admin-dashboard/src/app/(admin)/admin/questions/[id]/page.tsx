"use client";

import { useEffect, useState } from "react";
import { useRouter, useParams } from "next/navigation";
import { getSupabaseClient } from "@/lib/supabaseClient";
import { getQuestion, updateQuestion, type Question, type QuestionInput, type OptionInput } from "../actions";
import { QuestionForm } from "../QuestionForm";
import { AssetUploader } from "../AssetUploader";

export default function EditQuestionPage() {
  const supabase = getSupabaseClient();
  const router = useRouter();
  const params = useParams();
  const questionId = params.id as string;

  const [question, setQuestion] = useState<Question | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    async function loadQuestion() {
      if (!supabase || !questionId) return;

      const { data: sessionData } = await supabase.auth.getSession();
      const session = sessionData.session;
      if (!session) {
        setError("You are not signed in.");
        setLoading(false);
        return;
      }

      try {
        const data = await getQuestion(session.access_token, questionId);
        setQuestion(data);
      } catch (err) {
        setError(err instanceof Error ? err.message : "Failed to load question.");
      } finally {
        setLoading(false);
      }
    }
    loadQuestion();
  }, [supabase, questionId]);

  async function handleSubmit(input: QuestionInput, options: OptionInput[], tagIds: string[]) {
    if (!supabase) return;
    setSaving(true);
    setError(null);

    const { data: sessionData } = await supabase.auth.getSession();
    const session = sessionData.session;
    if (!session) {
      setError("You are not signed in.");
      setSaving(false);
      return;
    }

    try {
      const updated = await updateQuestion(session.access_token, questionId, input, options, tagIds);
      setQuestion(updated);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to update question.");
    } finally {
      setSaving(false);
    }
  }

  function handleCancel() {
    router.push("/admin/questions");
  }

  if (loading) {
    return (
      <main className="mx-auto max-w-[1440px] px-6 py-12">
        <p className="text-sm text-[color:var(--ink-muted)]" role="status" aria-live="polite">
          Loading question…
        </p>
      </main>
    );
  }

  if (error && !question) {
    return (
      <main className="mx-auto max-w-[1440px] px-6 py-12">
        <p className="text-sm text-[color:var(--danger-strong)]" role="alert">
          {error}
        </p>
      </main>
    );
  }

  if (!question) {
    return (
      <main className="mx-auto max-w-[1440px] px-6 py-12">
        <p className="text-sm text-[color:var(--ink-muted)]" role="status" aria-live="polite">
          Question not found.
        </p>
      </main>
    );
  }

  return (
    <main className="mx-auto flex max-w-[1440px] flex-col gap-6 px-6 pb-10 pt-8">
      <header>
        <p className="text-[11px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">Admin Console</p>
        <h1 className="text-2xl font-semibold text-[color:var(--ink)]">Edit Question</h1>
        <p className="text-sm text-[color:var(--ink-muted)]">
          ID:{" "}
          <code className="rounded bg-[color:var(--surface-soft)] px-1 py-0.5 text-xs">{questionId}</code>
        </p>
      </header>

      {error ? (
        <div
          className="rounded-2xl border border-[color:var(--danger)] bg-[color:var(--surface)] px-4 py-3 text-sm text-[color:var(--danger-strong)]"
          role="alert"
        >
          {error}
        </div>
      ) : null}

      <div className="rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface)] p-6">
        <QuestionForm initialData={question} onSubmit={handleSubmit} onCancel={handleCancel} saving={saving} />
      </div>

      <div className="rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface)] p-6">
        <AssetUploader questionId={questionId} />
      </div>
    </main>
  );
}
