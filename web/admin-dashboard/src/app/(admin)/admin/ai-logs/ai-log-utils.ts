export function formatDateTime(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleString();
}

export function estimateTokens(value: string) {
  if (!value) return 0;
  return Math.max(1, Math.ceil(value.length / 4));
}

export function serializeJson(value: unknown, space: number = 2) {
  try {
    return JSON.stringify(value ?? null, null, space) ?? "";
  } catch {
    return String(value ?? "");
  }
}

const EMAIL_PATTERN = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi;
const PHONE_PATTERN = /\+?\d[\d\s()\-]{7,}\d/g;
const UUID_PATTERN =
  /\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b/gi;
const LONG_DIGIT_PATTERN = /\b\d{9,}\b/g;

export function maskPII(value: string) {
  return value
    .replace(EMAIL_PATTERN, "[email]")
    .replace(PHONE_PATTERN, "[phone]")
    .replace(UUID_PATTERN, "[uuid]")
    .replace(LONG_DIGIT_PATTERN, "[id]");
}
