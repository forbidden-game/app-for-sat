"use server";

import "server-only";
import { requireAdmin } from "@/lib/adminAuth";
import { recordAdminEvent } from "@/lib/adminAudit";
import type { Database } from "../../../../../../../supabase/database.types";

export type QuestionOption = {
  id: string;
  label: string;
  content: string;
};

export type QuestionTag = {
  id: string;
  name: string;
  category: string;
};

export type Question = {
  id: string;
  subject: string;
  module: string;
  difficulty: number;
  question_type: string;
  stem: string;
  answer_key: Record<string, unknown>;
  metadata: Record<string, unknown>;
  created_at: string;
  options?: QuestionOption[];
  tags?: QuestionTag[];
};

export type QuestionListItem = {
  id: string;
  subject: string;
  module: string;
  difficulty: number;
  question_type: string;
  stem: string;
  created_at: string;
  tags: { name: string }[];
};

export type QuestionInput = {
  subject: string;
  module: string;
  difficulty: number;
  question_type: string;
  stem: string;
  answer_key: Record<string, unknown>;
  metadata?: Record<string, unknown>;
};

export type OptionInput = {
  label: string;
  content: string;
};

export type QuestionType = {
  id: string;
  name: string;
  display_name: string;
  is_active: boolean;
};

export type QuestionSortField =
  | "created_at"
  | "subject"
  | "module"
  | "difficulty"
  | "question_type";
export type SortDirection = "asc" | "desc";

export type ListQuestionsParams = {
  page?: number;
  pageSize?: number;
  search?: string;
  subject?: string;
  module?: string;
  difficulty?: number;
  question_type?: string;
  sortBy?: QuestionSortField;
  sortDirection?: SortDirection;
};

export type ListQuestionsResult = {
  questions: QuestionListItem[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
};

function validateQuestionInput(input: QuestionInput) {
  const subject = input.subject.trim();
  const questionModule = input.module.trim();
  const stem = input.stem.trim();
  const questionType = input.question_type.trim();

  if (!subject) throw new Error("Subject is required.");
  if (!questionModule) throw new Error("Module is required.");
  if (!stem) throw new Error("Question stem is required.");
  if (!questionType) throw new Error("Question type is required.");
  if (!Number.isFinite(input.difficulty) || input.difficulty < 1 || input.difficulty > 5) {
    throw new Error("Difficulty must be between 1 and 5.");
  }
  if (!input.answer_key || typeof input.answer_key !== "object") {
    throw new Error("Answer key is required.");
  }

  return {
    subject,
    module: questionModule,
    difficulty: input.difficulty,
    question_type: questionType,
    stem,
    answer_key: input.answer_key,
    metadata: input.metadata ?? {},
  };
}

export async function listQuestions(
  accessToken: string,
  params: ListQuestionsParams = {},
): Promise<ListQuestionsResult> {
  const { supabase } = await requireAdmin(accessToken);
  const page = params.page ?? 1;
  const pageSize = params.pageSize ?? 20;
  const offset = (page - 1) * pageSize;

  let query = supabase.from("questions").select(
    `
      id, subject, module, difficulty, question_type, stem, created_at,
      question_tags(tags(name))
    `,
    { count: "exact" },
  );

  if (params.search) {
    query = query.ilike("stem", `%${params.search}%`);
  }
  if (params.subject) {
    query = query.eq("subject", params.subject);
  }
  if (params.module) {
    query = query.eq("module", params.module);
  }
  if (params.difficulty) {
    query = query.eq("difficulty", params.difficulty);
  }
  if (params.question_type) {
    query = query.eq("question_type", params.question_type);
  }

  const sortBy =
    params.sortBy &&
    ["created_at", "subject", "module", "difficulty", "question_type"].includes(params.sortBy)
      ? params.sortBy
      : "created_at";
  const sortDirection = params.sortDirection === "asc" ? "asc" : "desc";

  query = query
    .order(sortBy, { ascending: sortDirection === "asc" })
    .range(offset, offset + pageSize - 1);

  const { data, error, count } = await query;

  if (error) {
    throw new Error("Failed to load questions.");
  }

  const questions: QuestionListItem[] = (data ?? []).map((q: Record<string, unknown>) => ({
    id: q.id as string,
    subject: q.subject as string,
    module: q.module as string,
    difficulty: q.difficulty as number,
    question_type: q.question_type as string,
    stem: q.stem as string,
    created_at: q.created_at as string,
    tags: ((q.question_tags as { tags: { name: string } }[]) ?? []).map((qt) => ({
      name: qt.tags?.name ?? "",
    })),
  }));

  const total = count ?? 0;

  return {
    questions,
    total,
    page,
    pageSize,
    totalPages: Math.ceil(total / pageSize),
  };
}

export async function getQuestion(accessToken: string, id: string): Promise<Question> {
  const { supabase } = await requireAdmin(accessToken);

  const { data, error } = await supabase
    .from("questions")
    .select(
      `
      id, subject, module, difficulty, question_type, stem, answer_key, metadata, created_at,
      question_options(id, label, content),
      question_tags(tag_id, tags(id, name, category))
    `,
    )
    .eq("id", id)
    .single();

  if (error || !data) {
    throw new Error("Question not found.");
  }

  const record = data as unknown as {
    id: string;
    subject: string;
    module: string;
    difficulty: number;
    question_type: string;
    stem: string;
    answer_key: Record<string, unknown> | null;
    metadata: Record<string, unknown> | null;
    created_at: string;
    question_options: Array<{ id: string; label: string; content: string }> | null;
    question_tags: Array<{
      tag_id: string;
      tags: { id: string; name: string; category: string } | null;
    }> | null;
  };
  const rawOptions = record.question_options;
  const rawTags = record.question_tags;

  return {
    id: record.id,
    subject: record.subject,
    module: record.module,
    difficulty: record.difficulty,
    question_type: record.question_type,
    stem: record.stem,
    answer_key: record.answer_key ?? {},
    metadata: record.metadata ?? {},
    created_at: record.created_at,
    options: (rawOptions ?? []).sort((a, b) => a.label.localeCompare(b.label)),
    tags: (rawTags ?? []).filter((qt) => qt.tags !== null).map((qt) => qt.tags as QuestionTag),
  };
}

export async function createQuestion(
  accessToken: string,
  input: QuestionInput,
  options: OptionInput[],
  tagIds: string[],
): Promise<Question> {
  const context = await requireAdmin(accessToken);
  const { supabase } = context;
  const payload = validateQuestionInput(input);
  const insertPayload = payload as unknown as Database["public"]["Tables"]["questions"]["Insert"];

  const { data: question, error: questionError } = await supabase
    .from("questions")
    .insert(insertPayload)
    .select(
      "id, subject, module, difficulty, question_type, stem, answer_key, metadata, created_at",
    )
    .single();

  if (questionError || !question) {
    throw new Error(questionError?.message ?? "Failed to create question.");
  }

  try {
    if (options.length > 0) {
      const optionPayload = options.map((opt) => ({
        question_id: question.id,
        label: opt.label.trim(),
        content: opt.content.trim(),
      }));
      const { error: optError } = await supabase.from("question_options").insert(optionPayload);
      if (optError) {
        throw new Error(`Failed to create options: ${optError.message}`);
      }
    }

    if (tagIds.length > 0) {
      const tagPayload = tagIds.map((tagId) => ({
        question_id: question.id,
        tag_id: tagId,
      }));
      const { error: tagError } = await supabase.from("question_tags").insert(tagPayload);
      if (tagError) {
        throw new Error(`Failed to assign tags: ${tagError.message}`);
      }
    }
  } catch (err) {
    await supabase.from("questions").delete().eq("id", question.id);
    throw err;
  }

  await recordAdminEvent(context, {
    action: "question.create",
    resourceType: "questions",
    resourceId: question.id,
    metadata: {
      subject: payload.subject,
      module: payload.module,
      difficulty: payload.difficulty,
    },
  });

  return getQuestion(accessToken, question.id);
}

export async function updateQuestion(
  accessToken: string,
  id: string,
  input: QuestionInput,
  options: OptionInput[],
  tagIds: string[],
): Promise<Question> {
  const context = await requireAdmin(accessToken);
  const { supabase } = context;
  const payload = validateQuestionInput(input);
  const updatePayload = payload as unknown as Database["public"]["Tables"]["questions"]["Update"];

  const { error: questionError } = await supabase
    .from("questions")
    .update(updatePayload)
    .eq("id", id);

  if (questionError) {
    throw new Error(questionError.message);
  }

  const { error: optionsDeleteError } = await supabase
    .from("question_options")
    .delete()
    .eq("question_id", id);
  if (optionsDeleteError) {
    throw new Error(`Failed to reset options: ${optionsDeleteError.message}`);
  }

  if (options.length > 0) {
    const optionPayload = options.map((opt) => ({
      question_id: id,
      label: opt.label.trim(),
      content: opt.content.trim(),
    }));
    const { error: optError } = await supabase.from("question_options").insert(optionPayload);
    if (optError) {
      throw new Error(`Failed to update options: ${optError.message}`);
    }
  }

  const { error: tagsDeleteError } = await supabase
    .from("question_tags")
    .delete()
    .eq("question_id", id);
  if (tagsDeleteError) {
    throw new Error(`Failed to reset tags: ${tagsDeleteError.message}`);
  }

  if (tagIds.length > 0) {
    const tagPayload = tagIds.map((tagId) => ({
      question_id: id,
      tag_id: tagId,
    }));
    const { error: tagError } = await supabase.from("question_tags").insert(tagPayload);
    if (tagError) {
      throw new Error(`Failed to update tags: ${tagError.message}`);
    }
  }

  await recordAdminEvent(context, {
    action: "question.update",
    resourceType: "questions",
    resourceId: id,
    metadata: {
      subject: payload.subject,
      module: payload.module,
      difficulty: payload.difficulty,
    },
  });

  return getQuestion(accessToken, id);
}

export async function deleteQuestion(accessToken: string, id: string) {
  const context = await requireAdmin(accessToken);
  const { supabase } = context;
  const { error } = await supabase.from("questions").delete().eq("id", id);

  if (error) {
    throw new Error(error.message);
  }

  await recordAdminEvent(context, {
    action: "question.delete",
    resourceType: "questions",
    resourceId: id,
  });
}

export async function listQuestionTypes(accessToken: string): Promise<QuestionType[]> {
  const { supabase } = await requireAdmin(accessToken);
  const { data, error } = await supabase
    .from("question_types")
    .select("id, name, display_name, is_active")
    .eq("is_active", true)
    .order("sort_order", { ascending: true });

  if (error) {
    throw new Error("Failed to load question types.");
  }

  return data as QuestionType[];
}

export type QuestionAsset = {
  id: string;
  asset_url: string;
  asset_type: string;
  storage_path: string | null;
};

export async function listQuestionAssets(
  accessToken: string,
  questionId: string,
): Promise<QuestionAsset[]> {
  const { supabase } = await requireAdmin(accessToken);
  const { data, error } = await supabase
    .from("question_assets")
    .select("id, asset_url, asset_type, storage_path")
    .eq("question_id", questionId)
    .eq("status", "active")
    .order("created_at", { ascending: true });

  if (error) {
    throw new Error("Failed to load assets.");
  }
  return data as QuestionAsset[];
}

export async function createQuestionAsset(
  accessToken: string,
  questionId: string,
  assetUrl: string,
  assetType: string,
  storagePath: string,
): Promise<QuestionAsset> {
  const context = await requireAdmin(accessToken);
  const { supabase, admin } = context;
  const { data, error } = await supabase
    .from("question_assets")
    .insert({
      question_id: questionId,
      asset_url: assetUrl,
      asset_type: assetType,
      storage_path: storagePath,
      status: "active",
      created_by: admin.id,
    })
    .select("id, asset_url, asset_type, storage_path")
    .single();

  if (error) {
    throw new Error(error.message);
  }

  await recordAdminEvent(context, {
    action: "question_asset.create",
    resourceType: "question_assets",
    resourceId: data.id,
    metadata: { question_id: questionId, asset_type: assetType },
  });

  return data as QuestionAsset;
}

export async function deleteQuestionAsset(accessToken: string, assetId: string) {
  const context = await requireAdmin(accessToken);
  const { supabase } = context;
  const { error } = await supabase
    .from("question_assets")
    .update({ status: "deleted" })
    .eq("id", assetId);

  if (error) {
    throw new Error(error.message);
  }

  await recordAdminEvent(context, {
    action: "question_asset.delete",
    resourceType: "question_assets",
    resourceId: assetId,
  });
}

export async function getDistinctValues(
  accessToken: string,
  field: "subject" | "module",
): Promise<string[]> {
  const { supabase } = await requireAdmin(accessToken);
  const values = new Set<string>();
  const pageSize = 1000;
  let offset = 0;

  while (true) {
    const { data, error } = await supabase
      .from("questions")
      .select(field)
      .order(field, { ascending: true })
      .range(offset, offset + pageSize - 1);

    if (error) {
      return [];
    }

    const rows = (data ?? []) as Array<Record<string, string>>;
    for (const row of rows) {
      const value = row[field];
      if (value) values.add(value);
    }

    if (rows.length < pageSize) break;
    offset += pageSize;
  }

  return Array.from(values);
}
