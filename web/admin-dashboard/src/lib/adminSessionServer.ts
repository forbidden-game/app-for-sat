import "server-only";

import { cookies } from "next/headers";

import { ADMIN_ACCESS_TOKEN_COOKIE } from "./adminSessionConfig";

export async function readAdminAccessToken() {
  const store = await cookies();
  const value = store.get(ADMIN_ACCESS_TOKEN_COOKIE)?.value;
  if (!value) return null;
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}
