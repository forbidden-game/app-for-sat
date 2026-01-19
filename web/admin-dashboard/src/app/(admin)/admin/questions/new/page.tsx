"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { getSupabaseClient } from "@/lib/supabaseClient";
import { createQuestion, type QuestionInput, type OptionInput } from "../actions";
import { QuestionForm } from "../QuestionForm";

export default function NewQuestionPage() {
  const supabase = getSupabaseClient();
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

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
      const created = await createQuestion(session.access_token, input, options, tagIds);
      router.push(`/admin/questions/${created.id}`);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to create question.");
      setSaving(false);
    }
  }

  function handleCancel() {
    router.push("/admin/questions");
  }

  return (
    <main className="mx-auto flex max-w-[1280px] flex-col gap-6 px-6 pb-10 pt-8">
      <header>
        <p className="text-[11px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">Admin Console</p>
        <h1 className="text-2xl font-semibold text-[color:var(--ink)]">New Question</h1>
        <p className="text-sm text-[color:var(--ink-muted)]">Create a new question in the question bank.</p>
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
        <QuestionForm onSubmit={handleSubmit} onCancel={handleCancel} saving={saving} />
      </div>
    </main>
  );
}
