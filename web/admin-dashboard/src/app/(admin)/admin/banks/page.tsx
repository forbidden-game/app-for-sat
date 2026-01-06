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
      <main className="mx-auto max-w-6xl px-6 py-12">
        <p className="text-sm text-zinc-500">Loading question banks...</p>
      </main>
    );
  }

  if (error && banks.length === 0) {
    return (
      <main className="mx-auto max-w-6xl px-6 py-12">
        <p className="text-sm text-red-600">{error}</p>
      </main>
    );
  }

  return (
    <main className="mx-auto flex max-w-6xl flex-col gap-10 px-6 py-8">
      <header className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-xs uppercase tracking-[0.2em] text-zinc-400">
            Admin Console
          </p>
          <h1 className="text-2xl font-semibold text-zinc-900">Question banks</h1>
          <p className="text-sm text-zinc-500">
            Create, edit, and retire question banks for the student app.
          </p>
        </div>
        <button
          className="rounded-full bg-zinc-900 px-4 py-2 text-sm font-semibold text-white transition hover:bg-zinc-800"
          onClick={openCreateDrawer}
          type="button"
        >
          Create bank
        </button>
      </header>

      {error ? (
        <div className="rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
          {error}
        </div>
      ) : null}

      {lastImportResult ? (
        <div className="rounded-2xl border border-green-200 bg-green-50 px-4 py-3 text-sm text-green-800">
          <div className="flex items-center justify-between gap-3">
            <p className="font-medium">
              Imported {lastImportResult.inserted_count} questions into{" "}
              {lastImportResult.bankTitle}.
            </p>
            <button
              type="button"
              onClick={() => setLastImportResult(null)}
              className="text-xs text-green-700 underline"
            >
              Dismiss
            </button>
          </div>
          {lastImportResult.error_count > 0 && (
            <ul className="mt-2 list-inside list-disc text-xs text-amber-700">
              {lastImportResult.errors.slice(0, 5).map((err, index) => (
                <li key={index}>
                  Row {err.index}: {err.error}
                </li>
              ))}
            </ul>
          )}
          <Link
            href={`/admin/banks/${lastImportResult.bankId}/questions`}
            className="mt-2 inline-block text-xs text-green-700 underline"
          >
            View bank questions
          </Link>
        </div>
      ) : null}

      <section className="overflow-hidden rounded-2xl border border-zinc-200 bg-white">
          <table className="w-full text-left text-sm text-zinc-700">
            <thead className="bg-zinc-50 text-xs uppercase tracking-wide text-zinc-500">
              <tr>
                <th className="px-4 py-3">Title</th>
                <th className="px-4 py-3">Slug</th>
                <th className="px-4 py-3">Mode</th>
                <th className="px-4 py-3">Limit</th>
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3">Order</th>
                <th className="px-4 py-3">Actions</th>
              </tr>
            </thead>
            <tbody>
              {sortedBanks.length === 0 ? (
                <tr>
                  <td
                    className="px-4 py-6 text-center text-sm text-zinc-500"
                    colSpan={7}
                  >
                    No question banks yet.
                  </td>
                </tr>
              ) : (
                sortedBanks.map((bank) => (
                  <tr
                    key={bank.id}
                    className="cursor-pointer border-t border-zinc-100 transition hover:bg-zinc-50"
                    onClick={() => openEditDrawer(bank)}
                  >
                    <td className="px-4 py-3 font-medium text-zinc-900">
                      {bank.title}
                    </td>
                    <td className="px-4 py-3 text-xs text-zinc-500">
                      {bank.slug}
                    </td>
                    <td className="px-4 py-3">{bank.mode}</td>
                    <td className="px-4 py-3">{bank.question_limit}</td>
                    <td className="px-4 py-3">
                      {bank.is_active ? "Active" : "Paused"}
                    </td>
                    <td className="px-4 py-3">{bank.sort_order}</td>
                    <td className="px-4 py-3">
                      <div className="flex flex-wrap gap-2">
                        <Link
                          href={`/admin/banks/${bank.id}/questions`}
                          className="rounded-full border border-zinc-200 px-3 py-1 text-xs text-zinc-700 transition hover:border-zinc-300"
                          onClick={(event) => event.stopPropagation()}
                        >
                          Questions
                        </Link>
                        <button
                          className="rounded-full border border-zinc-200 px-3 py-1 text-xs text-zinc-700 transition hover:border-zinc-300"
                          onClick={(event) => {
                            event.stopPropagation();
                            openEditDrawer(bank);
                          }}
                          type="button"
                        >
                          Edit
                        </button>
                        <button
                          className="rounded-full border border-red-200 px-3 py-1 text-xs text-red-700 transition hover:border-red-300"
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
          <aside className="relative z-10 flex h-full w-full max-w-lg flex-col gap-4 overflow-auto bg-white p-6 shadow-2xl">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-xs uppercase tracking-[0.2em] text-zinc-400">
                  {drawerMode === "edit" ? "Edit bank" : "Create bank"}
                </p>
                <p className="text-sm font-semibold text-zinc-900">
                  {drawerMode === "edit" ? "Update settings" : "New question bank"}
                </p>
              </div>
              <button
                className="text-xs text-zinc-400 transition hover:text-zinc-600"
                onClick={closeDrawer}
              >
                Close
              </button>
            </div>

            {drawerMode === "edit" && selectedBank ? (
              <div className="rounded-2xl border border-zinc-200 bg-zinc-50 p-4">
                <p className="text-xs uppercase tracking-[0.2em] text-zinc-400">
                  Bank details
                </p>
                <dl className="mt-3 space-y-2 text-sm">
                  <div className="flex items-start justify-between gap-3">
                    <dt className="text-xs text-zinc-500">ID</dt>
                    <dd className="text-xs text-zinc-700">
                      <span className="font-mono break-all">{selectedBank.id}</span>
                    </dd>
                  </div>
                  <div className="flex items-start justify-between gap-3">
                    <dt className="text-xs text-zinc-500">Created</dt>
                    <dd className="text-xs text-zinc-700">
                      {formatDateTime(selectedBank.created_at)}
                    </dd>
                  </div>
                  <div className="flex items-start justify-between gap-3">
                    <dt className="text-xs text-zinc-500">Mode</dt>
                    <dd className="text-xs text-zinc-700">{selectedBank.mode}</dd>
                  </div>
                </dl>
              </div>
            ) : null}

            <div className="grid gap-3 text-sm text-zinc-700">
              <label className="grid gap-1">
                Slug
                <input
                  className="rounded-lg border border-zinc-200 px-3 py-2 text-sm"
                  value={form.slug}
                  onChange={(event) => setForm({ ...form, slug: event.target.value })}
                  placeholder="sat-practice"
                />
              </label>
              <label className="grid gap-1">
                Title
                <input
                  className="rounded-lg border border-zinc-200 px-3 py-2 text-sm"
                  value={form.title}
                  onChange={(event) => setForm({ ...form, title: event.target.value })}
                  placeholder="SAT Practice"
                />
              </label>
              <label className="grid gap-1">
                Subtitle
                <input
                  className="rounded-lg border border-zinc-200 px-3 py-2 text-sm"
                  value={form.subtitle}
                  onChange={(event) => setForm({ ...form, subtitle: event.target.value })}
                  placeholder="Optional description"
                />
              </label>
              <label className="grid gap-1">
                Icon
                <input
                  className="rounded-lg border border-zinc-200 px-3 py-2 text-sm"
                  value={form.icon}
                  onChange={(event) => setForm({ ...form, icon: event.target.value })}
                  placeholder="sparkle"
                />
              </label>
              <label className="grid gap-1">
                Mode
                <select
                  className="rounded-lg border border-zinc-200 px-3 py-2 text-sm"
                  value={form.mode}
                  onChange={(event) => setForm({ ...form, mode: event.target.value })}
                >
                  <option value="fixed">Fixed (manual)</option>
                  <option value="daily_mix">Daily Mix (dynamic)</option>
                </select>
                <span className="text-xs text-zinc-500">
                  {MODE_DESCRIPTIONS[form.mode as keyof typeof MODE_DESCRIPTIONS]}
                </span>
              </label>
              <label className="grid gap-1">
                Question limit
                <input
                  className="rounded-lg border border-zinc-200 px-3 py-2 text-sm"
                  type="number"
                  value={form.question_limit}
                  onChange={(event) =>
                    setForm({
                      ...form,
                      question_limit: Number(event.target.value),
                    })
                  }
                />
              </label>
              <label className="grid gap-1">
                Sort order
                <input
                  className="rounded-lg border border-zinc-200 px-3 py-2 text-sm"
                  type="number"
                  value={form.sort_order}
                  onChange={(event) =>
                    setForm({ ...form, sort_order: Number(event.target.value) })
                  }
                />
              </label>
              <label className="flex items-center gap-2 text-sm">
                <input
                  checked={form.is_active}
                  onChange={(event) =>
                    setForm({ ...form, is_active: event.target.checked })
                  }
                  type="checkbox"
                />
                Active
              </label>
              {form.mode === "daily_mix" && (
                <label className="grid gap-1">
                  <span className="flex items-center gap-2">
                    Rule JSON
                    <span className="rounded bg-blue-100 px-1.5 py-0.5 text-[10px] font-medium text-blue-700">
                      Required for Daily Mix
                    </span>
                  </span>
                  <textarea
                    className="min-h-[120px] rounded-lg border border-zinc-200 px-3 py-2 font-mono text-xs"
                    value={form.rule_json}
                    onChange={(event) => setForm({ ...form, rule_json: event.target.value })}
                    placeholder='{"subjects": ["math"], "difficulty_min": 1, "difficulty_max": 5}'
                  />
                  <span className="text-xs text-zinc-500">
                    Filter questions by subjects, modules, difficulty range, or tag_ids.
                  </span>
                </label>
              )}

              {drawerMode === "create" ? (
                <div className="rounded-2xl border border-dashed border-zinc-200 bg-zinc-50 p-4 text-sm text-zinc-700">
                  <p className="text-xs uppercase tracking-[0.2em] text-zinc-400 mb-2">
                    Import from file (optional)
                  </p>
                  <div className="flex flex-wrap items-center gap-2 mb-3">
                    <select
                      className="rounded-lg border border-zinc-200 px-3 py-2 text-sm"
                      value={importFormat}
                      onChange={(event) => setImportFormat(event.target.value as ImportFormat)}
                    >
                      <option value="csv">CSV</option>
                      <option value="json">JSON</option>
                    </select>
                    <input
                      type="file"
                      accept=".csv,.json"
                      onChange={handleImportFileChange}
                      className="text-sm"
                    />
                    {importFile ? (
                      <button
                        type="button"
                        onClick={() => resetImportState()}
                        className="text-xs text-zinc-500 hover:text-zinc-700 underline"
                      >
                        Clear
                      </button>
                    ) : null}
                  </div>

                  {form.mode !== "fixed" ? (
                    <p className="text-xs text-amber-600 mb-2">
                      Import attaches questions to the bank. Daily Mix uses Rule JSON
                      instead of fixed ordering.
                    </p>
                  ) : null}

                  {importParsing ? (
                    <p className="text-xs text-zinc-400 mb-2">Parsing file...</p>
                  ) : null}

                  {importParseErrors.length > 0 && (
                    <div className="rounded-xl border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700 mb-2">
                      <p className="font-medium mb-1">Parse errors</p>
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
                    <div className="rounded-xl border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-800 mb-2">
                      <p className="font-medium mb-1">Warnings</p>
                      <ul className="list-inside list-disc space-y-1">
                        {importParseWarnings.slice(0, 4).map((warning, index) => (
                          <li key={index}>{warning}</li>
                        ))}
                      </ul>
                    </div>
                  )}

                  {importPayload ? (
                    <p className="text-xs text-zinc-600 mb-2">
                      Parsed {importPayload.questions.length} questions.
                    </p>
                  ) : null}

                  <label className="flex items-center gap-2 text-xs text-zinc-600">
                    <input
                      type="checkbox"
                      checked={importPartial}
                      onChange={(event) => setImportPartial(event.target.checked)}
                    />
                    Partial mode (continue on errors)
                  </label>
                </div>
              ) : null}
              <div className="flex flex-wrap gap-2 pt-2">
                <button
                  className="rounded-lg bg-zinc-900 px-4 py-2 text-sm font-semibold text-white disabled:opacity-60"
                  disabled={
                    saving ||
                    importing ||
                    (drawerMode === "create" &&
                      !!importFile &&
                      (importParsing || !importPayload || importParseErrors.length > 0))
                  }
                  onClick={handleSave}
                  type="button"
                >
                  {drawerMode === "edit" ? "Save changes" : "Create bank"}
                </button>
                <button
                  className="rounded-lg border border-zinc-200 px-4 py-2 text-sm text-zinc-700"
                  onClick={closeDrawer}
                  type="button"
                  disabled={saving}
                >
                  Cancel
                </button>
              </div>
            </div>
          </aside>
        </div>
      ) : null}
    </main>
  );
}
