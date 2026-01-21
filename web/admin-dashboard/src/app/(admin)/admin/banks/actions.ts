"use server";

import "server-only";
import { requireAdmin } from "@/lib/adminAuth";
import { recordAdminEvent } from "@/lib/adminAudit";

const BANK_MODES = ["fixed", "daily_mix"] as const;

export type QuestionBank = {
  id: string;
  slug: string;
  title: string;
  subtitle: string | null;
  icon: string | null;
  mode: (typeof BANK_MODES)[number];
  question_limit: number;
  rule_json: Record<string, unknown>;
  is_active: boolean;
  sort_order: number;
  created_at: string;
};

export type QuestionBankInput = {
  slug: string;
  title: string;
  subtitle: string;
  icon: string;
  mode: string;
  question_limit: number;
  is_active: boolean;
  sort_order: number;
  rule_json: string;
};

function parseRuleJson(raw: string) {
  if (!raw.trim()) return {};
  try {
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed === "object") return parsed as Record<string, unknown>;
    throw new Error("Rule JSON must be an object.");
  } catch (error) {
    if (error instanceof Error) {
      throw new Error(`Invalid rule JSON: ${error.message}`);
    }
    throw new Error("Invalid rule JSON.");
  }
}

function validateBankInput(input: QuestionBankInput) {
  const slug = input.slug.trim();
  const title = input.title.trim();
  const subtitle = input.subtitle.trim();
  const icon = input.icon.trim();
  const mode = input.mode.trim();

  if (!slug) {
    throw new Error("Slug is required.");
  }
  if (!/^[a-z0-9_-]+$/.test(slug)) {
    throw new Error("Slug must be lowercase letters, numbers, dashes, or underscores.");
  }
  if (!title) {
    throw new Error("Title is required.");
  }
  if (!BANK_MODES.includes(mode as (typeof BANK_MODES)[number])) {
    throw new Error("Mode must be fixed or daily_mix.");
  }
  if (!Number.isFinite(input.question_limit) || input.question_limit < 1) {
    throw new Error("Question limit must be a positive number.");
  }
  if (!Number.isFinite(input.sort_order)) {
    throw new Error("Sort order must be a number.");
  }

  return {
    slug,
    title,
    subtitle: subtitle.length > 0 ? subtitle : null,
    icon: icon.length > 0 ? icon : null,
    mode: mode as (typeof BANK_MODES)[number],
    question_limit: Math.trunc(input.question_limit),
    rule_json: parseRuleJson(input.rule_json),
    is_active: Boolean(input.is_active),
    sort_order: Math.trunc(input.sort_order),
  };
}

export async function listQuestionBanks(accessToken: string) {
  const { supabase } = await requireAdmin(accessToken);
  const { data, error } = await supabase
    .from("question_banks")
    .select(
      "id, slug, title, subtitle, icon, mode, question_limit, rule_json, is_active, sort_order, created_at",
    )
    .order("sort_order", { ascending: true })
    .order("created_at", { ascending: false });

  if (error) {
    throw new Error("Failed to load question banks.");
  }
  return (data ?? []) as QuestionBank[];
}

export async function createQuestionBank(accessToken: string, input: QuestionBankInput) {
  const context = await requireAdmin(accessToken);
  const { supabase } = context;
  const payload = validateBankInput(input);
  const insertPayload = payload as unknown as never;
  const { data, error } = await supabase
    .from("question_banks")
    .insert(insertPayload)
    .select(
      "id, slug, title, subtitle, icon, mode, question_limit, rule_json, is_active, sort_order, created_at",
    )
    .single();

  if (error || !data) {
    throw new Error(error?.message ?? "Failed to create question bank.");
  }

  const createdBank = data as unknown as QuestionBank;

  await recordAdminEvent(context, {
    action: "bank.create",
    resourceType: "question_banks",
    resourceId: createdBank.id,
    metadata: { slug: payload.slug, mode: payload.mode },
  });

  return createdBank;
}

export async function updateQuestionBank(
  accessToken: string,
  id: string,
  input: QuestionBankInput,
) {
  const context = await requireAdmin(accessToken);
  const { supabase } = context;
  const payload = validateBankInput(input);
  const updatePayload = payload as unknown as never;
  const { data, error } = await supabase
    .from("question_banks")
    .update(updatePayload)
    .eq("id", id)
    .select(
      "id, slug, title, subtitle, icon, mode, question_limit, rule_json, is_active, sort_order, created_at",
    )
    .single();

  if (error || !data) {
    throw new Error(error?.message ?? "Failed to update question bank.");
  }

  const updatedBank = data as unknown as QuestionBank;

  await recordAdminEvent(context, {
    action: "bank.update",
    resourceType: "question_banks",
    resourceId: id,
    metadata: { slug: payload.slug, mode: payload.mode, is_active: payload.is_active },
  });

  return updatedBank;
}

export async function deleteQuestionBank(accessToken: string, id: string) {
  const context = await requireAdmin(accessToken);
  const { supabase } = context;
  const { error } = await supabase.from("question_banks").delete().eq("id", id);
  if (error) {
    throw new Error(error.message);
  }

  await recordAdminEvent(context, {
    action: "bank.delete",
    resourceType: "question_banks",
    resourceId: id,
  });
}
