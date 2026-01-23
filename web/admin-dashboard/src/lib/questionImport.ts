export type ImportQuestion = {
  subject: string;
  module: string;
  difficulty: number;
  question_type: string;
  stem: string;
  answer_key: { correct: string | number };
  metadata?: Record<string, unknown>;
  options?: Array<{ label: string; content: string }>;
  tags?: Array<{ name?: string; category?: string } | string>;
};

export type ImportPayload = {
  questions: ImportQuestion[];
};

export type ImportParseError = {
  row: number;
  message: string;
};

export type ImportParseResult = {
  payload: ImportPayload | null;
  errors: ImportParseError[];
  warnings: string[];
};

type CsvRecord = Record<string, string>;

type Format = "csv" | "json";

const REQUIRED_FIELDS = [
  "subject",
  "module",
  "difficulty",
  "question_type",
  "stem",
  "answer_key",
] as const;

const ALLOWED_HEADERS = new Set([
  "subject",
  "module",
  "difficulty",
  "question_type",
  "stem",
  "answer_key",
  "options",
  "tags",
  "metadata",
]);

export function parseImportText(text: string, format: Format): ImportParseResult {
  const trimmed = text.replace(/^\uFEFF/, "").trim();
  if (!trimmed) {
    return {
      payload: null,
      errors: [{ row: 0, message: "File is empty." }],
      warnings: [],
    };
  }

  if (format === "json") {
    return parseJsonPayload(trimmed);
  }

  return parseCsvPayload(trimmed);
}

function parseJsonPayload(text: string): ImportParseResult {
  const errors: ImportParseError[] = [];
  const warnings: string[] = [];

  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    return {
      payload: null,
      errors: [{ row: 0, message: "Invalid JSON format." }],
      warnings: [],
    };
  }

  if (
    !parsed ||
    typeof parsed !== "object" ||
    !Array.isArray((parsed as { questions?: unknown }).questions)
  ) {
    return {
      payload: null,
      errors: [{ row: 0, message: "JSON must include a questions array." }],
      warnings: [],
    };
  }

  const questions = (parsed as { questions: unknown[] }).questions;
  const normalized: ImportQuestion[] = [];

  questions.forEach((item, index) => {
    const result = normalizeQuestion(item, index + 1, errors, warnings);
    if (result) {
      normalized.push(result);
    }
  });

  if (normalized.length === 0 && errors.length === 0) {
    errors.push({ row: 0, message: "No questions found in JSON." });
  }

  return {
    payload: normalized.length > 0 ? { questions: normalized } : null,
    errors,
    warnings,
  };
}

function parseCsvPayload(text: string): ImportParseResult {
  const errors: ImportParseError[] = [];
  const warnings: string[] = [];
  let rows: string[][];

  try {
    rows = parseCsvRows(text);
  } catch (err) {
    return {
      payload: null,
      errors: [{ row: 0, message: err instanceof Error ? err.message : "Invalid CSV." }],
      warnings: [],
    };
  }

  if (rows.length === 0) {
    return {
      payload: null,
      errors: [{ row: 0, message: "CSV has no rows." }],
      warnings: [],
    };
  }

  const headerRow = rows[0].map((cell) => cell.trim().toLowerCase());
  const headerIndex = new Map<string, number>();

  headerRow.forEach((name, idx) => {
    if (name) {
      headerIndex.set(name, idx);
      if (!ALLOWED_HEADERS.has(name)) {
        warnings.push(`Unknown column: ${name}`);
      }
    }
  });

  const missing = REQUIRED_FIELDS.filter((field) => !headerIndex.has(field));
  if (missing.length > 0) {
    return {
      payload: null,
      errors: [
        {
          row: 1,
          message: `Missing required columns: ${missing.join(", ")}.`,
        },
      ],
      warnings,
    };
  }

  const questions: ImportQuestion[] = [];

  rows.slice(1).forEach((row, rowIndex) => {
    const record = rowToRecord(headerIndex, row);
    if (isEmptyRecord(record)) {
      return;
    }

    const result = normalizeQuestion(record, rowIndex + 2, errors, warnings);
    if (result) {
      questions.push(result);
    }
  });

  if (questions.length === 0 && errors.length === 0) {
    errors.push({ row: 0, message: "No questions found in CSV." });
  }

  return {
    payload: questions.length > 0 ? { questions } : null,
    errors,
    warnings,
  };
}

function parseCsvRows(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = "";
  let inQuotes = false;

  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];

    if (inQuotes) {
      if (char === '"') {
        const next = text[i + 1];
        if (next === '"') {
          cell += '"';
          i += 1;
        } else {
          inQuotes = false;
        }
      } else {
        cell += char;
      }
      continue;
    }

    if (char === '"') {
      inQuotes = true;
      continue;
    }

    if (char === ",") {
      row.push(cell);
      cell = "";
      continue;
    }

    if (char === "\n") {
      row.push(cell);
      rows.push(row);
      row = [];
      cell = "";
      continue;
    }

    if (char === "\r") {
      if (text[i + 1] === "\n") {
        i += 1;
      }
      row.push(cell);
      rows.push(row);
      row = [];
      cell = "";
      continue;
    }

    cell += char;
  }

  if (inQuotes) {
    throw new Error("CSV contains an unclosed quote.");
  }

  if (cell.length > 0 || row.length > 0) {
    row.push(cell);
    rows.push(row);
  }

  return rows;
}

function rowToRecord(headerIndex: Map<string, number>, row: string[]): CsvRecord {
  const record: CsvRecord = {};
  headerIndex.forEach((index, key) => {
    record[key] = (row[index] ?? "").trim();
  });
  return record;
}

function isEmptyRecord(record: CsvRecord): boolean {
  return Object.values(record).every((value) => !value || value.trim() === "");
}

function normalizeQuestion(
  input: unknown,
  row: number,
  errors: ImportParseError[],
  warnings: string[],
): ImportQuestion | null {
  const record =
    typeof input === "object" && input !== null ? (input as Record<string, unknown>) : null;
  if (!record) {
    errors.push({ row, message: "Row is not an object." });
    return null;
  }

  const subject = readString(record, "subject");
  const moduleValue = readString(record, "module");
  const stem = readString(record, "stem");
  const questionType = readString(record, "question_type");
  const difficultyValue = record.difficulty ?? record["difficulty"];
  const answerValue = record.answer_key ?? record["answer_key"];

  if (!subject) {
    errors.push({ row, message: "Missing subject." });
  }
  if (!moduleValue) {
    errors.push({ row, message: "Missing module." });
  }
  if (!stem) {
    errors.push({ row, message: "Missing stem." });
  }
  if (!questionType) {
    errors.push({ row, message: "Missing question_type." });
  }
  if (!difficultyValue) {
    errors.push({ row, message: "Missing difficulty." });
  }
  if (answerValue === undefined || answerValue === null || `${answerValue}`.trim() === "") {
    errors.push({ row, message: "Missing answer_key." });
  }

  if (!subject || !moduleValue || !stem || !questionType || !difficultyValue || !answerValue) {
    return null;
  }

  const difficulty = Number(difficultyValue);
  if (Number.isNaN(difficulty) || difficulty <= 0) {
    errors.push({ row, message: "Difficulty must be a positive number." });
    return null;
  }

  const normalizedType = questionType.trim().toLowerCase();
  if (normalizedType !== "mcq" && normalizedType !== "numeric") {
    errors.push({ row, message: "question_type must be mcq or numeric." });
    return null;
  }

  const answerKey = normalizeAnswerKey(answerValue, row, errors);
  if (!answerKey) {
    return null;
  }

  const options = normalizeOptions(record.options, row, errors);
  const tags = normalizeTags(record.tags, row, errors);
  const metadata = normalizeMetadata(record.metadata, row, errors);

  if (normalizedType === "mcq" && (!options || options.length === 0)) {
    warnings.push(`Row ${row}: mcq without options.`);
  }

  return {
    subject,
    module: moduleValue,
    difficulty,
    question_type: normalizedType,
    stem,
    answer_key: answerKey,
    metadata: metadata ?? undefined,
    options: options ?? undefined,
    tags: tags ?? undefined,
  };
}

function readString(record: Record<string, unknown>, key: string): string {
  const value = record[key];
  if (value === undefined || value === null) return "";
  if (typeof value === "string") return value.trim();
  return `${value}`.trim();
}

function normalizeAnswerKey(
  value: unknown,
  row: number,
  errors: ImportParseError[],
): { correct: string | number } | null {
  if (typeof value === "object" && value !== null) {
    const correct = (value as { correct?: unknown }).correct;
    if (correct === undefined || correct === null || `${correct}`.trim() === "") {
      errors.push({ row, message: "answer_key.correct is required." });
      return null;
    }
    return { correct: coerceScalar(correct) };
  }

  const valueString = `${value}`.trim();
  if (!valueString) {
    errors.push({ row, message: "answer_key is required." });
    return null;
  }

  if (valueString.startsWith("{")) {
    try {
      const parsed = JSON.parse(valueString) as { correct?: unknown };
      if (parsed && parsed.correct !== undefined && parsed.correct !== null) {
        return { correct: coerceScalar(parsed.correct) };
      }
      errors.push({ row, message: "answer_key JSON must include correct." });
      return null;
    } catch {
      errors.push({ row, message: "answer_key JSON is invalid." });
      return null;
    }
  }

  const numeric = Number(valueString);
  if (!Number.isNaN(numeric) && valueString === numeric.toString()) {
    return { correct: numeric };
  }

  return { correct: valueString };
}

function normalizeOptions(
  value: unknown,
  row: number,
  errors: ImportParseError[],
): Array<{ label: string; content: string }> | null {
  if (value === undefined || value === null || `${value}`.trim() === "") {
    return null;
  }

  if (Array.isArray(value)) {
    const options = value
      .map((item) => {
        if (typeof item !== "object" || item === null) return null;
        const label = readString(item as Record<string, unknown>, "label");
        const content = readString(item as Record<string, unknown>, "content");
        if (!label || !content) return null;
        return { label, content };
      })
      .filter(Boolean) as Array<{ label: string; content: string }>;
    return options.length > 0 ? options : null;
  }

  const raw = `${value}`.trim();
  if (!raw) return null;

  if (raw.startsWith("[")) {
    try {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed)) {
        return normalizeOptions(parsed, row, errors);
      }
      errors.push({ row, message: "options must be a JSON array." });
      return null;
    } catch {
      errors.push({ row, message: "options JSON is invalid." });
      return null;
    }
  }

  const pairs = raw
    .split("|")
    .map((part) => part.trim())
    .filter(Boolean);
  if (pairs.length === 0) return null;

  const parsed = pairs
    .map((pair) => {
      const [label, ...rest] = pair.split(":");
      if (!label || rest.length === 0) return null;
      return { label: label.trim(), content: rest.join(":").trim() };
    })
    .filter(Boolean) as Array<{ label: string; content: string }>;

  if (parsed.length === 0) {
    errors.push({ row, message: "options must be JSON or label:content pairs." });
    return null;
  }

  return parsed;
}

function normalizeTags(
  value: unknown,
  row: number,
  errors: ImportParseError[],
): Array<{ name?: string; category?: string } | string> | null {
  if (value === undefined || value === null || `${value}`.trim() === "") {
    return null;
  }

  if (Array.isArray(value)) {
    const tags = value.filter(
      (item) => item !== null && item !== undefined && `${item}`.trim() !== "",
    );
    return tags.length > 0 ? (tags as Array<{ name?: string; category?: string } | string>) : null;
  }

  const raw = `${value}`.trim();
  if (!raw) return null;

  if (raw.startsWith("[")) {
    try {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed)) {
        return normalizeTags(parsed, row, errors);
      }
      errors.push({ row, message: "tags must be a JSON array." });
      return null;
    } catch {
      errors.push({ row, message: "tags JSON is invalid." });
      return null;
    }
  }

  const tags = raw
    .split(";")
    .map((item) => item.trim())
    .filter(Boolean);

  return tags.length > 0 ? tags : null;
}

function normalizeMetadata(
  value: unknown,
  row: number,
  errors: ImportParseError[],
): Record<string, unknown> | null {
  if (value === undefined || value === null || `${value}`.trim() === "") {
    return null;
  }

  if (typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }

  const raw = `${value}`.trim();
  if (!raw) return null;

  if (raw.startsWith("{")) {
    try {
      const parsed = JSON.parse(raw);
      if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
        return parsed as Record<string, unknown>;
      }
      errors.push({ row, message: "metadata must be a JSON object." });
      return null;
    } catch {
      errors.push({ row, message: "metadata JSON is invalid." });
      return null;
    }
  }

  errors.push({ row, message: "metadata must be JSON." });
  return null;
}

function coerceScalar(value: unknown): string | number {
  if (typeof value === "number") return value;
  const raw = `${value}`.trim();
  const numeric = Number(raw);
  if (!Number.isNaN(numeric) && raw === numeric.toString()) {
    return numeric;
  }
  return raw;
}
