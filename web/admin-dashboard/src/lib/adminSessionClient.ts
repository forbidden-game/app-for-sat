"use client";

import { ADMIN_ACCESS_TOKEN_COOKIE, ADMIN_ACCESS_TOKEN_MAX_AGE } from "./adminSessionConfig";

function buildCookie(value: string) {
  const encoded = encodeURIComponent(value);
  const isSecure = typeof window !== "undefined" && window.location.protocol === "https:";
  return (
    `${ADMIN_ACCESS_TOKEN_COOKIE}=${encoded}; path=/; samesite=lax; max-age=${ADMIN_ACCESS_TOKEN_MAX_AGE}` +
    (isSecure ? "; secure" : "")
  );
}

export function writeAdminAccessToken(token: string) {
  if (!token) return;
  document.cookie = buildCookie(token);
}

export function clearAdminAccessToken() {
  const isSecure = typeof window !== "undefined" && window.location.protocol === "https:";
  document.cookie =
    `${ADMIN_ACCESS_TOKEN_COOKIE}=; path=/; samesite=lax; max-age=0` + (isSecure ? "; secure" : "");
}
