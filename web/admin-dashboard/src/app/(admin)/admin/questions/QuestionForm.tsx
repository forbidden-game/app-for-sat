"use client";

import { useEffect, useState } from "react";
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
  onSubmit: (
    input: QuestionInput,
    options: OptionInput[],
    tagIds: string[],
  ) => Promise<void>;
  onCancel: () => void;
  saving: boolean;
};

export function QuestionForm({
  initialData,
  onSubmit,
  onCancel,
  saving,
}: QuestionFormProps) {
  const supabase = getSupabaseClient();
  const isEdit = Boolean(initialData);

  const [subject, setSubject] = useState(initialData?.subject ?? "");
  const [module, setModule] = useState(initialData?.module ?? "");
  const [difficulty, setDifficulty] = useState(initialData?.difficulty ?? 3);
  const [questionType, setQuestionType] = useState(
    initialData?.question_type ?? "mcq",
  );
  const [stem, setStem] = useState(initialData?.stem ?? "");
  const [answerKey, setAnswerKey] = useState<Record<string, unknown>>(
    initialData?.answer_key ?? { correct: "" },
  );
  const [options, setOptions] = useState<OptionInput[]>(
    initialData?.options?.map((o) => ({ label: o.label, content: o.content })) ??
      [
        { label: "A", content: "" },
        { label: "B", content: "" },
        { label: "C", content: "" },
        { label: "D", content: "" },
      ],
  );
  const [selectedTagIds, setSelectedTagIds] = useState<string[]>(
    initialData?.tags?.map((t) => t.id) ?? [],
  );

  const [subjects, setSubjects] = useState<string[]>([]);
  const [modules, setModules] = useState<string[]>([]);
  const [questionTypes, setQuestionTypes] = useState<QuestionType[]>([]);
  const [allTags, setAllTags] = useState<Tag[]>([]);
  const [loadingMeta, setLoadingMeta] = useState(true);

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

  function handleOptionChange(index: number, field: "label" | "content", value: string) {
    setOptions((prev) =>
      prev.map((opt, i) => (i === index ? { ...opt, [field]: value } : opt)),
    );
  }

  function addOption() {
    const nextLabel = String.fromCharCode(65 + options.length);
    setOptions((prev) => [...prev, { label: nextLabel, content: "" }]);
  }

  function removeOption(index: number) {
    setOptions((prev) => prev.filter((_, i) => i !== index));
  }

  function toggleTag(tagId: string) {
    setSelectedTagIds((prev) =>
      prev.includes(tagId) ? prev.filter((id) => id !== tagId) : [...prev, tagId],
    );
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

    const validOptions =
      questionType === "mcq"
        ? options.filter((o) => o.label.trim() && o.content.trim())
        : [];

    await onSubmit(input, validOptions, selectedTagIds);
  }

  const isMCQ = questionType === "mcq";
  const tagsByCategory = allTags.reduce(
    (acc, tag) => {
      if (!acc[tag.category]) acc[tag.category] = [];
      acc[tag.category].push(tag);
      return acc;
    },
    {} as Record<string, Tag[]>,
  );

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-6">
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <label className="grid gap-1 text-sm">
          Subject
          <input
            list="subjects-list"
            className="rounded-lg border border-zinc-200 px-3 py-2 text-sm"
            value={subject}
            onChange={(e) => setSubject(e.target.value)}
            placeholder="e.g., math"
            required
          />
          <datalist id="subjects-list">
            {subjects.map((s) => (
              <option key={s} value={s} />
            ))}
          </datalist>
        </label>

        <label className="grid gap-1 text-sm">
          Module
          <input
            list="modules-list"
            className="rounded-lg border border-zinc-200 px-3 py-2 text-sm"
            value={module}
            onChange={(e) => setModule(e.target.value)}
            placeholder="e.g., algebra"
            required
          />
          <datalist id="modules-list">
            {modules.map((m) => (
              <option key={m} value={m} />
            ))}
          </datalist>
        </label>

        <label className="grid gap-1 text-sm">
          Difficulty
          <select
            className="rounded-lg border border-zinc-200 px-3 py-2 text-sm"
            value={difficulty}
            onChange={(e) => setDifficulty(Number(e.target.value))}
          >
            {[1, 2, 3, 4, 5].map((d) => (
              <option key={d} value={d}>
                {d} - {["Easy", "Easy-Med", "Medium", "Med-Hard", "Hard"][d - 1]}
              </option>
            ))}
          </select>
        </label>

        <label className="grid gap-1 text-sm">
          Question Type
          <select
            className="rounded-lg border border-zinc-200 px-3 py-2 text-sm"
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

      <label className="grid gap-1 text-sm">
        Question Stem
        <textarea
          className="min-h-[120px] rounded-lg border border-zinc-200 px-3 py-2 text-sm"
          value={stem}
          onChange={(e) => setStem(e.target.value)}
          placeholder="Enter the question text..."
          required
        />
      </label>

      {isMCQ && (
        <div className="flex flex-col gap-3">
          <div className="flex items-center justify-between">
            <span className="text-sm font-medium text-zinc-700">Options</span>
            <button
              type="button"
              onClick={addOption}
              className="rounded-lg border border-zinc-200 px-3 py-1 text-xs text-zinc-700 hover:border-zinc-300"
            >
              + Add Option
            </button>
          </div>
          {options.map((opt, index) => (
            <div key={index} className="flex items-center gap-2">
              <input
                className="w-12 rounded-lg border border-zinc-200 px-2 py-2 text-center text-sm font-medium"
                value={opt.label}
                onChange={(e) => handleOptionChange(index, "label", e.target.value)}
                placeholder="A"
                aria-label={`Option ${index + 1} label`}
              />
              <input
                className="flex-1 rounded-lg border border-zinc-200 px-3 py-2 text-sm"
                value={opt.content}
                onChange={(e) => handleOptionChange(index, "content", e.target.value)}
                placeholder="Option content..."
                aria-label={`Option ${index + 1} content`}
              />
              <label className="flex items-center gap-1 text-sm">
                <input
                  type="radio"
                  name="correct-answer"
                  checked={answerKey.correct === opt.label}
                  onChange={() => setAnswerKey({ correct: opt.label })}
                />
                Correct
              </label>
              {options.length > 2 && (
                <button
                  type="button"
                  onClick={() => removeOption(index)}
                  className="text-red-500 hover:text-red-700"
                  aria-label={`Remove option ${index + 1}`}
                >
                  ×
                </button>
              )}
            </div>
          ))}
        </div>
      )}

      {!isMCQ && (
        <label className="grid gap-1 text-sm">
          Correct Answer
          <input
            className="rounded-lg border border-zinc-200 px-3 py-2 text-sm"
            value={String(answerKey.correct ?? "")}
            onChange={(e) => {
              const val = e.target.value;
              const numVal = Number(val);
              setAnswerKey({
                correct: !isNaN(numVal) && val.trim() !== "" ? numVal : val,
              });
            }}
            placeholder={questionType === "numeric" ? "e.g., 42" : "Correct answer..."}
          />
        </label>
      )}

      <div className="flex flex-col gap-3">
        <span className="text-sm font-medium text-zinc-700">Tags</span>
        {Object.keys(tagsByCategory).length === 0 ? (
          <p className="text-sm text-zinc-500">No tags available.</p>
        ) : (
          <div className="flex flex-col gap-3">
            {Object.entries(tagsByCategory).map(([category, tags]) => (
              <div key={category} className="flex flex-wrap items-center gap-2">
                <span className="text-xs font-medium text-zinc-500 capitalize w-16">
                  {category}:
                </span>
                {tags.map((tag) => (
                  <button
                    key={tag.id}
                    type="button"
                    onClick={() => toggleTag(tag.id)}
                    className={`rounded-full px-3 py-1 text-xs transition ${
                      selectedTagIds.includes(tag.id)
                        ? "bg-zinc-900 text-white"
                        : "border border-zinc-200 text-zinc-700 hover:border-zinc-300"
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

      <div className="flex gap-3 pt-4 border-t border-zinc-100">
        <button
          type="submit"
          disabled={saving}
          className="rounded-lg bg-zinc-900 px-6 py-2 text-sm font-semibold text-white disabled:opacity-60"
        >
          {saving ? "Saving..." : isEdit ? "Save Changes" : "Create Question"}
        </button>
        <button
          type="button"
          onClick={onCancel}
          className="rounded-lg border border-zinc-200 px-6 py-2 text-sm text-zinc-700"
        >
          Cancel
        </button>
      </div>
    </form>
  );
}
