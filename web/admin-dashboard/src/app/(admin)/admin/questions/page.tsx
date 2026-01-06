"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { getSupabaseClient } from "@/lib/supabaseClient";
import {
  deleteQuestion,
  getDistinctValues,
  listQuestions,
  listQuestionTypes,
  type ListQuestionsResult,
  type QuestionType,
} from "./actions";

function truncate(text: string, maxLength: number) {
  if (text.length <= maxLength) return text;
  return text.slice(0, maxLength) + "...";
}

function formatDate(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

export default function QuestionsPage() {
  const supabase = getSupabaseClient();
  const [result, setResult] = useState<ListQuestionsResult | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [deleting, setDeleting] = useState<string | null>(null);

  const [search, setSearch] = useState("");
  const [subject, setSubject] = useState("");
  const [module, setModule] = useState("");
  const [difficulty, setDifficulty] = useState<number | "">("");
  const [questionType, setQuestionType] = useState("");
  const [page, setPage] = useState(1);

  const [subjects, setSubjects] = useState<string[]>([]);
  const [modules, setModules] = useState<string[]>([]);
  const [questionTypes, setQuestionTypes] = useState<QuestionType[]>([]);

  const loadQuestions = useCallback(async () => {
    if (!supabase) return;

    const { data: sessionData } = await supabase.auth.getSession();
    const session = sessionData.session;
    if (!session) {
      setError("You are not signed in.");
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      const data = await listQuestions(session.access_token, {
        page,
        pageSize: 20,
        search: search || undefined,
        subject: subject || undefined,
        module: module || undefined,
        difficulty: difficulty || undefined,
        question_type: questionType || undefined,
      });
      setResult(data);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load questions.");
    } finally {
      setLoading(false);
    }
  }, [supabase, page, search, subject, module, difficulty, questionType]);

  useEffect(() => {
    loadQuestions();
  }, [loadQuestions]);

  useEffect(() => {
    async function loadFilters() {
      if (!supabase) return;
      const { data: sessionData } = await supabase.auth.getSession();
      const session = sessionData.session;
      if (!session) return;

      try {
        const [subjectList, moduleList, typeList] = await Promise.all([
          getDistinctValues(session.access_token, "subject"),
          getDistinctValues(session.access_token, "module"),
          listQuestionTypes(session.access_token),
        ]);
        setSubjects(subjectList);
        setModules(moduleList);
        setQuestionTypes(typeList);
      } catch {
      }
    }
    loadFilters();
  }, [supabase]);

  async function handleDelete(questionId: string, stem: string) {
    if (!supabase) return;
    const confirmed = window.confirm(
      `Delete this question?\n\n"${truncate(stem, 100)}"`,
    );
    if (!confirmed) return;

    const { data: sessionData } = await supabase.auth.getSession();
    const session = sessionData.session;
    if (!session) return;

    try {
      setDeleting(questionId);
      await deleteQuestion(session.access_token, questionId);
      await loadQuestions();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to delete question.");
    } finally {
      setDeleting(null);
    }
  }

  function handleSearch(e: React.FormEvent) {
    e.preventDefault();
    setPage(1);
    loadQuestions();
  }

  function clearFilters() {
    setSearch("");
    setSubject("");
    setModule("");
    setDifficulty("");
    setQuestionType("");
    setPage(1);
  }

  if (error && !result) {
    return (
      <main className="mx-auto max-w-6xl px-6 py-12">
        <p className="text-sm text-red-600">{error}</p>
      </main>
    );
  }

  return (
    <main className="mx-auto flex max-w-6xl flex-col gap-6 px-6 py-8">
      <header className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-xs uppercase tracking-[0.2em] text-zinc-400">
            Admin Console
          </p>
          <h1 className="text-2xl font-semibold text-zinc-900">Questions</h1>
          <p className="text-sm text-zinc-500">
            Manage questions in the question bank.
          </p>
        </div>
        <div className="flex gap-2">
          <Link
            href="/admin/questions/import"
            className="rounded-lg border border-zinc-200 px-4 py-2 text-sm text-zinc-700 transition hover:border-zinc-300"
          >
            Import
          </Link>
          <Link
            href="/admin/questions/new"
            className="rounded-lg bg-zinc-900 px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-zinc-800"
          >
            + New Question
          </Link>
        </div>
      </header>

      {error ? (
        <div className="rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
          {error}
        </div>
      ) : null}

      <form
        onSubmit={handleSearch}
        className="flex flex-wrap items-end gap-3 rounded-2xl border border-zinc-200 bg-white p-4"
      >
        <label className="grid gap-1 text-sm">
          Search
          <input
            type="text"
            className="w-48 rounded-lg border border-zinc-200 px-3 py-2 text-sm"
            placeholder="Search stem..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </label>
        <label className="grid gap-1 text-sm">
          Subject
          <select
            className="rounded-lg border border-zinc-200 px-3 py-2 text-sm"
            value={subject}
            onChange={(e) => setSubject(e.target.value)}
          >
            <option value="">All</option>
            {subjects.map((s) => (
              <option key={s} value={s}>
                {s}
              </option>
            ))}
          </select>
        </label>
        <label className="grid gap-1 text-sm">
          Module
          <select
            className="rounded-lg border border-zinc-200 px-3 py-2 text-sm"
            value={module}
            onChange={(e) => setModule(e.target.value)}
          >
            <option value="">All</option>
            {modules.map((m) => (
              <option key={m} value={m}>
                {m}
              </option>
            ))}
          </select>
        </label>
        <label className="grid gap-1 text-sm">
          Difficulty
          <select
            className="rounded-lg border border-zinc-200 px-3 py-2 text-sm"
            value={difficulty}
            onChange={(e) =>
              setDifficulty(e.target.value ? Number(e.target.value) : "")
            }
          >
            <option value="">All</option>
            {[1, 2, 3, 4, 5].map((d) => (
              <option key={d} value={d}>
                {d}
              </option>
            ))}
          </select>
        </label>
        <label className="grid gap-1 text-sm">
          Type
          <select
            className="rounded-lg border border-zinc-200 px-3 py-2 text-sm"
            value={questionType}
            onChange={(e) => setQuestionType(e.target.value)}
          >
            <option value="">All</option>
            {questionTypes.map((qt) => (
              <option key={qt.name} value={qt.name}>
                {qt.display_name}
              </option>
            ))}
          </select>
        </label>
        <button
          type="submit"
          className="rounded-lg bg-zinc-900 px-4 py-2 text-sm font-semibold text-white"
        >
          Search
        </button>
        <button
          type="button"
          onClick={clearFilters}
          className="rounded-lg border border-zinc-200 px-4 py-2 text-sm text-zinc-700"
        >
          Clear
        </button>
      </form>

      <div className="overflow-hidden rounded-2xl border border-zinc-200 bg-white">
        <table className="w-full text-left text-sm text-zinc-700">
          <thead className="bg-zinc-50 text-xs uppercase tracking-wide text-zinc-500">
            <tr>
              <th className="px-4 py-3">Stem</th>
              <th className="px-4 py-3 w-24">Subject</th>
              <th className="px-4 py-3 w-24">Module</th>
              <th className="px-4 py-3 w-16">Diff</th>
              <th className="px-4 py-3 w-20">Type</th>
              <th className="px-4 py-3 w-24">Created</th>
              <th className="px-4 py-3 w-24">Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading && !result ? (
              <tr>
                <td colSpan={7} className="px-4 py-8 text-center text-zinc-500">
                  Loading...
                </td>
              </tr>
            ) : result?.questions.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-4 py-8 text-center text-zinc-500">
                  No questions found.
                </td>
              </tr>
            ) : (
              result?.questions.map((q) => (
                <tr
                  key={q.id}
                  className="border-t border-zinc-100 hover:bg-zinc-50"
                >
                  <td className="px-4 py-3">
                    <div className="font-medium text-zinc-900">
                      {truncate(q.stem, 60)}
                    </div>
                    {q.tags.length > 0 && (
                      <div className="mt-1 flex flex-wrap gap-1">
                        {q.tags.slice(0, 3).map((tag, i) => (
                          <span
                            key={i}
                            className="rounded-full bg-zinc-100 px-2 py-0.5 text-xs text-zinc-600"
                          >
                            {tag.name}
                          </span>
                        ))}
                        {q.tags.length > 3 && (
                          <span className="text-xs text-zinc-400">
                            +{q.tags.length - 3}
                          </span>
                        )}
                      </div>
                    )}
                  </td>
                  <td className="px-4 py-3 text-xs">{q.subject}</td>
                  <td className="px-4 py-3 text-xs">{q.module}</td>
                  <td className="px-4 py-3 text-center">{q.difficulty}</td>
                  <td className="px-4 py-3 text-xs">{q.question_type}</td>
                  <td className="px-4 py-3 text-xs text-zinc-500">
                    {formatDate(q.created_at)}
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex gap-2">
                      <Link
                        href={`/admin/questions/${q.id}`}
                        className="rounded-full border border-zinc-200 px-3 py-1 text-xs text-zinc-700 transition hover:border-zinc-300"
                      >
                        Edit
                      </Link>
                      <button
                        type="button"
                        onClick={() => handleDelete(q.id, q.stem)}
                        disabled={deleting === q.id}
                        className="rounded-full border border-red-200 px-3 py-1 text-xs text-red-700 transition hover:border-red-300 disabled:opacity-50"
                      >
                        {deleting === q.id ? "..." : "Del"}
                      </button>
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {result && result.totalPages > 1 && (
        <div className="flex items-center justify-between text-sm">
          <span className="text-zinc-500">
            Showing {(result.page - 1) * result.pageSize + 1}-
            {Math.min(result.page * result.pageSize, result.total)} of{" "}
            {result.total}
          </span>
          <div className="flex gap-2">
            <button
              type="button"
              onClick={() => setPage((p) => Math.max(1, p - 1))}
              disabled={page === 1}
              className="rounded-lg border border-zinc-200 px-3 py-1 text-zinc-700 disabled:opacity-50"
            >
              Previous
            </button>
            <span className="px-2 py-1 text-zinc-500">
              Page {result.page} of {result.totalPages}
            </span>
            <button
              type="button"
              onClick={() => setPage((p) => Math.min(result.totalPages, p + 1))}
              disabled={page >= result.totalPages}
              className="rounded-lg border border-zinc-200 px-3 py-1 text-zinc-700 disabled:opacity-50"
            >
              Next
            </button>
          </div>
        </div>
      )}
    </main>
  );
}
