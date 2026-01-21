"use client";

import { useEffect, useMemo, useState, type ChangeEvent } from "react";
import Link from "next/link";
import { getSupabaseClient } from "@/lib/supabaseClient";
import {
  parseImportText,
  type ImportParseError,
  type ImportPayload,
} from "@/lib/questionImport";
import {
  createQuestionBank,
  deleteQuestionBank,
  listQuestionBanks,
  updateQuestionBank,
  type QuestionBank,
  type QuestionBankInput,
} from "./actions";
import { Skeleton } from "@/components/Skeleton";
import { EmptyState } from "@/components/EmptyState";
import { LoadingButton } from "@/components/Button";

const EMPTY_FORM: QuestionBankInput = {
  slug: "",
  title: "",
  subtitle: "",
  icon: "",
  mode: "fixed",
  question_limit: 10,
  rule_json: "{}",
  is_active: true,
  sort_order: 0,
};

type ImportFormat = "csv" | "json";

type ImportResult = {
  inserted_count: number;
  inserted_ids: string[];
  error_count: number;
  errors: Array<{ index: number; error: string }>;
};

type ImportSummary = ImportResult & {
  bankId: string;
  bankTitle: string;
};

const MODE_DESCRIPTIONS = {
  fixed: "Questions are manually added and ordered. Students see them in the order you set.",
  daily_mix: "Questions are selected dynamically based on rules. Define filters in Rule JSON below.",
} as const;

function formatRuleJson(value: QuestionBank["rule_json"]) {
  try {
    return JSON.stringify(value ?? {}, null, 2);
  } catch {
    return "{\\n  \\n}";
  }
}

export default function QuestionBanksPage() {
  const supabase = getSupabaseClient();
  const [banks, setBanks] = useState<QuestionBank[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [form, setForm] = useState<QuestionBankInput>({ ...EMPTY_FORM });
  const [editingId, setEditingId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [drawerMode, setDrawerMode] = useState<"create" | "edit">("create");
  const [selectedBank, setSelectedBank] = useState<QuestionBank | null>(null);
  const [lastImportResult, setLastImportResult] = useState<ImportSummary | null>(null);

  const [importFormat, setImportFormat] = useState<ImportFormat>("csv");
  const [importFile, setImportFile] = useState<File | null>(null);
  const [importPayload, setImportPayload] = useState<ImportPayload | null>(null);
  const [importParseErrors, setImportParseErrors] = useState<ImportParseError[]>([]);
  const [importParseWarnings, setImportParseWarnings] = useState<string[]>([]);
  const [importParsing, setImportParsing] = useState(false);
  const [importPartial, setImportPartial] = useState(false);
  const [importing, setImporting] = useState(false);

  useEffect(() => {
    let active = true;

    async function loadBanks() {
      if (!supabase) {
        if (active) {
          setError("Supabase not configured.");
          setLoading(false);
        }
        return;
      }

      const { data: sessionData } = await supabase.auth.getSession();
      const session = sessionData.session;
      if (!session) {
        if (active) {
          setError("You are not signed in.");
          setLoading(false);
        }
        return;
      }

      try {
        const data = await listQuestionBanks(session.access_token);
        if (active) {
          setBanks(data);
          setError(null);
        }
      } catch (loadError) {
        if (active) {
          setError(
            loadError instanceof Error
              ? loadError.message
              : "Failed to load question banks.",
          );
        }
      } finally {
        if (active) {
          setLoading(false);
        }
      }
    }

    loadBanks();

    return () => {
      active = false;
    };
  }, [supabase]);

  const sortedBanks = useMemo(
    () => [...banks].sort((a, b) => a.sort_order - b.sort_order),
    [banks],
  );

  function formatDateTime(value: string) {
    return new Date(value).toLocaleString();
  }

  function resetForm() {
    setForm({ ...EMPTY_FORM });
    setEditingId(null);
  }

  function resetImportState() {
    setImportFile(null);
    setImportPayload(null);
    setImportParseErrors([]);
    setImportParseWarnings([]);
    setImportParsing(false);
    setImportPartial(false);
  }

  function openCreateDrawer() {
    resetForm();
    resetImportState();
    setDrawerMode("create");
    setSelectedBank(null);
    setDrawerOpen(true);
  }

  function openEditDrawer(bank: QuestionBank) {
    setEditingId(bank.id);
    setForm({
      slug: bank.slug,
      title: bank.title,
      subtitle: bank.subtitle ?? "",
      icon: bank.icon ?? "",
      mode: bank.mode,
      question_limit: bank.question_limit,
      rule_json: formatRuleJson(bank.rule_json),
      is_active: bank.is_active,
      sort_order: bank.sort_order,
    });
    setDrawerMode("edit");
    setSelectedBank(bank);
    setDrawerOpen(true);
  }

  function closeDrawer() {
    setDrawerOpen(false);
  }

  useEffect(() => {
    if (!importFile) return;
    void parseImportFile(importFile, importFormat);
  }, [importFile, importFormat]);

  async function parseImportFile(file: File, format: ImportFormat) {
    setImportParsing(true);
    setImportParseErrors([]);
    setImportParseWarnings([]);
    setImportPayload(null);

    try {
      const text = await file.text();
      const parsed = parseImportText(text, format);
      setImportParseErrors(parsed.errors);
      setImportParseWarnings(parsed.warnings);
      setImportPayload(parsed.payload);
    } catch (err) {
      setImportParseErrors([
        { row: 0, message: err instanceof Error ? err.message : "Failed to read file." },
      ]);
    } finally {
      setImportParsing(false);
    }
  }

  function handleImportFileChange(event: ChangeEvent<HTMLInputElement>) {
    const selected = event.target.files?.[0] ?? null;
    setImportFile(selected);
    if (selected) {
      const name = selected.name.toLowerCase();
      if (name.endsWith(".json")) {
        setImportFormat("json");
      } else if (name.endsWith(".csv")) {
        setImportFormat("csv");
      }
    }
  }

  async function handleSave() {
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
      if (editingId) {
        const updated = await updateQuestionBank(session.access_token, editingId, form);
        setBanks((prev) => prev.map((bank) => (bank.id === updated.id ? updated : bank)));
        setSelectedBank(updated);
      } else {
        const created = await createQuestionBank(session.access_token, form);
        setBanks((prev) => [created, ...prev]);
        if (importPayload) {
          setImporting(true);
          const { data, error: importError } = await supabase.rpc("import_questions_to_bank", {
            p_payload: importPayload,
            p_partial: importPartial,
            p_bank_id: created.id,
          });
          if (importError) {
            throw new Error(importError.message);
          }
          if (data) {
            setLastImportResult({
              ...(data as ImportResult),
              bankId: created.id,
              bankTitle: created.title,
            });
          }
        }
      }
      resetForm();
      resetImportState();
      setDrawerOpen(false);
    } catch (saveError) {
      setError(
        saveError instanceof Error ? saveError.message : "Failed to save question bank.",
      );
    } finally {
      setSaving(false);
      setImporting(false);
    }
  }

  async function handleDelete(bank: QuestionBank) {
    if (!supabase) return;
    const confirmed = window.confirm(
      `Delete question bank \"${bank.title}\"? This will remove its question mappings.`,
    );
    if (!confirmed) return;

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
      await deleteQuestionBank(session.access_token, bank.id);
      setBanks((prev) => prev.filter((item) => item.id !== bank.id));
      if (editingId === bank.id) {
        resetForm();
        setSelectedBank(null);
        setDrawerOpen(false);
      }
    } catch (deleteError) {
      setError(
        deleteError instanceof Error
          ? deleteError.message
          : "Failed to delete question bank.",
      );
    } finally {
      setSaving(false);
    }
  }

  if (loading) {
    return (
      <main className="mx-auto flex max-w-[1280px] flex-col gap-6 px-6 pb-10 pt-8">
        <header className="flex flex-wrap items-center justify-between gap-4">
          <div className="flex flex-col gap-2">
            <Skeleton variant="text" width="80px" />
            <Skeleton variant="text" width="200px" height="28px" />
            <Skeleton variant="text" width="280px" />
          </div>
          <Skeleton variant="rectangular" width="120px" height="36px" />
        </header>

        <section className="overflow-hidden rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)]">
          <div className="flex items-center justify-between border-b border-[color:var(--border)] bg-[color:var(--surface-soft)] px-4 py-3">
            {Array.from({ length: 7 }).map((_, i) => (
              <Skeleton key={i} variant="text" width={i === 0 ? "25%" : "12%"} />
            ))}
          </div>
          <div className="divide-y divide-[color:var(--border)]">
            {Array.from({ length: 5 }).map((_, rowIndex) => (
              <div key={rowIndex} className="flex items-center gap-4 px-4 py-4">
                <Skeleton variant="text" width="25%" />
                <Skeleton variant="text" width="12%" />
                <Skeleton variant="text" width="12%" />
                <Skeleton variant="text" width="12%" />
                <Skeleton variant="text" width="12%" />
                <Skeleton variant="text" width="12%" />
                <Skeleton variant="rectangular" width="80px" height="28px" />
              </div>
            ))}
          </div>
        </section>
      </main>
    );
  }

  if (error && banks.length === 0) {
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
          <h1 className="text-2xl font-semibold tracking-tight text-[color:var(--ink)]">Question Banks</h1>
          <p className="text-sm text-[color:var(--ink-muted)]">
            Create, edit, and retire question banks for the student app.
          </p>
        </div>
        <LoadingButton onClick={openCreateDrawer}>
          Create Bank
        </LoadingButton>
      </header>

      {error ? (
        <div
          className="rounded-xl border border-[color:var(--danger)] bg-[color:var(--surface)] px-4 py-3 text-sm text-[color:var(--danger-strong)]"
          role="alert"
        >
          {error}
        </div>
      ) : null}

      {lastImportResult ? (
        <div
          className="rounded-xl border border-[color:var(--accent)] bg-[color:var(--surface)] px-4 py-3 text-sm"
          role="status"
          aria-live="polite"
        >
          <div className="flex items-center justify-between gap-3">
            <p className="font-medium text-[color:var(--accent-strong)]">
              Imported {lastImportResult.inserted_count} questions into {lastImportResult.bankTitle}.
            </p>
            <button
              type="button"
              onClick={() => setLastImportResult(null)}
              className="text-xs font-medium text-[color:var(--ink-muted)]"
            >
              Dismiss
            </button>
          </div>
          {lastImportResult.error_count > 0 && (
            <ul className="mt-2 list-inside list-disc text-xs text-[color:var(--danger-strong)]">
              {lastImportResult.errors.slice(0, 5).map((err, index) => (
                <li key={index}>
                  Row {err.index}: {err.error}
                </li>
              ))}
            </ul>
          )}
          <Link
            href={`/admin/banks/${lastImportResult.bankId}/questions`}
            className="mt-2 inline-block text-xs font-medium text-[color:var(--accent-strong)]"
          >
            View Bank Questions
          </Link>
        </div>
      ) : null}

      <section className="overflow-hidden rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] shadow-sm">
          <div className="overflow-x-auto scrollbar-thin scrollbar-thumb-[color:var(--border)] scrollbar-track-transparent">
            <table className="w-full text-left text-sm text-[color:var(--ink-muted)] min-w-[900px]">
              <thead className="bg-[color:var(--surface-soft)] text-xs font-medium text-[color:var(--ink-muted)]">
                <tr>
                  <th scope="col" className="px-4 py-3 sticky left-0 bg-[color:var(--surface-soft)] min-w-[180px] z-10">Title</th>
                  <th scope="col" className="px-4 py-3 min-w-[120px]">Slug</th>
                  <th scope="col" className="px-4 py-3 min-w-[100px]">Mode</th>
                  <th scope="col" className="px-4 py-3 min-w-[70px]">Limit</th>
                  <th scope="col" className="px-4 py-3 min-w-[80px]">Status</th>
                  <th scope="col" className="px-4 py-3 min-w-[70px]">Order</th>
                  <th scope="col" className="px-4 py-3 sticky right-0 bg-[color:var(--surface-soft)] min-w-[200px] z-10">Actions</th>
                </tr>
              </thead>
              <tbody>
              {sortedBanks.length === 0 ? (
                <tr>
                  <td
                    colSpan={7}
                  >
                    <EmptyState
                      title="No question banks yet"
                      description="Create your first question bank to start managing practice content for students."
                      icon="banks"
                      action={{
                        label: "Create Bank",
                        onClick: openCreateDrawer,
                        variant: "primary",
                      }}
                      className="m-4"
                    />
                  </td>
                </tr>
              ) : (
                sortedBanks.map((bank) => (
                  <tr
                    key={bank.id}
                    className="border-t border-[color:var(--border)] transition hover:bg-[color:var(--surface-soft)]"
                  >
                    <td className="px-4 py-3 font-medium text-[color:var(--ink)] sticky left-0 bg-[color:var(--surface)]">
                      {bank.title}
                    </td>
                    <td className="px-4 py-3 text-xs text-[color:var(--ink-muted)]">
                      {bank.slug}
                    </td>
                    <td className="px-4 py-3">{bank.mode}</td>
                    <td className="px-4 py-3">{bank.question_limit}</td>
                    <td className="px-4 py-3">
                      <span
                        className={`rounded-full px-2 py-0.5 text-[11px] font-medium text-white ${
                          bank.is_active
                            ? "bg-[color:var(--accent-strong)]"
                            : "bg-[color:var(--danger-strong)]"
                        }`}
                      >
                        {bank.is_active ? "Active" : "Paused"}
                      </span>
                    </td>
                    <td className="px-4 py-3">{bank.sort_order}</td>
                    <td className="px-4 py-3 sticky right-0 bg-[color:var(--surface)]">
                      <div className="flex flex-wrap gap-2">
                        <Link
                          href={`/admin/banks/${bank.id}/questions`}
                          className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-1 text-xs font-medium text-[color:var(--ink-muted)] transition hover:border-[color:var(--accent)] hover:text-[color:var(--ink)]"
                          onClick={(event) => event.stopPropagation()}
                        >
                          Questions
                        </Link>
                        <button
                          className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-1 text-xs font-medium text-[color:var(--ink-muted)] transition hover:border-[color:var(--accent)] hover:text-[color:var(--ink)]"
                          onClick={(event) => {
                            event.stopPropagation();
                            openEditDrawer(bank);
                          }}
                          type="button"
                        >
                          Edit
                        </button>
                        <button
                          className="rounded-full border border-[color:var(--danger)] px-3 py-1 text-xs font-medium text-[color:var(--danger-strong)]"
                          onClick={(event) => {
                            event.stopPropagation();
                            void handleDelete(bank);
                          }}
                          type="button"
                        >
                          Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
      </section>

      {drawerOpen ? (
        <div className="fixed inset-0 z-40 flex justify-end">
          <button
            className="absolute inset-0 bg-black/30"
            onClick={closeDrawer}
            aria-label="Close drawer"
          />
          <aside className="relative z-10 flex h-full w-full max-w-lg flex-col gap-4 overflow-auto overscroll-contain bg-[color:var(--surface)] p-6 shadow-2xl border-l border-[color:var(--border)]">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-xs font-medium text-[color:var(--ink-muted)]">
                  {drawerMode === "edit" ? "Edit Bank" : "Create Bank"}
                </p>
                <p className="text-sm font-semibold tracking-tight text-[color:var(--ink)]">
                  {drawerMode === "edit" ? "Update Settings" : "New Question Bank"}
                </p>
              </div>
              <button
                className="text-xs font-medium text-[color:var(--ink-muted)] transition hover:text-[color:var(--ink)]"
                onClick={closeDrawer}
              >
                Close
              </button>
            </div>

            {drawerMode === "edit" && selectedBank ? (
              <div className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface-soft)] p-4">
                <p className="text-xs font-medium text-[color:var(--ink-muted)]">
                  Bank Details
                </p>
                <dl className="mt-3 space-y-2 text-sm">
                  <div className="flex items-start justify-between gap-3">
                    <dt className="text-xs text-[color:var(--ink-muted)]">ID</dt>
                    <dd className="text-xs text-[color:var(--ink)]">
                      <span className="font-mono break-all">{selectedBank.id}</span>
                    </dd>
                  </div>
                  <div className="flex items-start justify-between gap-3">
                    <dt className="text-xs text-[color:var(--ink-muted)]">Created</dt>
                    <dd className="text-xs text-[color:var(--ink)]">
                      {formatDateTime(selectedBank.created_at)}
                    </dd>
                  </div>
                  <div className="flex items-start justify-between gap-3">
                    <dt className="text-xs text-[color:var(--ink-muted)]">Mode</dt>
                    <dd className="text-xs text-[color:var(--ink)]">{selectedBank.mode}</dd>
                  </div>
                </dl>
              </div>
            ) : null}

            <div className="grid gap-3 text-sm text-[color:var(--ink)]">
              <label className="grid gap-1 text-xs font-medium text-[color:var(--ink-muted)]">
                Slug
                <input
                  name="slug"
                  className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm"
                  value={form.slug}
                  onChange={(event) => setForm({ ...form, slug: event.target.value })}
                  placeholder="sat-practice…"
                  autoComplete="off"
                />
              </label>
              <label className="grid gap-1 text-xs font-medium text-[color:var(--ink-muted)]">
                Title
                <input
                  name="title"
                  className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm"
                  value={form.title}
                  onChange={(event) => setForm({ ...form, title: event.target.value })}
                  placeholder="SAT Practice…"
                  autoComplete="off"
                />
              </label>
              <label className="grid gap-1 text-xs font-medium text-[color:var(--ink-muted)]">
                Subtitle
                <input
                  name="subtitle"
                  className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm"
                  value={form.subtitle}
                  onChange={(event) => setForm({ ...form, subtitle: event.target.value })}
                  placeholder="Optional description…"
                  autoComplete="off"
                />
              </label>
              <label className="grid gap-1 text-xs font-medium text-[color:var(--ink-muted)]">
                Icon
                <input
                  name="icon"
                  className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm"
                  value={form.icon}
                  onChange={(event) => setForm({ ...form, icon: event.target.value })}
                  placeholder="sparkle…"
                  autoComplete="off"
                />
              </label>
              <label className="grid gap-1 text-xs font-medium text-[color:var(--ink-muted)]">
                Mode
                <select
                  name="mode"
                  className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
                  value={form.mode}
                  onChange={(event) => setForm({ ...form, mode: event.target.value })}
                >
                  <option value="fixed">Fixed (manual)</option>
                  <option value="daily_mix">Daily Mix (dynamic)</option>
                </select>
                <span className="text-xs text-[color:var(--ink-muted)]">
                  {MODE_DESCRIPTIONS[form.mode as keyof typeof MODE_DESCRIPTIONS]}
                </span>
              </label>
              <label className="grid gap-1 text-xs font-medium text-[color:var(--ink-muted)]">
                Question limit
                <input
                  name="question_limit"
                  className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm"
                  type="number"
                  value={form.question_limit}
                  onChange={(event) =>
                    setForm({
                      ...form,
                      question_limit: Number(event.target.value),
                    })
                  }
                  autoComplete="off"
                />
              </label>
              <label className="grid gap-1 text-xs font-medium text-[color:var(--ink-muted)]">
                Sort order
                <input
                  name="sort_order"
                  className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm"
                  type="number"
                  value={form.sort_order}
                  onChange={(event) =>
                    setForm({ ...form, sort_order: Number(event.target.value) })
                  }
                  autoComplete="off"
                />
              </label>
              <label className="flex items-center gap-2 text-sm">
                <input
                  checked={form.is_active}
                  onChange={(event) =>
                    setForm({ ...form, is_active: event.target.checked })
                  }
                  type="checkbox"
                  name="is_active"
                  autoComplete="off"
                />
                Active
              </label>
              {form.mode === "daily_mix" && (
                <label className="grid gap-1 text-xs font-medium text-[color:var(--ink-muted)]">
                  <span className="flex items-center gap-2">
                    Rule JSON
                    <span className="rounded-full border border-[color:var(--accent)] px-2 py-0.5 text-[11px] font-medium text-[color:var(--accent-strong)]">
                      Required for Daily Mix
                    </span>
                  </span>
                  <textarea
                    name="rule_json"
                    className="min-h-[120px] rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 font-mono text-xs"
                    value={form.rule_json}
                    onChange={(event) => setForm({ ...form, rule_json: event.target.value })}
                    placeholder='{"subjects": ["math"], "difficulty_min": 1, "difficulty_max": 5}…'
                    autoComplete="off"
                  />
                  <span className="text-xs text-[color:var(--ink-muted)]">
                    Filter questions by subjects, modules, difficulty range, or tag_ids.
                  </span>
                </label>
              )}

              {drawerMode === "create" ? (
                <div className="rounded-xl border border-dashed border-[color:var(--border)] bg-[color:var(--surface-soft)] p-4 text-sm text-[color:var(--ink)]">
                  <p className="mb-2 text-xs font-medium text-[color:var(--ink-muted)]">
                    Import from file (optional)
                  </p>
                  <div className="mb-3 flex flex-wrap items-center gap-2">
                    <select
                      name="importFormat"
                      className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-1.5 text-xs font-medium text-[color:var(--ink)]"
                      value={importFormat}
                      onChange={(event) => setImportFormat(event.target.value as ImportFormat)}
                      aria-label="Import format"
                    >
                      <option value="csv">CSV</option>
                      <option value="json">JSON</option>
                    </select>
                    <input
                      type="file"
                      accept=".csv,.json"
                      onChange={handleImportFileChange}
                      className="text-sm"
                      aria-label="Import file"
                      name="importFile"
                      autoComplete="off"
                    />
                    {importFile ? (
                      <button
                        type="button"
                        onClick={() => resetImportState()}
                        className="text-xs text-[color:var(--ink-muted)] hover:text-[color:var(--ink)] underline"
                      >
                        Clear
                      </button>
                    ) : null}
                  </div>

                  {form.mode !== "fixed" ? (
                    <p className="mb-2 text-xs text-[color:var(--danger-strong)]">
                      Import attaches questions to the bank. Daily Mix uses Rule JSON instead of fixed ordering.
                    </p>
                  ) : null}

                  {importParsing ? (
                    <p
                      className="mb-2 text-xs text-[color:var(--ink-muted)]"
                      role="status"
                      aria-live="polite"
                    >
                      Parsing file…
                    </p>
                  ) : null}

                  {importParseErrors.length > 0 && (
                    <div
                      className="mb-2 rounded-lg border border-[color:var(--danger)] bg-[color:var(--surface)] px-3 py-2 text-xs text-[color:var(--danger-strong)]"
                      role="alert"
                    >
                      <p className="mb-1 font-medium">Parse errors</p>
                      <ul className="list-inside list-disc space-y-1">
                        {importParseErrors.slice(0, 5).map((err, index) => (
                          <li key={index}>
                            Row {err.row}: {err.message}
                          </li>
                        ))}
                      </ul>
                    </div>
                  )}

                  {importParseWarnings.length > 0 && (
                    <div
                      className="mb-2 rounded-lg border border-[color:var(--border)] bg-[color:var(--surface-soft)] px-3 py-2 text-xs text-[color:var(--ink-muted)]"
                      role="status"
                      aria-live="polite"
                    >
                      <p className="mb-1 font-medium">Warnings</p>
                      <ul className="list-inside list-disc space-y-1">
                        {importParseWarnings.slice(0, 4).map((warning, index) => (
                          <li key={index}>{warning}</li>
                        ))}
                      </ul>
                    </div>
                  )}

                  {importPayload ? (
                    <p className="mb-2 text-xs text-[color:var(--ink-muted)]">
                      Parsed {importPayload.questions.length} questions.
                    </p>
                  ) : null}

                  <label className="flex items-center gap-2 text-xs text-[color:var(--ink-muted)]">
                    <input
                      type="checkbox"
                      checked={importPartial}
                      onChange={(event) => setImportPartial(event.target.checked)}
                      name="partialMode"
                      autoComplete="off"
                    />
                    Partial mode (continue on errors)
                  </label>
                </div>
              ) : null}
              <div className="flex flex-wrap gap-2 pt-2">
                <LoadingButton
                  loading={saving || importing}
                  disabled={
                    (drawerMode === "create" &&
                      !!importFile &&
                      (importParsing || !importPayload || importParseErrors.length > 0))
                  }
                  onClick={handleSave}
                >
                  {drawerMode === "edit" ? "Save Changes" : "Create Bank"}
                </LoadingButton>
                <LoadingButton
                  variant="secondary"
                  onClick={closeDrawer}
                  disabled={saving}
                >
                  Cancel
                </LoadingButton>
              </div>
            </div>
          </aside>
        </div>
      ) : null}
    </main>
  );
}
