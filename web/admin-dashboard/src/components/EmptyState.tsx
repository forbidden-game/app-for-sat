"use client";

import type { ReactNode } from "react";

interface EmptyStateProps {
  /**
   * Main title of the empty state
   */
  title: string;
  /**
   * Optional description text
   */
  description?: string;
  /**
   * Optional action button
   */
  action?: {
    label: string;
    onClick: () => void;
    variant?: "primary" | "secondary";
  };
  /**
   * Icon variant
   */
  icon?: "users" | "questions" | "tags" | "banks" | "search" | "custom";
  /**
   * Custom icon component
   */
  customIcon?: ReactNode;
  /**
   * Additional CSS classes
   */
  className?: string;
}

const iconPaths = {
  users: (
    <path
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth={1.5}
      d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2M9 11a4 4 0 100-8 4 4 0 000 8zM23 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75"
    />
  ),
  questions: (
    <path
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth={1.5}
      d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
    />
  ),
  tags: (
    <path
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth={1.5}
      d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A2 2 0 013 12V7a4 4 0 014-4z"
    />
  ),
  banks: (
    <path
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth={1.5}
      d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"
    />
  ),
  search: (
    <path
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth={1.5}
      d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
    />
  ),
  custom: null,
};

export function EmptyState({
  title,
  description,
  action,
  icon = "custom",
  customIcon,
  className = "",
}: EmptyStateProps) {
  return (
    <div
      className={`flex flex-col items-center justify-center rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] p-8 text-center ${className}`}
      role="status"
      aria-live="polite"
    >
      <div
        className="mb-4 rounded-full bg-[color:var(--surface-soft)] p-4 text-[color:var(--ink-muted)]"
        aria-hidden="true"
      >
        <svg
          className="h-8 w-8"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          strokeWidth={1.5}
        >
          {customIcon || iconPaths[icon]}
        </svg>
      </div>

      <h3 className="text-sm font-semibold text-[color:var(--ink)]">{title}</h3>

      {description && (
        <p className="mt-2 max-w-sm text-sm text-[color:var(--ink-muted)]">
          {description}
        </p>
      )}

      {action && (
        <button
          type="button"
          onClick={action.onClick}
          className={`mt-6 rounded-full px-6 py-2 text-xs font-semibold transition ${
            action.variant === "secondary"
              ? "border border-[color:var(--border)] bg-[color:var(--surface)] text-[color:var(--ink)] hover:bg-[color:var(--surface-soft)]"
              : "bg-[color:var(--accent)] text-white hover:bg-[color:var(--accent-strong)]"
          }`}
        >
          {action.label}
        </button>
      )}
    </div>
  );
}

interface EmptyTableRowProps {
  colSpan: number;
  message: string;
  action?: {
    label: string;
    onClick: () => void;
  };
}

export function EmptyTableRow({ colSpan, message, action }: EmptyTableRowProps) {
  return (
    <tr>
      <td
        className="px-4 py-8 text-center"
        colSpan={colSpan}
      >
        <div className="flex flex-col items-center gap-2">
          <span className="text-sm text-[color:var(--ink-muted)]">{message}</span>
          {action && (
            <button
              type="button"
              onClick={action.onClick}
              className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-4 py-1.5 text-xs font-medium text-[color:var(--accent-strong)] transition hover:bg-[color:var(--surface-soft)]"
            >
              {action.label}
            </button>
          )}
        </div>
      </td>
    </tr>
  );
}
