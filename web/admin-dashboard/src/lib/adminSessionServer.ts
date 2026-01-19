import "server-only";

import { cookies } from "next/headers";

import { ADMIN_ACCESS_TOKEN_COOKIE } from "./adminSessionConfig";

export function readAdminAccessToken() {
  const value = cookies().get(ADMIN_ACCESS_TOKEN_COOKIE)?.value;
  if (!value) return null;
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}
