"use server";

import "server-only";
import { requireAdmin } from "@/lib/adminAuth";

export type BankQuestion = {
  question_id: string;
  position: number;
  stem: string;
  subject: string;
  difficulty: number;
  question_type: string;
};

export type AvailableQuestion = {
  id: string;
  stem: string;
  subject: string;
  module: string;
  difficulty: number;
  question_type: string;
};

export async function listBankQuestions(
  accessToken: string,
  bankId: string,
): Promise<BankQuestion[]> {
  const { supabase } = await requireAdmin(accessToken);

  const { data, error } = await supabase
    .from("question_bank_questions")
    .select(
      `
      question_id,
      position,
      questions(stem, subject, difficulty, question_type)
    `,
    )
    .eq("bank_id", bankId)
    .order("position", { ascending: true });

  if (error) {
    throw new Error("Failed to load bank questions.");
  }

  return (data ?? []).map((row: Record<string, unknown>) => {
    const q = row.questions as { stem: string; subject: string; difficulty: number; question_type: string } | null;
    return {
      question_id: row.question_id as string,
      position: row.position as number,
      stem: q?.stem ?? "",
      subject: q?.subject ?? "",
      difficulty: q?.difficulty ?? 0,
      question_type: q?.question_type ?? "",
    };
  });
}

export type SearchFilters = {
  search?: string;
  subject?: string;
};

export async function searchAvailableQuestions(
  accessToken: string,
  bankId: string,
  filters: SearchFilters,
): Promise<AvailableQuestion[]> {
  const { supabase } = await requireAdmin(accessToken);

  const { data: existingIds } = await supabase
    .from("question_bank_questions")
    .select("question_id")
    .eq("bank_id", bankId);

  const excludeIds = (existingIds ?? []).map((r: { question_id: string }) => r.question_id);

  let query = supabase
    .from("questions")
    .select("id, stem, subject, module, difficulty, question_type")
    .order("created_at", { ascending: false })
    .limit(30);

  if (filters.search) {
    query = query.ilike("stem", `%${filters.search}%`);
  }

  if (filters.subject) {
    query = query.eq("subject", filters.subject);
  }

  if (excludeIds.length > 0) {
    query = query.not("id", "in", `(${excludeIds.join(",")})`);
  }

  const { data, error } = await query;

  if (error) {
    throw new Error("Failed to search questions.");
  }

  return data as AvailableQuestion[];
}

export async function getAvailableSubjects(
  accessToken: string,
): Promise<string[]> {
  const { supabase } = await requireAdmin(accessToken);

  const { data, error } = await supabase
    .from("questions")
    .select("subject")
    .order("subject");

  if (error) {
    throw new Error("Failed to load subjects.");
  }

  const uniqueSubjects = [...new Set((data ?? []).map((r: { subject: string }) => r.subject))];
  return uniqueSubjects.filter(Boolean);
}

export async function addQuestionToBank(
  accessToken: string,
  bankId: string,
  questionId: string,
): Promise<void> {
  const { supabase } = await requireAdmin(accessToken);

  const { data: maxPos } = await supabase
    .from("question_bank_questions")
    .select("position")
    .eq("bank_id", bankId)
    .order("position", { ascending: false })
    .limit(1)
    .single();

  const nextPosition = (maxPos?.position ?? 0) + 1;

  const { error } = await supabase.from("question_bank_questions").insert({
    bank_id: bankId,
    question_id: questionId,
    position: nextPosition,
  });

  if (error) {
    if (error.code === "23505") {
      throw new Error("Question already in this bank.");
    }
    throw new Error(error.message);
  }
}

export async function removeQuestionFromBank(
  accessToken: string,
  bankId: string,
  questionId: string,
): Promise<void> {
  const { supabase } = await requireAdmin(accessToken);

  const { error } = await supabase
    .from("question_bank_questions")
    .delete()
    .eq("bank_id", bankId)
    .eq("question_id", questionId);

  if (error) {
    throw new Error(error.message);
  }
}

export async function reorderBankQuestions(
  accessToken: string,
  bankId: string,
  items: Array<{ question_id: string; position: number }>,
): Promise<void> {
  const { supabase } = await requireAdmin(accessToken);

  const { error } = await supabase.rpc("reorder_bank_questions", {
    p_bank_id: bankId,
    p_items: items,
  });

  if (error) {
    throw new Error(error.message);
  }
}

export async function getBankInfo(
  accessToken: string,
  bankId: string,
): Promise<{ title: string; slug: string }> {
  const { supabase } = await requireAdmin(accessToken);

  const { data, error } = await supabase
    .from("question_banks")
    .select("title, slug")
    .eq("id", bankId)
    .single();

  if (error) {
    throw new Error("Bank not found.");
  }

  return data;
}
