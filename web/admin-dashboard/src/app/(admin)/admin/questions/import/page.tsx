"use client";

import { useEffect, useMemo, useState, type ChangeEvent } from "react";
import Link from "next/link";
import { getSupabaseClient } from "@/lib/supabaseClient";
import { parseImportText, type ImportParseError, type ImportPayload } from "@/lib/questionImport";

type ImportResult = {
  inserted_count: number;
  inserted_ids: string[];
  error_count: number;
  errors: Array<{ index: number; error: string }>;
};

const SAMPLE_JSON = `{
  "questions": [
    {
      "subject": "math",
      "module": "algebra",
      "difficulty": 2,
      "question_type": "mcq",
      "stem": "What is 2 + 2?",
      "answer_key": { "correct": "B" },
      "options": [
        { "label": "A", "content": "3" },
        { "label": "B", "content": "4" },
        { "label": "C", "content": "5" },
        { "label": "D", "content": "6" }
      ],
      "tags": [
        { "name": "arithmetic", "category": "topic" }
      ]
    }
  ]
}`;

const SAMPLE_CSV = `subject,module,difficulty,question_type,stem,answer_key,options,tags,metadata
math,algebra,2,mcq,"What is 2 + 2?",B,"[{""label"":""A"",""content"":""3""},{""label"":""B"",""content"":""4""},{""label"":""C"",""content"":""5""},{""label"":""D"",""content"":""6""}]","[""arithmetic"",""basics""]","{""source"":""sample""}"
math,algebra,3,numeric,"Solve 5x = 20",4,,,
`;

type ImportFormat = "csv" | "json";

export default function ImportQuestionsPage() {
  const supabase = getSupabaseClient();
  const [file, setFile] = useState<File | null>(null);
  const [format, setFormat] = useState<ImportFormat>("csv");
  const [payload, setPayload] = useState<ImportPayload | null>(null);
  const [parseErrors, setParseErrors] = useState<ImportParseError[]>([]);
  const [parseWarnings, setParseWarnings] = useState<string[]>([]);
  const [parsing, setParsing] = useState(false);
  const [partial, setPartial] = useState(false);
  const [importing, setImporting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<ImportResult | null>(null);

  const previewQuestions = useMemo(() => payload?.questions.slice(0, 3) ?? [], [payload]);

  useEffect(() => {
    if (!file) return;
    void parseFile(file, format);
  }, [file, format]);

  async function parseFile(selectedFile: File, selectedFormat: ImportFormat) {
    setParsing(true);
    setParseErrors([]);
    setParseWarnings([]);
    setPayload(null);
    setError(null);
    setResult(null);

    try {
      const text = await selectedFile.text();
      const parsed = parseImportText(text, selectedFormat);
      setParseErrors(parsed.errors);
      setParseWarnings(parsed.warnings);
      setPayload(parsed.payload);
    } catch (err) {
      setParseErrors([{ row: 0, message: err instanceof Error ? err.message : "Failed to read file." }]);
    } finally {
      setParsing(false);
    }
  }

  async function handleImport() {
    if (!supabase || !payload) return;

    setImporting(true);
    setError(null);
    setResult(null);

    const { data: sessionData } = await supabase.auth.getSession();
    const session = sessionData.session;
    if (!session) {
      setError("You are not signed in.");
      setImporting(false);
      return;
    }

    try {
      const { data, error: rpcError } = await supabase.rpc("import_questions_to_bank", {
        p_payload: payload,
        p_partial: partial,
        p_bank_id: null,
      });

      if (rpcError) {
        throw new Error(rpcError.message);
      }

      setResult(data as ImportResult);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Import failed.");
    } finally {
      setImporting(false);
    }
  }

  function handleFileChange(event: ChangeEvent<HTMLInputElement>) {
    const selected = event.target.files?.[0] ?? null;
    setFile(selected);
    if (selected) {
      const name = selected.name.toLowerCase();
      if (name.endsWith(".json")) {
        setFormat("json");
      } else if (name.endsWith(".csv")) {
        setFormat("csv");
      }
    }
  }

  function clearFile() {
    setFile(null);
    setPayload(null);
    setParseErrors([]);
    setParseWarnings([]);
    setResult(null);
  }

  function downloadSample(sampleFormat: ImportFormat) {
    const content = sampleFormat === "csv" ? SAMPLE_CSV : SAMPLE_JSON;
    const blob = new Blob([content], { type: "text/plain" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = sampleFormat === "csv" ? "questions-sample.csv" : "questions-sample.json";
    link.click();
    URL.revokeObjectURL(url);
  }

  return (
    <main className="mx-auto flex max-w-[1440px] flex-col gap-6 px-6 pb-10 pt-8">
      <header className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-[11px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">Admin Console</p>
          <h1 className="text-2xl font-semibold text-[color:var(--ink)]">Import Questions</h1>
          <p className="text-sm text-[color:var(--ink-muted)]">Bulk import questions from CSV or JSON.</p>
        </div>
        <Link
          href="/admin/questions"
          className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-4 py-2 text-[10px] font-semibold uppercase tracking-[0.2em] text-[color:var(--ink-muted)] transition hover:border-[color:var(--accent)] hover:text-[color:var(--ink)]"
        >
          Back to Questions
        </Link>
      </header>

      {error ? (
        <div
          className="rounded-2xl border border-[color:var(--danger)] bg-[color:var(--surface)] px-4 py-3 text-sm text-[color:var(--danger-strong)]"
          role="alert"
        >
          {error}
        </div>
      ) : null}

      {result ? (
        <div
          className="rounded-2xl border border-[color:var(--accent)] bg-[color:var(--surface)] px-4 py-4 text-sm"
          role="status"
          aria-live="polite"
        >
          <p className="font-medium text-[color:var(--accent-strong)]">
            Import completed: {result.inserted_count} questions inserted.
          </p>
          {result.error_count > 0 && (
            <div className="mt-2">
              <p className="text-[color:var(--danger-strong)]">{result.error_count} errors:</p>
              <ul className="mt-1 list-inside list-disc text-xs text-[color:var(--danger-strong)]">
                {result.errors.map((err, i) => (
                  <li key={i}>
                    Row {err.index}: {err.error}
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      ) : null}

      <div className="rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface)] p-6">
        <div className="flex flex-col gap-4">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <label className="text-sm font-medium text-[color:var(--ink)]">Import file</label>
            <div className="flex items-center gap-2 text-[10px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
              <button type="button" onClick={() => downloadSample("csv")} className="hover:text-[color:var(--ink)]">
                Download CSV
              </button>
              <span>|</span>
              <button type="button" onClick={() => downloadSample("json")} className="hover:text-[color:var(--ink)]">
                Download JSON
              </button>
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-3">
            <select
              name="importFormat"
              className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-[11px] text-[color:var(--ink)]"
              value={format}
              onChange={(event) => setFormat(event.target.value as ImportFormat)}
              aria-label="Import format"
            >
              <option value="csv">CSV</option>
              <option value="json">JSON</option>
            </select>
            <input
              type="file"
              accept=".csv,.json"
              onChange={handleFileChange}
              className="text-sm text-[color:var(--ink)]"
              aria-label="Import file"
              name="importFile"
              autoComplete="off"
            />
            {file ? (
              <button
                type="button"
                onClick={clearFile}
                className="text-[10px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)] hover:text-[color:var(--ink)]"
              >
                Clear
              </button>
            ) : null}
          </div>

          {parsing ? (
            <p className="text-xs text-[color:var(--ink-muted)]" role="status" aria-live="polite">
              Parsing file…
            </p>
          ) : null}

          {parseErrors.length > 0 ? (
            <div
              className="rounded-xl border border-[color:var(--danger)] bg-[color:var(--surface)] px-3 py-2 text-xs text-[color:var(--danger-strong)]"
              role="alert"
            >
              <p className="font-medium mb-1">Parse errors</p>
              <ul className="list-inside list-disc space-y-1">
                {parseErrors.slice(0, 8).map((err, index) => (
                  <li key={index}>
                    Row {err.row}: {err.message}
                  </li>
                ))}
              </ul>
              {parseErrors.length > 8 ? (
                <p className="mt-1 text-[11px] text-[color:var(--danger-strong)]">
                  {parseErrors.length - 8} more errors not shown.
                </p>
              ) : null}
            </div>
          ) : null}

          {parseWarnings.length > 0 ? (
            <div
              className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface-soft)] px-3 py-2 text-xs text-[color:var(--ink-muted)]"
              role="status"
              aria-live="polite"
            >
              <p className="font-medium mb-1">Warnings</p>
              <ul className="list-inside list-disc space-y-1">
                {parseWarnings.slice(0, 6).map((warning, index) => (
                  <li key={index}>{warning}</li>
                ))}
              </ul>
            </div>
          ) : null}

          {payload ? (
            <div className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface-soft)] px-3 py-2 text-xs text-[color:var(--ink-muted)]">
              <p className="font-medium text-[color:var(--ink)]">Parsed {payload.questions.length} questions</p>
              {previewQuestions.length > 0 ? (
                <ul className="mt-2 list-disc list-inside space-y-1">
                  {previewQuestions.map((question, index) => (
                    <li key={index}>
                      {question.subject} / {question.module} / D{question.difficulty} - {question.stem.slice(0, 60)}
                    </li>
                  ))}
                </ul>
              ) : null}
            </div>
          ) : null}

          <label className="flex items-center gap-2 text-xs text-[color:var(--ink-muted)]">
            <input
              type="checkbox"
              checked={partial}
              onChange={(e) => setPartial(e.target.checked)}
              name="partialMode"
              autoComplete="off"
            />
            Partial mode (continue on errors)
          </label>

          <div className="flex gap-3 pt-2">
            <button
              type="button"
              onClick={handleImport}
              disabled={importing || parsing || !payload || parseErrors.length > 0}
              className="rounded-full bg-[color:var(--accent)] px-6 py-2 text-[11px] font-semibold uppercase tracking-[0.2em] text-white transition hover:bg-[color:var(--accent-strong)] disabled:opacity-60"
            >
              {importing ? "Importing…" : "Import Questions"}
            </button>
          </div>
        </div>
      </div>

      <div className="rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface-soft)] p-4 text-xs text-[color:var(--ink-muted)]">
        <p className="font-medium mb-2">Supported formats</p>
        <div className="space-y-3">
          <div>
            <p className="font-medium text-[color:var(--ink)] mb-1">CSV columns</p>
            <p className="text-[11px] text-[color:var(--ink-muted)]">
              subject, module, difficulty, question_type, stem, answer_key, options, tags, metadata
            </p>
            <p className="text-[11px] text-[color:var(--ink-muted)] mt-1">
              options/tags/metadata accept JSON. options also supports "A:3|B:4". tags can be "tag1;tag2".
            </p>
          </div>
          <div>
            <p className="font-medium text-[color:var(--ink)] mb-1">JSON schema</p>
            <pre className="overflow-x-auto whitespace-pre-wrap font-mono text-[11px]">
{`{
  "questions": [
    {
      "subject": "string",
      "module": "string",
      "difficulty": 1,
      "question_type": "mcq | numeric",
      "stem": "string",
      "answer_key": { "correct": "string | number" },
      "metadata": { … },
      "options": [{ "label": "A", "content": "…" }],
      "tags": [{ "name": "…", "category": "…" }]
    }
  ]
}`}
            </pre>
          </div>
        </div>
      </div>
    </main>
  );
}
