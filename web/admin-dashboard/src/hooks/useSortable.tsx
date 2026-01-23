import { useCallback, useMemo, useState } from "react";

export type SortDirection = "asc" | "desc";

export interface SortConfig<T> {
  column: keyof T | null;
  direction: SortDirection;
}

export interface UseSortableReturn<T> {
  sortConfig: SortConfig<T>;
  handleSort: (column: keyof T) => void;
  sortedData: T[];
}

/**
 * Custom hook for sortable table columns
 * @param data - The data to sort
 * @param initialColumn - Initial sort column (optional)
 * @param initialDirection - Initial sort direction (default: asc)
 */
export function useSortable<T extends Record<string, unknown>>(
  data: T[],
  initialColumn?: keyof T,
  initialDirection: SortDirection = "asc",
): UseSortableReturn<T> {
  const [sortConfig, setSortConfig] = useState<SortConfig<T>>(() => {
    if (initialColumn) {
      return { column: initialColumn, direction: initialDirection };
    }
    return { column: null, direction: "asc" };
  });

  const handleSort = useCallback((column: keyof T) => {
    setSortConfig((prev) => {
      if (prev.column === column) {
        // Toggle direction: asc -> desc -> asc
        return {
          column,
          direction: prev.direction === "asc" ? "desc" : "asc",
        };
      }
      return { column, direction: "asc" };
    });
  }, []);

  const sortedData = useMemo(() => {
    if (!sortConfig.column) return data;

    return [...data].sort((a, b) => {
      const aValue = a[sortConfig.column!];
      const bValue = b[sortConfig.column!];

      // Handle null/undefined values
      if (aValue == null && bValue == null) return 0;
      if (aValue == null) return sortConfig.direction === "asc" ? 1 : -1;
      if (bValue == null) return sortConfig.direction === "asc" ? -1 : 1;

      // String comparison
      if (typeof aValue === "string" && typeof bValue === "string") {
        const aLower = aValue.toLowerCase();
        const bLower = bValue.toLowerCase();
        if (aLower < bLower) return sortConfig.direction === "asc" ? -1 : 1;
        if (aLower > bLower) return sortConfig.direction === "asc" ? 1 : -1;
        return 0;
      }

      // Number comparison
      if (typeof aValue === "number" && typeof bValue === "number") {
        return sortConfig.direction === "asc" ? aValue - bValue : bValue - aValue;
      }

      // Boolean comparison (true comes first in asc)
      if (typeof aValue === "boolean" && typeof bValue === "boolean") {
        return sortConfig.direction === "asc"
          ? aValue === bValue
            ? 0
            : aValue
              ? -1
              : 1
          : aValue === bValue
            ? 0
            : aValue
              ? 1
              : -1;
      }

      // Fallback: convert to string and compare
      const aStr = String(aValue).toLowerCase();
      const bStr = String(bValue).toLowerCase();
      if (aStr < bStr) return sortConfig.direction === "asc" ? -1 : 1;
      if (aStr > bStr) return sortConfig.direction === "asc" ? 1 : -1;
      return 0;
    });
  }, [data, sortConfig]);

  return {
    sortConfig,
    handleSort,
    sortedData,
  };
}

// Helper function to render sort icon
export function renderSortIcon(
  isActive: boolean,
  direction: SortDirection | undefined,
): React.ReactNode {
  if (!isActive) {
    return (
      <svg
        className="inline-block h-3 w-3 opacity-30 ml-1"
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
      >
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth={2}
          d="M7 16V4m0 0L3 8m4-4l4 4m6 0v12m0 0l4-4m-4 4l-4-4"
        />
      </svg>
    );
  }
  if (direction === "asc") {
    return (
      <svg
        className="inline-block h-3 w-3 text-[color:var(--accent-strong)] ml-1"
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
      >
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 15l7-7 7 7" />
      </svg>
    );
  }
  return (
    <svg
      className="inline-block h-3 w-3 text-[color:var(--accent-strong)] ml-1"
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
    </svg>
  );
}
