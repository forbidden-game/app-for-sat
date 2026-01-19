"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { getSupabaseClient } from "@/lib/supabaseClient";
import {
  createQuestion,
  deleteQuestion,
  getDistinctValues,
  getQuestion,
  listQuestions,
  listQuestionTypes,
  updateQuestion,
  type ListQuestionsResult,
  type Question,
  type QuestionInput,
  type OptionInput,
  type QuestionType,
} from "./actions";
import { QuestionForm } from "./QuestionForm";
import { AssetUploader } from "./AssetUploader";

function truncate(text: string, maxLength: number) {
  if (text.length <= maxLength) return text;
  return text.slice(0, maxLength) + "…";
}

function formatDate(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
  }).format(date);
}

export default function QuestionsPage() {
  const supabase = getSupabaseClient();
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const [result, setResult] = useState<ListQuestionsResult | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [deleting, setDeleting] = useState<string | null>(null);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [drawerMode, setDrawerMode] = useState<"create" | "edit">("create");
  const [drawerLoading, setDrawerLoading] = useState(false);
  const [drawerSaving, setDrawerSaving] = useState(false);
  const [drawerError, setDrawerError] = useState<string | null>(null);
  const [selectedQuestion, setSelectedQuestion] = useState<Question | null>(null);
  const [selectedQuestionId, setSelectedQuestionId] = useState<string | null>(null);
  const requestIdRef = useRef(0);

  const [search, setSearch] = useState(() => searchParams.get("q") ?? "");
  const [subject, setSubject] = useState(() => searchParams.get("subject") ?? "");
  const [module, setModule] = useState(() => searchParams.get("module") ?? "");
  const [difficulty, setDifficulty] = useState<number | "">(() => {
    const value = searchParams.get("difficulty");
    const parsed = value ? Number(value) : NaN;
    return Number.isFinite(parsed) ? parsed : "";
  });
  const [questionType, setQuestionType] = useState(() => searchParams.get("type") ?? "");
  const [page, setPage] = useState(() => {
    const value = searchParams.get("page");
    const parsed = value ? Number(value) : NaN;
    return Number.isFinite(parsed) && parsed > 0 ? parsed : 1;
  });

  const [subjects, setSubjects] = useState<string[]>([]);
  const [modules, setModules] = useState<string[]>([]);
  const [questionTypes, setQuestionTypes] = useState<QuestionType[]>([]);

  const getAccessToken = useCallback(async () => {
    if (!supabase) {
      setError("Supabase not configured.");
      return null;
    }
    const { data: sessionData } = await supabase.auth.getSession();
    const session = sessionData.session;
    if (!session) {
      setError("You are not signed in.");
      return null;
    }
    return session.access_token;
  }, [supabase]);

  const loadQuestions = useCallback(async () => {
    const accessToken = await getAccessToken();
    if (!accessToken) {
      setLoading(false);
      return;
    }
    const requestId = requestIdRef.current + 1;
    requestIdRef.current = requestId;

    try {
      setLoading(true);
      const data = await listQuestions(accessToken, {
        page,
        pageSize: 20,
        search: search || undefined,
        subject: subject || undefined,
        module: module || undefined,
        difficulty: difficulty || undefined,
        question_type: questionType || undefined,
      });
      if (requestId !== requestIdRef.current) return;
      setResult(data);
      setError(null);
    } catch (err) {
      if (requestId !== requestIdRef.current) return;
      setError(err instanceof Error ? err.message : "Failed to load questions.");
    } finally {
      if (requestId === requestIdRef.current) {
        setLoading(false);
      }
    }
  }, [getAccessToken, page, search, subject, module, difficulty, questionType]);

  useEffect(() => {
    loadQuestions();
  }, [loadQuestions]);

  useEffect(() => {
    setSearch(searchParams.get("q") ?? "");
    setSubject(searchParams.get("subject") ?? "");
    setModule(searchParams.get("module") ?? "");
    setQuestionType(searchParams.get("type") ?? "");
    const nextDifficulty = searchParams.get("difficulty");
    const parsedDifficulty = nextDifficulty ? Number(nextDifficulty) : NaN;
    setDifficulty(Number.isFinite(parsedDifficulty) ? parsedDifficulty : "");
    const nextPage = searchParams.get("page");
    const parsedPage = nextPage ? Number(nextPage) : NaN;
    setPage(Number.isFinite(parsedPage) && parsedPage > 0 ? parsedPage : 1);
  }, [searchParams]);

  useEffect(() => {
    const nextParams = new URLSearchParams(searchParams);
    if (search) {
      nextParams.set("q", search);
    } else {
      nextParams.delete("q");
    }
    if (subject) {
      nextParams.set("subject", subject);
    } else {
      nextParams.delete("subject");
    }
    if (module) {
      nextParams.set("module", module);
    } else {
      nextParams.delete("module");
    }
    if (questionType) {
      nextParams.set("type", questionType);
    } else {
      nextParams.delete("type");
    }
    if (difficulty !== "") {
      nextParams.set("difficulty", String(difficulty));
    } else {
      nextParams.delete("difficulty");
    }
    if (page > 1) {
      nextParams.set("page", String(page));
    } else {
      nextParams.delete("page");
    }

    const nextQuery = nextParams.toString();
    const currentQuery = searchParams.toString();
    if (nextQuery !== currentQuery) {
      router.replace(nextQuery ? `${pathname}?${nextQuery}` : pathname, { scroll: false });
    }
  }, [search, subject, module, difficulty, questionType, page, pathname, router, searchParams]);

  useEffect(() => {
    async function loadFilters() {
      const accessToken = await getAccessToken();
      if (!accessToken) return;

      try {
        const [subjectList, moduleList, typeList] = await Promise.all([
          getDistinctValues(accessToken, "subject"),
          getDistinctValues(accessToken, "module"),
          listQuestionTypes(accessToken),
        ]);
        setSubjects(subjectList);
        setModules(moduleList);
        setQuestionTypes(typeList);
      } catch {
      }
    }
    loadFilters();
  }, [getAccessToken]);

  function openCreateDrawer() {
    setDrawerMode("create");
    setSelectedQuestion(null);
    setSelectedQuestionId(null);
    setDrawerError(null);
    setDrawerOpen(true);
  }

  async function openEditDrawer(questionId: string) {
    const accessToken = await getAccessToken();
    if (!accessToken) return;

    setDrawerMode("edit");
    setSelectedQuestion(null);
    setSelectedQuestionId(questionId);
    setDrawerError(null);
    setDrawerOpen(true);
    setDrawerLoading(true);

    try {
      const question = await getQuestion(accessToken, questionId);
      setSelectedQuestion(question);
    } catch (err) {
      setDrawerError(err instanceof Error ? err.message : "Failed to load question.");
    } finally {
      setDrawerLoading(false);
    }
  }

  function closeDrawer() {
    setDrawerOpen(false);
  }

  async function handleDelete(questionId: string, stem: string) {
    const confirmed = window.confirm(`Delete this question?\n\n"${truncate(stem, 100)}"`);
    if (!confirmed) return;

    const accessToken = await getAccessToken();
    if (!accessToken) return;

    try {
      setDeleting(questionId);
      await deleteQuestion(accessToken, questionId);
      await loadQuestions();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to delete question.");
    } finally {
      setDeleting(null);
    }
  }

  async function handleDrawerSubmit(input: QuestionInput, options: OptionInput[], tagIds: string[]) {
    const accessToken = await getAccessToken();
    if (!accessToken) return;

    setDrawerSaving(true);
    setDrawerError(null);

    try {
      if (drawerMode === "create") {
        const created = await createQuestion(accessToken, input, options, tagIds);
        setSelectedQuestion(created);
        setSelectedQuestionId(created.id);
      } else if (selectedQuestionId) {
        const updated = await updateQuestion(accessToken, selectedQuestionId, input, options, tagIds);
        setSelectedQuestion(updated);
      }

      await loadQuestions();
      closeDrawer();
    } catch (err) {
      setDrawerError(err instanceof Error ? err.message : "Failed to save question.");
    } finally {
      setDrawerSaving(false);
    }
  }

  function handleDrawerCancel() {
    closeDrawer();
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
      <main className="mx-auto max-w-[1280px] px-6 py-12">
        <p className="text-sm text-[color:var(--danger-strong)]" role="alert">
          {error}
        </p>
      </main>
    );
  }

  return (
    <main className="mx-auto flex max-w-[1280px] flex-col gap-6 px-6 pb-10 pt-8">
      <header className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-xs font-medium text-[color:var(--ink-muted)]">Admin Console</p>
          <h1 className="text-2xl font-semibold tracking-tight text-[color:var(--ink)]">Questions</h1>
          <p className="text-sm text-[color:var(--ink-muted)]">Manage questions in the question bank.</p>
        </div>
        <div className="flex gap-2">
          <Link
            href="/admin/questions/import"
            className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-4 py-2 text-xs font-medium text-[color:var(--ink-muted)] transition hover:border-[color:var(--accent)] hover:text-[color:var(--ink)]"
          >
            Import
          </Link>
          <button
            className="rounded-full bg-[color:var(--accent)] px-4 py-2 text-xs font-semibold text-white transition hover:bg-[color:var(--accent-strong)]"
            onClick={openCreateDrawer}
            type="button"
          >
            New Question
          </button>
        </div>
      </header>

      {error ? (
        <div
          className="rounded-2xl border border-[color:var(--danger)] bg-[color:var(--surface)] px-4 py-3 text-sm text-[color:var(--danger-strong)]"
          role="alert"
        >
          {error}
        </div>
      ) : null}

      <form
        onSubmit={handleSearch}
        className="flex flex-wrap items-end gap-3 rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] p-4"
      >
        <label className="grid gap-1 text-xs font-medium text-[color:var(--ink-muted)]">
          Search
          <input
            type="search"
            name="search"
            inputMode="search"
            className="w-48 rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
            placeholder="Search stem…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            autoComplete="off"
          />
        </label>
        <label className="grid gap-1 text-xs font-medium text-[color:var(--ink-muted)]">
          Subject
          <select
            name="subject"
            className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
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
        <label className="grid gap-1 text-xs font-medium text-[color:var(--ink-muted)]">
          Module
          <select
            name="module"
            className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
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
        <label className="grid gap-1 text-xs font-medium text-[color:var(--ink-muted)]">
          Difficulty
          <select
            name="difficulty"
            className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
            value={difficulty}
            onChange={(e) => setDifficulty(e.target.value ? Number(e.target.value) : "")}
          >
            <option value="">All</option>
            {[1, 2, 3, 4, 5].map((d) => (
              <option key={d} value={d}>
                {d}
              </option>
            ))}
          </select>
        </label>
        <label className="grid gap-1 text-xs font-medium text-[color:var(--ink-muted)]">
          Type
          <select
            name="questionType"
            className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
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
          className="rounded-full bg-[color:var(--accent)] px-4 py-2 text-xs font-semibold text-white transition hover:bg-[color:var(--accent-strong)]"
        >
          Search
        </button>
        <button
          type="button"
          onClick={clearFilters}
          className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-4 py-2 text-xs font-medium text-[color:var(--ink-muted)] transition hover:border-[color:var(--accent)] hover:text-[color:var(--ink)]"
        >
          Clear
        </button>
      </form>

      <div className="overflow-hidden rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)]">
        <table className="w-full text-left text-sm text-[color:var(--ink-muted)]">
          <thead className="bg-[color:var(--surface-soft)] text-xs font-medium text-[color:var(--ink-muted)]">
            <tr>
              <th scope="col" className="px-4 py-3">Stem</th>
              <th scope="col" className="w-24 px-4 py-3">Subject</th>
              <th scope="col" className="w-24 px-4 py-3">Module</th>
              <th scope="col" className="w-16 px-4 py-3">Diff</th>
              <th scope="col" className="w-20 px-4 py-3">Type</th>
              <th scope="col" className="w-24 px-4 py-3">Created</th>
              <th scope="col" className="w-24 px-4 py-3">Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading && !result ? (
              <tr>
                <td
                  colSpan={7}
                  className="px-4 py-8 text-center text-[color:var(--ink-muted)]"
                  role="status"
                  aria-live="polite"
                >
                  Loading…
                </td>
              </tr>
            ) : result?.questions.length === 0 ? (
              <tr>
                <td
                  colSpan={7}
                  className="px-4 py-8 text-center text-[color:var(--ink-muted)]"
                  role="status"
                  aria-live="polite"
                >
                  No questions found.
                </td>
              </tr>
            ) : (
              result?.questions.map((q) => (
                <tr key={q.id} className="border-t border-[color:var(--border)] hover:bg-[color:var(--surface-soft)]">
                  <td className="px-4 py-3">
                    <button
                      type="button"
                      onClick={() => openEditDrawer(q.id)}
                      className="text-left font-medium text-[color:var(--ink)] hover:underline"
                      aria-label={`Edit question ${truncate(q.stem, 60)}`}
                    >
                      {truncate(q.stem, 60)}
                    </button>
                    {q.tags.length > 0 && (
                      <div className="mt-1 flex flex-wrap gap-1">
                        {q.tags.slice(0, 3).map((tag, i) => (
                          <span
                            key={i}
                            className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-2 py-0.5 text-[11px] font-medium text-[color:var(--ink-muted)]"
                          >
                            {tag.name}
                          </span>
                        ))}
                        {q.tags.length > 3 && (
                          <span className="text-xs text-[color:var(--ink-muted)]">+{q.tags.length - 3}</span>
                        )}
                      </div>
                    )}
                  </td>
                  <td className="px-4 py-3 text-xs text-[color:var(--ink-muted)]">{q.subject}</td>
                  <td className="px-4 py-3 text-xs text-[color:var(--ink-muted)]">{q.module}</td>
                  <td className="px-4 py-3 text-center text-xs text-[color:var(--ink-muted)]">{q.difficulty}</td>
                  <td className="px-4 py-3 text-xs text-[color:var(--ink-muted)]">{q.question_type}</td>
                  <td className="px-4 py-3 text-xs text-[color:var(--ink-muted)]">{formatDate(q.created_at)}</td>
                  <td className="px-4 py-3">
                    <div className="flex gap-2">
                      <button
                        type="button"
                        onClick={(event) => {
                          event.stopPropagation();
                          void openEditDrawer(q.id);
                        }}
                        className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-1 text-xs font-medium text-[color:var(--ink-muted)] transition hover:border-[color:var(--accent)] hover:text-[color:var(--ink)]"
                      >
                        Edit
                      </button>
                      <button
                        type="button"
                        onClick={(event) => {
                          event.stopPropagation();
                          void handleDelete(q.id, q.stem);
                        }}
                        disabled={deleting === q.id}
                        className="rounded-full border border-[color:var(--danger)] px-3 py-1 text-xs font-medium text-[color:var(--danger-strong)] transition disabled:opacity-50"
                      >
                        {deleting === q.id ? "…" : "Del"}
                      </button>
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {result && result.totalPages > 1 ? (
        <div className="flex items-center justify-between text-sm">
          <span className="text-[color:var(--ink-muted)]">
            Showing {(result.page - 1) * result.pageSize + 1}-{Math.min(result.page * result.pageSize, result.total)} of{" "}
            {result.total}
          </span>
          <div className="flex gap-2">
            <button
              type="button"
              onClick={() => setPage((p) => Math.max(1, p - 1))}
              disabled={page === 1}
              className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-1 text-xs font-medium text-[color:var(--ink-muted)] disabled:opacity-50"
            >
              Previous
            </button>
            <span className="px-2 py-1 text-[color:var(--ink-muted)]">
              Page {result.page} of {result.totalPages}
            </span>
            <button
              type="button"
              onClick={() => setPage((p) => Math.min(result.totalPages, p + 1))}
              disabled={page >= result.totalPages}
              className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-1 text-xs font-medium text-[color:var(--ink-muted)] disabled:opacity-50"
            >
              Next
            </button>
          </div>
        </div>
      ) : null}

      {drawerOpen ? (
        <div className="fixed inset-0 z-40 flex justify-end">
          <button className="absolute inset-0 bg-black/30" onClick={closeDrawer} aria-label="Close drawer" />
          <aside className="relative z-10 flex h-full w-full max-w-3xl flex-col gap-4 overflow-auto overscroll-contain bg-[color:var(--surface)] p-6 shadow-2xl">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-xs font-medium text-[color:var(--ink-muted)]">
                  {drawerMode === "edit" ? "Edit question" : "Create question"}
                </p>
                <p className="text-sm font-semibold tracking-tight text-[color:var(--ink)]">
                  {drawerMode === "edit" ? "Update content" : "New question"}
                </p>
              </div>
              <button
                className="text-xs font-medium text-[color:var(--ink-muted)] transition hover:text-[color:var(--ink)]"
                onClick={closeDrawer}
              >
                Close
              </button>
            </div>

            {drawerError ? (
              <div
                className="rounded-2xl border border-[color:var(--danger)] bg-[color:var(--surface)] px-4 py-3 text-sm text-[color:var(--danger-strong)]"
                role="alert"
              >
                {drawerError}
              </div>
            ) : null}

            {drawerMode === "edit" && selectedQuestionId ? (
              <div className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-[color:var(--border)] bg-[color:var(--surface-soft)] px-4 py-3">
                <div className="text-xs text-[color:var(--ink-muted)]">
                  ID: <span className="font-mono text-[color:var(--ink)]">{selectedQuestionId}</span>
                </div>
                <Link
                  href={`/admin/questions/${selectedQuestionId}`}
                  className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-1 text-xs font-medium text-[color:var(--ink-muted)] transition hover:border-[color:var(--accent)] hover:text-[color:var(--ink)]"
                >
                  Open Full Editor
                </Link>
              </div>
            ) : null}

            {drawerLoading ? (
              <p className="text-sm text-[color:var(--ink-muted)]" role="status" aria-live="polite">
                Loading question…
              </p>
            ) : (
              <QuestionForm
                key={selectedQuestion?.id ?? "new-question"}
                initialData={selectedQuestion ?? undefined}
                onSubmit={handleDrawerSubmit}
                onCancel={handleDrawerCancel}
                saving={drawerSaving}
              />
            )}

            {drawerMode === "edit" && selectedQuestionId ? (
              <div className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] p-4">
                <AssetUploader questionId={selectedQuestionId} />
              </div>
            ) : null}
          </aside>
        </div>
      ) : null}
    </main>
  );
}
