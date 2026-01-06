import { describe, it, expect, beforeAll } from "vitest";
import { createClientAs, skipIfNoSupabase, TestClient } from "@test/helpers";

describe("Profiles RLS", () => {
  beforeAll(() => {
    if (skipIfNoSupabase()) return;
  });

  describe("student role", () => {
    let studentClient: TestClient;

    beforeAll(async () => {
      if (skipIfNoSupabase()) return;
      studentClient = await createClientAs("student");
    });

    it("can read own profile", async () => {
      if (skipIfNoSupabase()) return;

      const { data, error } = await studentClient
        .from("profiles")
        .select("*")
        .eq("id", studentClient.userId)
        .single();

      expect(error).toBeNull();
      expect(data?.id).toBe(studentClient.userId);
    });

    it("cannot read other profiles", async () => {
      if (skipIfNoSupabase()) return;

      const { data, error } = await studentClient
        .from("profiles")
        .select("*")
        .neq("id", studentClient.userId);

      expect(error).toBeNull();
      expect(data).toEqual([]);
    });

    it("can update own profile display_name", async () => {
      if (skipIfNoSupabase()) return;

      const newName = `Updated ${Date.now()}`;
      const { error } = await studentClient
        .from("profiles")
        .update({ display_name: newName })
        .eq("id", studentClient.userId);

      expect(error).toBeNull();
    });

    it.todo("should prevent role change - SECURITY: current RLS allows role escalation");
  });

  describe("admin role", () => {
    let adminClient: TestClient;

    beforeAll(async () => {
      if (skipIfNoSupabase()) return;
      adminClient = await createClientAs("admin");
    });

    it("can read all profiles", async () => {
      if (skipIfNoSupabase()) return;

      const { data, error } = await adminClient.from("profiles").select("*");

      expect(error).toBeNull();
      expect(data?.length).toBeGreaterThan(0);
    });

    it("can update any profile", async () => {
      if (skipIfNoSupabase()) return;

      const { data: profiles } = await adminClient
        .from("profiles")
        .select("id")
        .eq("role", "student")
        .limit(1);

      if (profiles && profiles.length > 0) {
        const { error } = await adminClient
          .from("profiles")
          .update({ display_name: `Admin updated ${Date.now()}` })
          .eq("id", profiles[0].id);

        expect(error).toBeNull();
      }
    });
  });
});
