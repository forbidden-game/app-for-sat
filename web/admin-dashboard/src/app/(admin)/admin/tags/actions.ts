"use server";

import "server-only";
import { requireAdmin } from "@/lib/adminAuth";

export type Tag = {
  id: string;
  name: string;
  category: string;
};

export type TagInput = {
  name: string;
  category: string;
};

const VALID_CATEGORIES = ["topic", "skill", "difficulty", "source", "general"] as const;

function validateTagInput(input: TagInput) {
  const name = input.name.trim();
  const category = input.category.trim() || "general";

  if (!name) {
    throw new Error("Tag name is required.");
  }
  if (name.length > 100) {
    throw new Error("Tag name must be 100 characters or less.");
  }

  return { name, category };
}

export async function listTags(accessToken: string) {
  const { supabase } = await requireAdmin(accessToken);
  const { data, error } = await supabase
    .from("tags")
    .select("id, name, category")
    .order("category", { ascending: true })
    .order("name", { ascending: true });

  if (error) {
    throw new Error("Failed to load tags.");
  }
  return (data ?? []) as Tag[];
}

export async function createTag(accessToken: string, input: TagInput) {
  const { supabase } = await requireAdmin(accessToken);
  const payload = validateTagInput(input);
  
  const { data, error } = await supabase
    .from("tags")
    .insert(payload)
    .select("id, name, category")
    .single();

  if (error) {
    if (error.code === "23505") {
      throw new Error("A tag with this name already exists.");
    }
    throw new Error(error.message);
  }
  return data as Tag;
}

export async function updateTag(accessToken: string, id: string, input: TagInput) {
  const { supabase } = await requireAdmin(accessToken);
  const payload = validateTagInput(input);
  
  const { data, error } = await supabase
    .from("tags")
    .update(payload)
    .eq("id", id)
    .select("id, name, category")
    .single();

  if (error) {
    if (error.code === "23505") {
      throw new Error("A tag with this name already exists.");
    }
    throw new Error(error.message);
  }
  return data as Tag;
}

export async function deleteTag(accessToken: string, id: string) {
  const { supabase } = await requireAdmin(accessToken);
  const { error } = await supabase.from("tags").delete().eq("id", id);
  
  if (error) {
    throw new Error(error.message);
  }
}

export async function getTagCategories() {
  return VALID_CATEGORIES;
}
