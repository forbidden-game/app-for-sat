"use client";

interface TrendIndicatorProps {
  /**
   * Trend value (positive, negative, or zero)
   */
  value: number;
  /**
   * Label for the trend (e.g., "vs last week")
   */
  label?: string;
  /**
   * Size variant
   * @default "sm"
   */
  size?: "sm" | "md" | "lg";
  /**
   * Custom color override
   */
  color?: "default" | "green" | "red" | "neutral";
  /**
   * Show percentage sign
   * @default true
   */
  showSign?: boolean;
  /**
   * Inverse the meaning (for metrics like "error rate" where down is good)
   */
  invert?: boolean;
  /**
   * Additional CSS classes
   */
  className?: string;
}

export function TrendIndicator({
  value,
  label,
  size = "sm",
  color = "default",
  showSign = true,
  invert = false,
  className = "",
}: TrendIndicatorProps) {
  const isPositive = invert ? value < 0 : value > 0;
  const isNegative = invert ? value > 0 : value < 0;
  const isNeutral = value === 0;

  const getColor = () => {
    if (color !== "default") {
      if (color === "green") return "text-green-600";
      if (color === "red") return "text-red-600";
      return "text-[color:var(--ink-muted)]";
    }
    if (isPositive) return "text-green-600";
    if (isNegative) return "text-red-600";
    return "text-[color:var(--ink-muted)]";
  };

  const getBgColor = () => {
    if (color !== "default") {
      if (color === "green") return "bg-green-50";
      if (color === "red") return "bg-red-50";
      return "bg-[color:var(--surface-soft)]";
    }
    if (isPositive) return "bg-green-50";
    if (isNegative) return "bg-red-50";
    return "bg-[color:var(--surface-soft)]";
  };

  const sizeClasses = {
    sm: "text-xs px-1.5 py-0.5",
    md: "text-sm px-2 py-0.5",
    lg: "text-base px-2.5 py-1",
  };

  const iconSizeClasses = {
    sm: "w-3 h-3",
    md: "w-4 h-4",
    lg: "w-5 h-5",
  };

  const formattedValue = showSign
    ? `${value > 0 ? "+" : ""}${value}%`
    : `${Math.abs(value)}%`;

  return (
    <div className={`inline-flex items-center gap-1 ${className}`}>
      <span
        className={`inline-flex items-center gap-0.5 rounded-full font-medium ${getBgColor()} ${getColor()} ${sizeClasses[size]}`}
      >
        <TrendIcon
          direction={isPositive ? "up" : isNegative ? "down" : "flat"}
          size={size}
        />
        {formattedValue}
      </span>
      {label && (
        <span className="text-xs text-[color:var(--ink-muted)]">{label}</span>
      )}
    </div>
  );
}

interface TrendIconProps {
  direction: "up" | "down" | "flat";
  size: "sm" | "md" | "lg";
}

function TrendIcon({ direction, size }: TrendIconProps) {
  const iconSizeClasses = {
    sm: "w-3 h-3",
    md: "w-3.5 h-3.5",
    lg: "w-4 h-4",
  };

  if (direction === "flat") {
    return (
      <svg
        className={`${iconSizeClasses[size]}`}
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
        strokeWidth={2}
      >
        <path strokeLinecap="round" strokeLinejoin="round" d="M5 12h14" />
      </svg>
    );
  }

  if (direction === "up") {
    return (
      <svg
        className={`${iconSizeClasses[size]}`}
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
        strokeWidth={2}
      >
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          d="M7 17l5-5 5 5M7 7l5 5 5-5"
        />
      </svg>
    );
  }

  return (
    <svg
      className={`${iconSizeClasses[size]}`}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      strokeWidth={2}
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M7 7l5 5 5-5M7 12l5-5 5 5"
      />
    </svg>
  );
}

interface MetricCardProps {
  /**
   * Metric label
   */
  label: string;
  /**
   * Main value to display
   */
  value: string | number;
  /**
   * Optional trend information
   */
  trend?: number;
  /**
   * Trend label (e.g., "vs last week")
   */
  trendLabel?: string;
  /**
   * Optional helper text
   */
  helper?: string;
  /**
   * Icon to display
   */
  icon?: React.ReactNode;
  /**
   * Additional CSS classes
   */
  className?: string;
}

export function MetricCard({
  label,
  value,
  trend,
  trendLabel,
  helper,
  icon,
  className = "",
}: MetricCardProps) {
  return (
    <div
      className={`relative overflow-hidden rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] p-4 transition-all hover:shadow-md ${className}`}
    >
      {/* Subtle gradient overlay */}
      <div className="absolute inset-0 bg-gradient-to-br from-[color:var(--accent)]/3 to-transparent pointer-events-none" />

      <div className="relative flex items-start justify-between">
        <div className="flex flex-col gap-1">
          <p className="text-xs font-medium text-[color:var(--ink-muted)]">
            {label}
          </p>
          <div className="flex items-baseline gap-2">
            <p className="text-2xl font-semibold tracking-tight text-[color:var(--ink)]">
              {value}
            </p>
            {trend !== undefined && (
              <TrendIndicator value={trend} label={trendLabel} size="sm" />
            )}
          </div>
          {helper && (
            <p className="mt-1 text-xs text-[color:var(--ink-muted)]">{helper}</p>
          )}
        </div>
        {icon && (
          <div className="rounded-lg bg-[color:var(--surface-soft)] p-2 text-[color:var(--ink-muted)]">
            {icon}
          </div>
        )}
      </div>
    </div>
  );
}
