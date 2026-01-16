"use client";

import { useMemo } from "react";

import { diffLines, stringifyWithMask } from "./debug-helpers";

export function DiffField({
  label,
  currentValue,
  previousValue,
  maskEnabled,
}: {
  label: string;
  currentValue: unknown;
  previousValue: unknown;
  maskEnabled: boolean;
}) {
  const currentText = stringifyWithMask(currentValue, maskEnabled);
  const previousText = stringifyWithMask(previousValue, maskEnabled);
  const diffRows = useMemo(() => diffLines(currentText, previousText), [currentText, previousText]);
  const changed = currentText !== previousText;

  return (
    <div className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] p-3">
      <div className="flex items-center justify-between gap-2 text-[11px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
        <span>{label}</span>
        <span
          className={`rounded-full px-2 py-0.5 text-[10px] ${
            changed ? "bg-amber-100 text-amber-700" : "bg-emerald-100 text-emerald-700"
          }`}
        >
          {changed ? "changed" : "same"}
        </span>
      </div>
      <div className="mt-2 grid gap-2 md:grid-cols-2">
        <DiffBlock label="Current" rows={diffRows} side="current" />
        <DiffBlock label="Previous" rows={diffRows} side="previous" />
      </div>
    </div>
  );
}

function DiffBlock({
  label,
  rows,
  side,
}: {
  label: string;
  rows: Array<{ current: string; previous: string; changed: boolean }>;
  side: "current" | "previous";
}) {
  return (
    <div className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface-soft)] p-2">
      <div className="text-[10px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">{label}</div>
      <div className="mt-1 max-h-40 overflow-auto text-[11px]">
        {rows.map((row, index) => (
          <div
            key={`${label}-${index}`}
            className={`whitespace-pre-wrap break-words px-2 py-0.5 ${row.changed ? "bg-amber-50 text-amber-900" : "text-[color:var(--ink)]"}`}
          >
            {side === "current" ? row.current || " " : row.previous || " "}
          </div>
        ))}
      </div>
    </div>
  );
}
