"use client";

import { useCallback, useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import { getSupabaseClient } from "@/lib/supabaseClient";
import {
  addQuestionToBank,
  getAvailableSubjects,
  getBankInfo,
  listBankQuestions,
  removeQuestionFromBank,
  reorderBankQuestions,
  searchAvailableQuestions,
  type AvailableQuestion,
  type BankQuestion,
} from "./actions";

function truncate(text: string, maxLength: number) {
  if (text.length <= maxLength) return text;
  return text.slice(0, maxLength) + "…";
}

export default function BankQuestionsPage() {
  const supabase = getSupabaseClient();
  const params = useParams();
  const bankId = params.id as string;

  const [bankInfo, setBankInfo] = useState<{ title: string; slug: string } | null>(null);
  const [questions, setQuestions] = useState<BankQuestion[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const [searchQuery, setSearchQuery] = useState("");
  const [searchSubject, setSearchSubject] = useState("");
  const [availableSubjects, setAvailableSubjects] = useState<string[]>([]);
  const [searchResults, setSearchResults] = useState<AvailableQuestion[]>([]);
  const [searching, setSearching] = useState(false);
  const [showSearch, setShowSearch] = useState(false);
  const [hasSearched, setHasSearched] = useState(false);

  const loadData = useCallback(async () => {
    if (!supabase) return;

    const { data: sessionData } = await supabase.auth.getSession();
    const session = sessionData.session;
    if (!session) {
      setError("You are not signed in.");
      setLoading(false);
      return;
    }

    try {
      const [info, items, subjects] = await Promise.all([
        getBankInfo(session.access_token, bankId),
        listBankQuestions(session.access_token, bankId),
        getAvailableSubjects(session.access_token),
      ]);
      setBankInfo(info);
      setQuestions(items);
      setAvailableSubjects(subjects);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load data.");
    } finally {
      setLoading(false);
    }
  }, [supabase, bankId]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  async function handleSearch() {
    if (!supabase) return;

    const { data: sessionData } = await supabase.auth.getSession();
    const session = sessionData.session;
    if (!session) return;

    setSearching(true);
    setHasSearched(true);
    try {
      const results = await searchAvailableQuestions(
        session.access_token,
        bankId,
        { search: searchQuery, subject: searchSubject },
      );
      setSearchResults(results);
    } catch {
      setSearchResults([]);
    } finally {
      setSearching(false);
    }
  }

  async function handleAddQuestion(questionId: string) {
    if (!supabase) return;

    const { data: sessionData } = await supabase.auth.getSession();
    const session = sessionData.session;
    if (!session) return;

    setSaving(true);
    try {
      await addQuestionToBank(session.access_token, bankId, questionId);
      setSearchResults((prev) => prev.filter((q) => q.id !== questionId));
      await loadData();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to add question.");
    } finally {
      setSaving(false);
    }
  }

  async function handleRemoveQuestion(questionId: string) {
    if (!supabase) return;
    const confirmed = window.confirm("Remove this question from the bank?");
    if (!confirmed) return;

    const { data: sessionData } = await supabase.auth.getSession();
    const session = sessionData.session;
    if (!session) return;

    setSaving(true);
    try {
      await removeQuestionFromBank(session.access_token, bankId, questionId);
      setQuestions((prev) => prev.filter((q) => q.question_id !== questionId));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to remove question.");
    } finally {
      setSaving(false);
    }
  }

  async function handleMoveUp(index: number) {
    if (index <= 0) return;
    const newQuestions = [...questions];
    [newQuestions[index - 1], newQuestions[index]] = [newQuestions[index], newQuestions[index - 1]];
    await saveOrder(newQuestions);
  }

  async function handleMoveDown(index: number) {
    if (index >= questions.length - 1) return;
    const newQuestions = [...questions];
    [newQuestions[index], newQuestions[index + 1]] = [newQuestions[index + 1], newQuestions[index]];
    await saveOrder(newQuestions);
  }

  async function saveOrder(newQuestions: BankQuestion[]) {
    if (!supabase) return;

    const { data: sessionData } = await supabase.auth.getSession();
    const session = sessionData.session;
    if (!session) return;

    const items = newQuestions.map((q, i) => ({
      question_id: q.question_id,
      position: i + 1,
    }));

    setSaving(true);
    try {
      await reorderBankQuestions(session.access_token, bankId, items);
      setQuestions(newQuestions.map((q, i) => ({ ...q, position: i + 1 })));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to reorder.");
    } finally {
      setSaving(false);
    }
  }

  if (loading) {
    return (
      <main className="mx-auto max-w-4xl px-6 py-12">
        <p className="text-sm text-[color:var(--ink-muted)]" role="status" aria-live="polite">
          Loading…
        </p>
      </main>
    );
  }

  return (
    <main className="mx-auto flex max-w-4xl flex-col gap-6 px-6 py-8">
      <header className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-xs uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
            Admin Console
          </p>
          <h1 className="text-2xl font-semibold text-[color:var(--ink)]">
            {bankInfo?.title ?? "Bank"} Questions
          </h1>
          <p className="text-sm text-[color:var(--ink-muted)]">
            Manage questions in this bank. Drag to reorder.
          </p>
        </div>
        <div className="flex gap-2">
          <button
            type="button"
            onClick={() => setShowSearch(!showSearch)}
            className="rounded-lg border border-[color:var(--border)] px-4 py-2 text-sm text-[color:var(--ink)]"
          >
            {showSearch ? "Hide Search" : "+ Add Questions"}
          </button>
          <Link
            href="/admin/banks"
            className="rounded-lg border border-[color:var(--border)] px-4 py-2 text-sm text-[color:var(--ink)]"
          >
            Back to Banks
          </Link>
        </div>
      </header>

      {error && (
        <div
          className="rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800"
          role="alert"
        >
          {error}
        </div>
      )}

      {showSearch && (
        <div className="rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface)] p-4">
          <div className="flex flex-wrap gap-2 mb-4">
            <select
              name="searchSubject"
              className="rounded-lg border border-[color:var(--border)] px-3 py-2 text-sm"
              value={searchSubject}
              onChange={(e) => setSearchSubject(e.target.value)}
              aria-label="Filter by subject"
            >
              <option value="">All Subjects</option>
              {availableSubjects.map((subject) => (
                <option key={subject} value={subject}>
                  {subject}
                </option>
              ))}
            </select>
            <input
              type="text"
              name="searchQuery"
              className="flex-1 min-w-[200px] rounded-lg border border-[color:var(--border)] px-3 py-2 text-sm"
              placeholder="Search by question text…"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && handleSearch()}
              aria-label="Search questions"
              autoComplete="off"
            />
            <button
              type="button"
              onClick={handleSearch}
              disabled={searching}
              className="rounded-lg bg-[color:var(--accent)] px-4 py-2 text-sm font-semibold text-white transition hover:bg-[color:var(--accent-strong)]"
            >
              {searching ? "…" : "Search"}
            </button>
          </div>
          {searchResults.length > 0 ? (
            <div className="flex flex-col gap-2 max-h-72 overflow-y-auto">
              {searchResults.map((q) => (
                <div
                  key={q.id}
                  className="flex items-center justify-between rounded-lg border border-[color:var(--border)] p-2 hover:bg-[color:var(--surface-soft)]"
                >
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-[color:var(--ink)] truncate">{truncate(q.stem, 60)}</p>
                    <p className="text-xs text-[color:var(--ink-muted)]">
                      {q.subject} / {q.module} / D{q.difficulty}
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() => handleAddQuestion(q.id)}
                    disabled={saving}
                    className="ml-2 rounded-full border border-green-200 px-3 py-1 text-xs text-green-700 hover:bg-green-50"
                  >
                    Add
                  </button>
                </div>
              ))}
            </div>
          ) : hasSearched ? (
            <div
              className="rounded-xl border border-dashed border-[color:var(--border)] p-6 text-center"
              role="status"
              aria-live="polite"
            >
              <p className="text-sm text-[color:var(--ink-muted)] mb-2">No questions found</p>
              <p className="text-xs text-[color:var(--ink-muted)] mb-3">
                {availableSubjects.length === 0
                  ? "There are no questions in the database yet."
                  : "Try adjusting your search filters."}
              </p>
              {availableSubjects.length === 0 && (
                <div className="flex justify-center gap-2">
                  <Link
                    href="/admin/questions/new"
                    className="rounded-lg border border-[color:var(--border)] px-3 py-1.5 text-xs text-[color:var(--ink)] hover:bg-[color:var(--surface-soft)]"
                  >
                    Create Question
                  </Link>
                  <Link
                    href="/admin/questions/import"
                    className="rounded-lg bg-[color:var(--accent)] px-3 py-1.5 text-xs font-semibold text-white transition hover:bg-[color:var(--accent-strong)]"
                  >
                    Import Questions
                  </Link>
                </div>
              )}
            </div>
          ) : (
            <p className="text-xs text-[color:var(--ink-muted)] text-center py-2">
              Click Search to find questions to add
            </p>
          )}
        </div>
      )}

      <div className="rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface)]">
        {questions.length === 0 ? (
          <div
            className="p-6 text-center text-sm text-[color:var(--ink-muted)]"
            role="status"
            aria-live="polite"
          >
            No questions in this bank yet.
          </div>
        ) : (
          <div className="divide-y divide-[color:var(--border)]">
            {questions.map((q, index) => (
              <div
                key={q.question_id}
                className="flex items-center gap-3 p-3 hover:bg-[color:var(--surface-soft)]"
              >
                <div className="flex flex-col gap-1">
                  <button
                    type="button"
                    onClick={() => handleMoveUp(index)}
                    disabled={index === 0 || saving}
                    className="text-xs text-[color:var(--ink-muted)] hover:text-[color:var(--ink)] disabled:opacity-30"
                    aria-label="Move question up"
                  >
                    ▲
                  </button>
                  <button
                    type="button"
                    onClick={() => handleMoveDown(index)}
                    disabled={index === questions.length - 1 || saving}
                    className="text-xs text-[color:var(--ink-muted)] hover:text-[color:var(--ink)] disabled:opacity-30"
                    aria-label="Move question down"
                  >
                    ▼
                  </button>
                </div>
                <span className="w-8 text-center text-sm font-medium text-[color:var(--ink-muted)]">
                  {q.position}
                </span>
                <div className="flex-1 min-w-0">
                  <p className="text-sm text-[color:var(--ink)]">{truncate(q.stem, 80)}</p>
                  <p className="text-xs text-[color:var(--ink-muted)]">
                    {q.subject} / {q.question_type} / D{q.difficulty}
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => handleRemoveQuestion(q.question_id)}
                  disabled={saving}
                  className="rounded-full border border-red-200 px-3 py-1 text-xs text-red-700 hover:bg-red-50"
                >
                  Remove
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      <div className="text-xs text-[color:var(--ink-muted)]">
        Total: {questions.length} questions
      </div>
    </main>
  );
}
