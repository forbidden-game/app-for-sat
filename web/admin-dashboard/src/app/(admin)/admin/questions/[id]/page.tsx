"use client";

import { useEffect, useState } from "react";
import { useRouter, useParams } from "next/navigation";
import { getSupabaseClient } from "@/lib/supabaseClient";
import {
  getQuestion,
  updateQuestion,
  type Question,
  type QuestionInput,
  type OptionInput,
} from "../actions";
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

  async function handleSubmit(
    input: QuestionInput,
    options: OptionInput[],
    tagIds: string[],
  ) {
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
      const updated = await updateQuestion(
        session.access_token,
        questionId,
        input,
        options,
        tagIds,
      );
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
      <main className="mx-auto max-w-4xl px-6 py-12">
        <p className="text-sm text-zinc-500">Loading question...</p>
      </main>
    );
  }

  if (error && !question) {
    return (
      <main className="mx-auto max-w-4xl px-6 py-12">
        <p className="text-sm text-red-600">{error}</p>
      </main>
    );
  }

  if (!question) {
    return (
      <main className="mx-auto max-w-4xl px-6 py-12">
        <p className="text-sm text-zinc-500">Question not found.</p>
      </main>
    );
  }

  return (
    <main className="mx-auto flex max-w-4xl flex-col gap-6 px-6 py-8">
      <header>
        <p className="text-xs uppercase tracking-[0.2em] text-zinc-400">
          Admin Console
        </p>
        <h1 className="text-2xl font-semibold text-zinc-900">Edit Question</h1>
        <p className="text-sm text-zinc-500">
          ID: <code className="text-xs bg-zinc-100 px-1 py-0.5 rounded">{questionId}</code>
        </p>
      </header>

      {error && (
        <div className="rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
          {error}
        </div>
      )}

      <div className="rounded-2xl border border-zinc-200 bg-white p-6">
        <QuestionForm
          initialData={question}
          onSubmit={handleSubmit}
          onCancel={handleCancel}
          saving={saving}
        />
      </div>

      <div className="rounded-2xl border border-zinc-200 bg-white p-6">
        <AssetUploader questionId={questionId} />
      </div>
    </main>
  );
}
