"use client";

import type { ButtonHTMLAttributes, ReactNode } from "react";

interface LoadingButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  /**
   * Loading state
   */
  loading?: boolean;
  /**
   * Loading text suffix
   * @default "..."
   */
  loadingText?: string;
  /**
   * Icon to show alongside text
   */
  icon?: ReactNode;
  /**
   * Variant of the button
   * @default "primary"
   */
  variant?: "primary" | "secondary" | "danger" | "ghost";
  /**
   * Size of the button
   * @default "md"
   */
  size?: "sm" | "md" | "lg";
  /**
   * Full width
   */
  fullWidth?: boolean;
  children: ReactNode;
}

const variantStyles = {
  primary: "bg-[color:var(--accent)] text-white hover:bg-[color:var(--accent-strong)] focus:ring-[color:var(--accent)]",
  secondary: "border border-[color:var(--border)] bg-[color:var(--surface)] text-[color:var(--ink)] hover:bg-[color:var(--surface-soft)] focus:ring-[color:var(--border)]",
  danger: "border border-[color:var(--danger)] text-[color:var(--danger-strong)] hover:bg-[color:var(--danger)]/10 focus:ring-[color:var(--danger)]",
  ghost: "text-[color:var(--ink-muted)] hover:bg-[color:var(--surface-soft)] hover:text-[color:var(--ink)] focus:ring-[color:var(--border)]",
};

const sizeStyles = {
  sm: "px-3 py-1.5 text-xs",
  md: "px-4 py-2 text-xs",
  lg: "px-6 py-2.5 text-sm",
};

const iconSizeClasses = {
  sm: "w-3.5 h-3.5",
  md: "w-4 h-4",
  lg: "w-5 h-5",
};

export function LoadingButton({
  loading = false,
  loadingText = "…",
  icon,
  variant = "primary",
  size = "md",
  fullWidth = false,
  disabled,
  className = "",
  children,
  ...props
}: LoadingButtonProps) {
  return (
    <button
      className={`
        relative inline-flex items-center justify-center gap-2
        rounded-full font-semibold transition-all
        focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2
        disabled:cursor-not-allowed disabled:opacity-60
        ${variantStyles[variant]}
        ${sizeStyles[size]}
        ${fullWidth ? "w-full" : ""}
        ${className}
      `}
      disabled={disabled || loading}
      {...props}
    >
      {loading ? (
        <>
          <svg
            className={`animate-spin ${iconSizeClasses[size]}`}
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            aria-hidden="true"
          >
            <circle
              className="opacity-25"
              cx="12"
              cy="12"
              r="10"
              stroke="currentColor"
              strokeWidth="4"
            />
            <path
              className="opacity-75"
              fill="currentColor"
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
            />
          </svg>
          <span>
            {children} {loadingText}
          </span>
        </>
      ) : (
        <>
          {icon && <span className={iconSizeClasses[size]}>{icon}</span>}
          {children}
        </>
      )}
    </button>
  );
}

interface IconButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  /**
   * Icon to display
   */
  icon: ReactNode;
  /**
   * Accessible label (required for icon-only buttons)
   */
  label: string;
  /**
   * Variant of the button
   * @default "secondary"
   */
  variant?: "primary" | "secondary" | "ghost" | "danger";
  /**
   * Size of the button
   * @default "md"
   */
  size?: "sm" | "md" | "lg";
}

const iconButtonVariantStyles = {
  primary: "bg-[color:var(--accent)] text-white hover:bg-[color:var(--accent-strong)]",
  secondary: "bg-[color:var(--surface)] text-[color:var(--ink-muted)] border border-[color:var(--border)] hover:bg-[color:var(--surface-soft)] hover:text-[color:var(--ink)]",
  ghost: "text-[color:var(--ink-muted)] hover:bg-[color:var(--surface-soft)] hover:text-[color:var(--ink)]",
  danger: "text-[color:var(--danger-strong)] hover:bg-[color:var(--danger)]/10",
};

const iconButtonSizeStyles = {
  sm: "w-7 h-7",
  md: "w-8 h-8",
  lg: "w-10 h-10",
};

export function IconButton({
  icon,
  label,
  variant = "secondary",
  size = "md",
  className = "",
  ...props
}: IconButtonProps) {
  return (
    <button
      type="button"
      aria-label={label}
      className={`
        inline-flex items-center justify-center rounded-full
        transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--accent)]
        disabled:cursor-not-allowed disabled:opacity-50
        ${iconButtonVariantStyles[variant]}
        ${iconButtonSizeStyles[size]}
        ${className}
      `}
      {...props}
    >
      <span className={size === "sm" ? "w-3.5 h-3.5" : size === "lg" ? "w-5 h-5" : "w-4 h-4"}>
        {icon}
      </span>
    </button>
  );
}
