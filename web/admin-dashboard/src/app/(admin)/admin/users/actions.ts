"use server";

import "server-only";
import { requireAdmin } from "@/lib/adminAuth";
import { recordAdminEvent } from "@/lib/adminAudit";

const USER_ROLES = ["student", "parent", "admin"] as const;

export type UserRole = (typeof USER_ROLES)[number];

export type UserListItem = {
  id: string;
  email: string | null;
  display_name: string | null;
  role: UserRole | null;
  created_at: string;
  last_sign_in_at: string | null;
};

export type UserInput = {
  email: string;
  display_name: string;
  role: UserRole;
};

export type ListUsersParams = {
  page?: number;
  pageSize?: number;
};

export type ListUsersResult = {
  users: UserListItem[];
  page: number;
  pageSize: number;
  hasNext: boolean;
};

type AuthUser = {
  id: string;
  email: string | null;
  created_at: string;
  last_sign_in_at: string | null;
};

type ProfileRow = {
  id: string;
  role: UserRole;
  display_name: string | null;
  created_at: string;
};


function assertRole(role: string): UserRole {
  if (!USER_ROLES.includes(role as UserRole)) {
    throw new Error("Role must be student, parent, or admin.");
  }
  return role as UserRole;
}

function normalizeInput(input: UserInput) {
  const email = input.email.trim().toLowerCase();
  const displayName = input.display_name.trim();
  const role = assertRole(input.role);

  if (!email || !email.includes("@")) {
    throw new Error("A valid email is required.");
  }

  return {
    email,
    display_name: displayName ? displayName : null,
    role,
  };
}

function buildUserListItem(authUser: AuthUser, profile?: ProfileRow | null): UserListItem {
  return {
    id: authUser.id,
    email: authUser.email,
    display_name: profile?.display_name ?? null,
    role: profile?.role ?? null,
    created_at: profile?.created_at ?? authUser.created_at,
    last_sign_in_at: authUser.last_sign_in_at ?? null,
  };
}


export async function listUsers(
  accessToken: string,
  params: ListUsersParams = {},
): Promise<ListUsersResult> {
  const { supabase } = await requireAdmin(accessToken);
  const page = params.page ?? 1;
  const pageSize = params.pageSize ?? 20;

  const { data, error } = await supabase.auth.admin.listUsers({
    page,
    perPage: pageSize,
  });

  if (error) {
    throw new Error("Failed to load users.");
  }

  const users = (data.users ?? []) as AuthUser[];
  const userIds = users.map((user) => user.id);

  let profiles: ProfileRow[] = [];
  if (userIds.length > 0) {
    const { data: profileData, error: profileError } = await supabase
      .from("profiles")
      .select("id, role, display_name, created_at")
      .in("id", userIds);

    if (profileError) {
      throw new Error("Failed to load user profiles.");
    }

    profiles = (profileData ?? []) as ProfileRow[];
  }

  const profileMap = new Map(profiles.map((profile) => [profile.id, profile]));

  return {
    users: users.map((user) => buildUserListItem(user, profileMap.get(user.id))),
    page,
    pageSize,
    hasNext: users.length === pageSize,
  };
}

export async function createUser(
  accessToken: string,
  input: UserInput,
): Promise<UserListItem> {
  const context = await requireAdmin(accessToken);
  const { supabase } = context;
  const { email, display_name, role } = normalizeInput(input);

  const { data, error } = await supabase.auth.admin.inviteUserByEmail(email);
  if (error || !data.user) {
    throw new Error("Failed to create user.");
  }

  const createdUser = data.user as AuthUser;

  const { error: profileError } = await supabase
    .from("profiles")
    .update({ role, display_name })
    .eq("id", createdUser.id);

  if (profileError) {
    throw new Error("Failed to update user profile.");
  }

  const { data: profileData, error: fetchError } = await supabase
    .from("profiles")
    .select("id, role, display_name, created_at")
    .eq("id", createdUser.id)
    .single();

  if (fetchError || !profileData) {
    throw new Error("Failed to load created user profile.");
  }

  await recordAdminEvent(context, {
    action: "user.create",
    resourceType: "users",
    resourceId: createdUser.id,
    metadata: {
      email,
      role,
      display_name,
      invite: true,
    },
  });

  return buildUserListItem(createdUser, profileData as ProfileRow);
}

export async function updateUser(
  accessToken: string,
  userId: string,
  input: UserInput,
): Promise<UserListItem> {
  const context = await requireAdmin(accessToken);
  const { supabase, admin } = context;
  const { email, display_name, role } = normalizeInput(input);

  if (admin.id === userId && role !== "admin") {
    throw new Error("You cannot remove your own admin role.");
  }

  const { data: authData, error: authError } = await supabase.auth.admin.getUserById(
    userId,
  );

  if (authError || !authData.user) {
    throw new Error("User not found.");
  }

  const { data: profileRows, error: profileError } = await supabase
    .from("profiles")
    .select("id, role, display_name, created_at")
    .eq("id", userId)
    .limit(1);

  if (profileError || !profileRows || profileRows.length === 0) {
    throw new Error("User profile not found.");
  }

  const existingProfile = profileRows[0] as ProfileRow;
  const existingAuthUser = authData.user as AuthUser;

  const before = {
    email: existingAuthUser.email ?? null,
    role: existingProfile.role,
    display_name: existingProfile.display_name ?? null,
  };

  let updatedAuthUser = existingAuthUser;
  if (email !== before.email) {
    const { data: updatedAuth, error: updateAuthError } =
      await supabase.auth.admin.updateUserById(userId, { email });

    if (updateAuthError || !updatedAuth.user) {
      throw new Error("Failed to update user email.");
    }
    updatedAuthUser = updatedAuth.user as AuthUser;
  }

  const { error: updateProfileError } = await supabase
    .from("profiles")
    .update({ role, display_name })
    .eq("id", userId);

  if (updateProfileError) {
    throw new Error("Failed to update user profile.");
  }

  const { data: updatedProfileRows, error: updatedProfileError } = await supabase
    .from("profiles")
    .select("id, role, display_name, created_at")
    .eq("id", userId)
    .limit(1);

  if (updatedProfileError || !updatedProfileRows || updatedProfileRows.length === 0) {
    throw new Error("Failed to load updated user profile.");
  }

  const updatedProfile = updatedProfileRows[0] as ProfileRow;

  await recordAdminEvent(context, {
    action: "user.update",
    resourceType: "users",
    resourceId: userId,
    metadata: {
      before,
      after: {
        email,
        role,
        display_name,
      },
    },
  });

  return buildUserListItem(updatedAuthUser, updatedProfile);
}

export async function deleteUser(accessToken: string, userId: string): Promise<void> {
  const context = await requireAdmin(accessToken);
  const { supabase, admin } = context;

  if (admin.id === userId) {
    throw new Error("You cannot delete your own account.");
  }

  const { data: authData, error: authError } = await supabase.auth.admin.getUserById(
    userId,
  );

  if (authError || !authData.user) {
    throw new Error("User not found.");
  }

  const { data: profileRows } = await supabase
    .from("profiles")
    .select("id, role, display_name, created_at")
    .eq("id", userId)
    .limit(1);

  const profile = (profileRows && profileRows.length > 0 ? profileRows[0] : null) as
    | ProfileRow
    | null;

  const before = {
    email: (authData.user as AuthUser).email ?? null,
    role: profile?.role ?? null,
    display_name: profile?.display_name ?? null,
  };

  const { error: deleteError } = await supabase.auth.admin.deleteUser(userId);
  if (deleteError) {
    throw new Error("Failed to delete user.");
  }

  await recordAdminEvent(context, {
    action: "user.delete",
    resourceType: "users",
    resourceId: userId,
    metadata: { before },
  });
}
