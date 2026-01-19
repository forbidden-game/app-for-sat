"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { getSupabaseClient } from "@/lib/supabaseClient";
import { listTags, type Tag } from "../tags/actions";
import {
  listQuestionTypes,
  getDistinctValues,
  type Question,
  type QuestionInput,
  type OptionInput,
  type QuestionType,
} from "./actions";

type QuestionFormProps = {
  initialData?: Question;
  onSubmit: (input: QuestionInput, options: OptionInput[], tagIds: string[]) => Promise<void>;
  onCancel: () => void;
  saving: boolean;
};

export function QuestionForm({ initialData, onSubmit, onCancel, saving }: QuestionFormProps) {
  const supabase = getSupabaseClient();
  const isEdit = Boolean(initialData);

  const initialOptions =
    initialData?.options?.map((o) => ({ label: o.label, content: o.content })) ?? [
      { label: "A", content: "" },
      { label: "B", content: "" },
      { label: "C", content: "" },
      { label: "D", content: "" },
    ];
  const initialTagIds = initialData?.tags?.map((t) => t.id) ?? [];
  const initialAnswerKey = initialData?.answer_key ?? { correct: "" };

  const [subject, setSubject] = useState(initialData?.subject ?? "");
  const [module, setModule] = useState(initialData?.module ?? "");
  const [difficulty, setDifficulty] = useState(initialData?.difficulty ?? 3);
  const [questionType, setQuestionType] = useState(initialData?.question_type ?? "mcq");
  const [stem, setStem] = useState(initialData?.stem ?? "");
  const [answerKey, setAnswerKey] = useState<Record<string, unknown>>(initialAnswerKey);
  const [options, setOptions] = useState<OptionInput[]>(initialOptions);
  const [selectedTagIds, setSelectedTagIds] = useState<string[]>(initialTagIds);

  const [subjects, setSubjects] = useState<string[]>([]);
  const [modules, setModules] = useState<string[]>([]);
  const [questionTypes, setQuestionTypes] = useState<QuestionType[]>([]);
  const [allTags, setAllTags] = useState<Tag[]>([]);
  const [loadingMeta, setLoadingMeta] = useState(true);
  const initialSnapshot = useRef(
    JSON.stringify({
      subject: initialData?.subject ?? "",
      module: initialData?.module ?? "",
      difficulty: initialData?.difficulty ?? 3,
      questionType: initialData?.question_type ?? "mcq",
      stem: initialData?.stem ?? "",
      answerKey: initialAnswerKey,
      options: initialOptions,
      selectedTagIds: initialTagIds,
    }),
  );
  const isDirty = useMemo(() => {
    const snapshot = JSON.stringify({
      subject,
      module,
      difficulty,
      questionType,
      stem,
      answerKey,
      options,
      selectedTagIds,
    });
    return snapshot !== initialSnapshot.current;
  }, [subject, module, difficulty, questionType, stem, answerKey, options, selectedTagIds]);

  useEffect(() => {
    async function loadMeta() {
      if (!supabase) return;
      const { data: sessionData } = await supabase.auth.getSession();
      const session = sessionData.session;
      if (!session) return;

      try {
        const [subjectList, moduleList, typeList, tagList] = await Promise.all([
          getDistinctValues(session.access_token, "subject"),
          getDistinctValues(session.access_token, "module"),
          listQuestionTypes(session.access_token),
          listTags(session.access_token),
        ]);
        setSubjects(subjectList);
        setModules(moduleList);
        setQuestionTypes(typeList);
        setAllTags(tagList);
      } catch {
      } finally {
        setLoadingMeta(false);
      }
    }
    loadMeta();
  }, [supabase]);

  useEffect(() => {
    function handleBeforeUnload(event: BeforeUnloadEvent) {
      if (!isDirty) return;
      event.preventDefault();
      event.returnValue = "";
    }

    window.addEventListener("beforeunload", handleBeforeUnload);
    return () => window.removeEventListener("beforeunload", handleBeforeUnload);
  }, [isDirty]);

  function handleOptionChange(index: number, field: "label" | "content", value: string) {
    setOptions((prev) => prev.map((opt, i) => (i === index ? { ...opt, [field]: value } : opt)));
  }

  function addOption() {
    const nextLabel = String.fromCharCode(65 + options.length);
    setOptions((prev) => [...prev, { label: nextLabel, content: "" }]);
  }

  function removeOption(index: number) {
    setOptions((prev) => prev.filter((_, i) => i !== index));
  }

  function toggleTag(tagId: string) {
    setSelectedTagIds((prev) => (prev.includes(tagId) ? prev.filter((id) => id !== tagId) : [...prev, tagId]));
  }

  function handleCancel() {
    if (isDirty && !window.confirm("Discard unsaved changes?")) return;
    onCancel();
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();

    const input: QuestionInput = {
      subject,
      module,
      difficulty,
      question_type: questionType,
      stem,
      answer_key: answerKey,
    };

    const validOptions = questionType === "mcq" ? options.filter((o) => o.label.trim() && o.content.trim()) : [];

    await onSubmit(input, validOptions, selectedTagIds);
  }

  const isMCQ = questionType === "mcq";
  const tagsByCategory = useMemo(
    () =>
      allTags.reduce(
        (acc, tag) => {
          if (!acc[tag.category]) acc[tag.category] = [];
          acc[tag.category].push(tag);
          return acc;
        },
        {} as Record<string, Tag[]>,
      ),
    [allTags],
  );

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-6">
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <label className="grid gap-1 text-xs font-medium text-[color:var(--ink-muted)]">
          Subject
          <input
            list="subjects-list"
            name="subject"
            className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
            value={subject}
            onChange={(e) => setSubject(e.target.value)}
            placeholder="e.g., math…"
            autoComplete="off"
            required
          />
          <datalist id="subjects-list">
            {subjects.map((s) => (
              <option key={s} value={s} />
            ))}
          </datalist>
        </label>

        <label className="grid gap-1 text-xs font-medium text-[color:var(--ink-muted)]">
          Module
          <input
            list="modules-list"
            name="module"
            className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
            value={module}
            onChange={(e) => setModule(e.target.value)}
            placeholder="e.g., algebra…"
            autoComplete="off"
            required
          />
          <datalist id="modules-list">
            {modules.map((m) => (
              <option key={m} value={m} />
            ))}
          </datalist>
        </label>

        <label className="grid gap-1 text-xs font-medium text-[color:var(--ink-muted)]">
          Difficulty
          <select
            name="difficulty"
            className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
            value={difficulty}
            onChange={(e) => setDifficulty(Number(e.target.value))}
          >
            {[1, 2, 3, 4, 5].map((d) => (
              <option key={d} value={d}>
                {d} - {"Easy,Easy-Med,Medium,Med-Hard,Hard".split(",")[d - 1]}
              </option>
            ))}
          </select>
        </label>

        <label className="grid gap-1 text-xs font-medium text-[color:var(--ink-muted)]">
          Question Type
          <select
            name="questionType"
            className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
            value={questionType}
            onChange={(e) => setQuestionType(e.target.value)}
            disabled={loadingMeta}
          >
            {questionTypes.map((qt) => (
              <option key={qt.name} value={qt.name}>
                {qt.display_name}
              </option>
            ))}
          </select>
        </label>
      </div>

      <label className="grid gap-1 text-xs font-medium text-[color:var(--ink-muted)]">
        Question Stem
        <textarea
          name="stem"
          className="min-h-[120px] rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
          value={stem}
          onChange={(e) => setStem(e.target.value)}
          placeholder="Enter the question text…"
          autoComplete="off"
          required
        />
      </label>

      {isMCQ ? (
        <div className="flex flex-col gap-3">
          <div className="flex items-center justify-between">
            <span className="text-sm font-medium text-[color:var(--ink)]">Options</span>
            <button
              type="button"
              onClick={addOption}
              className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-1 text-xs font-medium text-[color:var(--ink-muted)] transition hover:border-[color:var(--accent)] hover:text-[color:var(--ink)]"
            >
              Add Option
            </button>
          </div>
          {options.map((opt, index) => (
            <div key={index} className="flex items-center gap-2">
              <input
                name={`option-label-${index}`}
                className="w-12 rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-2 py-2 text-center text-sm font-medium text-[color:var(--ink)]"
                value={opt.label}
                onChange={(e) => handleOptionChange(index, "label", e.target.value)}
                placeholder="A…"
                autoComplete="off"
                aria-label={`Option ${index + 1} label`}
              />
              <input
                name={`option-content-${index}`}
                className="flex-1 rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
                value={opt.content}
                onChange={(e) => handleOptionChange(index, "content", e.target.value)}
                placeholder="Option content…"
                autoComplete="off"
                aria-label={`Option ${index + 1} content`}
              />
              <label className="flex items-center gap-1 text-xs text-[color:var(--ink-muted)]">
                <input
                  type="radio"
                  name="correct-answer"
                  checked={answerKey.correct === opt.label}
                  onChange={() => setAnswerKey({ correct: opt.label })}
                  autoComplete="off"
                />
                Correct
              </label>
              {options.length > 2 ? (
                <button
                  type="button"
                  onClick={() => removeOption(index)}
                  className="text-[color:var(--danger-strong)] transition hover:text-[color:var(--danger)]"
                  aria-label={`Remove option ${index + 1}`}
                >
                  ×
                </button>
              ) : null}
            </div>
          ))}
        </div>
      ) : (
        <label className="grid gap-1 text-xs font-medium text-[color:var(--ink-muted)]">
          Correct Answer
          <input
            name="answer"
            type={questionType === "numeric" ? "number" : "text"}
            inputMode={questionType === "numeric" ? "decimal" : "text"}
            className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
            value={String(answerKey.correct ?? "")}
            onChange={(e) => {
              const val = e.target.value;
              const numVal = Number(val);
              setAnswerKey({
                correct: !isNaN(numVal) && val.trim() !== "" ? numVal : val,
              });
            }}
            placeholder={questionType === "numeric" ? "e.g., 42…" : "Correct answer…"}
            autoComplete="off"
          />
        </label>
      )}

      <div className="flex flex-col gap-3">
        <span className="text-sm font-medium text-[color:var(--ink)]">Tags</span>
        {Object.keys(tagsByCategory).length === 0 ? (
          <p className="text-sm text-[color:var(--ink-muted)]">No tags available.</p>
        ) : (
          <div className="flex flex-col gap-3">
            {Object.entries(tagsByCategory).map(([category, tags]) => (
              <div key={category} className="flex flex-wrap items-center gap-2">
                <span className="w-16 text-xs font-medium text-[color:var(--ink-muted)] capitalize">{category}:</span>
                {tags.map((tag) => (
                  <button
                    key={tag.id}
                    type="button"
                    onClick={() => toggleTag(tag.id)}
                    className={`rounded-full px-3 py-1 text-xs font-medium transition ${
                      selectedTagIds.includes(tag.id)
                        ? "bg-[color:var(--accent-strong)] text-white"
                        : "border border-[color:var(--border)] text-[color:var(--ink-muted)] hover:border-[color:var(--accent)] hover:text-[color:var(--ink)]"
                    }`}
                  >
                    {tag.name}
                  </button>
                ))}
              </div>
            ))}
          </div>
        )}
      </div>

      <div className="flex gap-3 border-t border-[color:var(--border)] pt-4">
        <button
          type="submit"
          disabled={saving}
          className="rounded-full bg-[color:var(--accent)] px-6 py-2 text-xs font-semibold text-white transition hover:bg-[color:var(--accent-strong)] disabled:opacity-60"
        >
          {saving ? "Saving…" : isEdit ? "Save Changes" : "Create Question"}
        </button>
        <button
          type="button"
          onClick={handleCancel}
          className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-6 py-2 text-xs font-medium text-[color:var(--ink-muted)] transition hover:border-[color:var(--accent)] hover:text-[color:var(--ink)]"
        >
          Cancel
        </button>
      </div>
    </form>
  );
}
