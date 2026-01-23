"use client";

import type { ReactNode } from "react";

interface SkeletonProps {
  /**
   * Visual variant of the skeleton
   * @default "text"
   */
  variant?: "text" | "circular" | "rectangular" | "inline";
  /**
   * Width of the skeleton (any CSS width value)
   */
  width?: string;
  /**
   * Height of the skeleton (any CSS height value)
   */
  height?: string;
  /**
   * Additional CSS classes
   */
  className?: string;
  /**
   * Number of skeleton lines (for text variant)
   */
  lines?: number;
  /**
   * Children to show (when loaded)
   */
  children?: ReactNode;
}

export function Skeleton({
  variant = "text",
  width,
  height,
  className = "",
  lines = 1,
  children,
}: SkeletonProps) {
  if (children !== undefined) {
    return <>{children}</>;
  }

  const baseStyles = `
    relative overflow-hidden rounded
    bg-[color:var(--surface-strong)]
    before:absolute before:inset-0
    before:-translate-x-full before:animate-[shimmer_1.5s_infinite]
    before:bg-gradient-to-r
    before:from-transparent
    before:via-[color:var(--surface-soft)]
    before:to-transparent
  `;

  const variantStyles = {
    text: "block h-4 w-full",
    circular: "rounded-full",
    rectangular: "block rounded-lg",
    inline: "inline-block h-4 align-middle",
  };

  if (variant === "text" && lines > 1) {
    return (
      <div className={`space-y-3 ${className}`}>
        {Array.from({ length: lines }).map((_, i) => (
          <div
            key={i}
            className={`${baseStyles} ${variantStyles.text}`}
            style={i === lines - 1 && lines > 1 ? { width: "60%" } : undefined}
          />
        ))}
      </div>
    );
  }

  return (
    <div
      className={`${baseStyles} ${variantStyles[variant]} ${className}`}
      style={{ ...(width && { width }), ...(height && { height }) }}
      aria-hidden="true"
    />
  );
}

interface SkeletonCardProps {
  className?: string;
}

export function SkeletonCard({ className = "" }: SkeletonCardProps) {
  return (
    <div
      className={`rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] p-4 ${className}`}
    >
      <div className="flex items-center justify-between">
        <Skeleton variant="text" width="40%" className="mb-3" />
        <Skeleton variant="circular" width="32px" height="32px" />
      </div>
      <Skeleton variant="text" width="60%" className="mt-4" />
      <Skeleton variant="text" width="80%" className="mt-2" />
    </div>
  );
}

interface SkeletonTableProps {
  rows?: number;
  columns?: number;
  className?: string;
}

export function SkeletonTable({ rows = 5, columns = 5, className = "" }: SkeletonTableProps) {
  return (
    <div
      className={`overflow-hidden rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] ${className}`}
    >
      <div className="bg-[color:var(--surface-soft)] px-4 py-3">
        <div className="flex gap-4">
          {Array.from({ length: columns }).map((_, i) => (
            <Skeleton key={i} variant="text" width={`${100 / columns}%`} />
          ))}
        </div>
      </div>
      <div className="divide-y divide-[color:var(--border)]">
        {Array.from({ length: rows }).map((_, rowIndex) => (
          <div key={rowIndex} className="flex items-center gap-4 px-4 py-3">
            {Array.from({ length: columns }).map((_, colIndex) => (
              <Skeleton
                key={colIndex}
                variant="text"
                width={`${100 / columns}%`}
                className={colIndex === 0 ? "flex-1" : ""}
              />
            ))}
          </div>
        ))}
      </div>
    </div>
  );
}
