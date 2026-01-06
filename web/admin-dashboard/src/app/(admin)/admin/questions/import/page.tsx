"use client";

import { useState } from "react";
import Link from "next/link";
import { getSupabaseClient } from "@/lib/supabaseClient";

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

export default function ImportQuestionsPage() {
  const supabase = getSupabaseClient();
  const [jsonInput, setJsonInput] = useState("");
  const [partial, setPartial] = useState(false);
  const [importing, setImporting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<ImportResult | null>(null);

  async function handleImport() {
    if (!supabase || !jsonInput.trim()) return;

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

    let payload: unknown;
    try {
      payload = JSON.parse(jsonInput);
    } catch {
      setError("Invalid JSON format.");
      setImporting(false);
      return;
    }

    try {
      const { data, error: rpcError } = await supabase.rpc("import_questions", {
        p_payload: payload,
        p_partial: partial,
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

  function loadSample() {
    setJsonInput(SAMPLE_JSON);
  }

  return (
    <main className="mx-auto flex max-w-4xl flex-col gap-6 px-6 py-8">
      <header className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-xs uppercase tracking-[0.2em] text-zinc-400">
            Admin Console
          </p>
          <h1 className="text-2xl font-semibold text-zinc-900">Import Questions</h1>
          <p className="text-sm text-zinc-500">
            Bulk import questions from JSON.
          </p>
        </div>
        <Link
          href="/admin/questions"
          className="rounded-lg border border-zinc-200 px-4 py-2 text-sm text-zinc-700"
        >
          Back to Questions
        </Link>
      </header>

      {error && (
        <div className="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
          {error}
        </div>
      )}

      {result && (
        <div className="rounded-2xl border border-green-200 bg-green-50 px-4 py-4 text-sm">
          <p className="font-medium text-green-800">
            Import completed: {result.inserted_count} questions inserted.
          </p>
          {result.error_count > 0 && (
            <div className="mt-2">
              <p className="text-amber-800">{result.error_count} errors:</p>
              <ul className="mt-1 list-inside list-disc text-xs text-amber-700">
                {result.errors.map((err, i) => (
                  <li key={i}>
                    Row {err.index}: {err.error}
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      )}

      <div className="rounded-2xl border border-zinc-200 bg-white p-6">
        <div className="flex flex-col gap-4">
          <div className="flex items-center justify-between">
            <label className="text-sm font-medium text-zinc-700">
              JSON Input
            </label>
            <button
              type="button"
              onClick={loadSample}
              className="text-xs text-zinc-500 hover:text-zinc-700 underline"
            >
              Load sample
            </button>
          </div>
          <textarea
            className="min-h-[300px] rounded-lg border border-zinc-200 px-3 py-2 font-mono text-xs"
            value={jsonInput}
            onChange={(e) => setJsonInput(e.target.value)}
            placeholder="Paste your JSON here..."
          />

          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={partial}
              onChange={(e) => setPartial(e.target.checked)}
            />
            Partial mode (continue on errors)
          </label>

          <div className="flex gap-3 pt-2">
            <button
              type="button"
              onClick={handleImport}
              disabled={importing || !jsonInput.trim()}
              className="rounded-lg bg-zinc-900 px-6 py-2 text-sm font-semibold text-white disabled:opacity-60"
            >
              {importing ? "Importing..." : "Import Questions"}
            </button>
          </div>
        </div>
      </div>

      <div className="rounded-2xl border border-zinc-100 bg-zinc-50 p-4 text-xs text-zinc-600">
        <p className="font-medium mb-2">JSON Schema:</p>
        <pre className="overflow-x-auto whitespace-pre-wrap">
{`{
  "questions": [
    {
      "subject": "string (required)",
      "module": "string (required)",
      "difficulty": "number 1-5 (required)",
      "question_type": "mcq | numeric (required)",
      "stem": "string (required)",
      "answer_key": { "correct": "string | number" },
      "metadata": { ... } (optional),
      "options": [
        { "label": "A", "content": "..." }
      ] (for mcq),
      "tags": [
        { "name": "...", "category": "..." }
      ] (optional)
    }
  ]
}`}
        </pre>
      </div>
    </main>
  );
}
