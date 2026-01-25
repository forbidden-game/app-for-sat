"use server";

import "server-only";
import { requireAdmin } from "@/lib/adminAuth";

export type StudyBehavior = {
  student_id: string;
  window_days: number;
  state: {
    label: string;
    confidence: number | null;
  };
  drivers: string[];
  metrics: {
    minutes: number;
    minutes_delta: number;
    accuracy: number | null;
    accuracy_delta: number | null;
    active_days: number;
    active_days_delta: number;
    attempts: number;
  };
  daily: Array<{
    date: string;
    minutes: number;
    attempts: number;
    accuracy: number | null;
  }>;
  weekly: Array<{
    week_start: string;
    minutes: number;
    attempts: number;
    accuracy: number | null;
    active_days: number;
  }>;
};

export type StudyBehaviorItem = {
  student: {
    id: string;
    display_name: string | null;
  };
  behavior: StudyBehavior | null;
  error?: string | null;
};

export type StudyBehaviorList = {
  generated_at: string;
  window_days: number;
  items: StudyBehaviorItem[];
};

export async function getStudyBehaviorList(
  accessToken: string,
  options?: { limit?: number; windowDays?: number },
): Promise<StudyBehaviorList> {
  const { supabase } = await requireAdmin(accessToken);
  const limit = options?.limit ?? 30;
  const windowDays = options?.windowDays ?? 7;

  const { data: students, error: studentError } = await supabase
    .from("profiles")
    .select("id, display_name")
    .eq("role", "student")
    .order("created_at", { ascending: false })
    .limit(limit);

  if (studentError) {
    throw new Error("Failed to load students.");
  }

  const items = await Promise.all(
    (students ?? []).map(async (student) => {
      const { data, error } = await supabase.rpc("get_study_behavior", {
        target_student_id: student.id,
        window_days: windowDays,
        history_weeks: 8,
      });

      if (error) {
        return {
          student,
          behavior: null,
          error: error.message,
        };
      }

      return {
        student,
        behavior: data as StudyBehavior,
        error: null,
      };
    }),
  );

  return {
    generated_at: new Date().toISOString(),
    window_days: windowDays,
    items,
  };
}
