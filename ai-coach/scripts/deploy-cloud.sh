#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-web/admin-dashboard/.env.local}"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

: "${NEXT_PUBLIC_SUPABASE_URL:?Missing NEXT_PUBLIC_SUPABASE_URL (set ENV_FILE=... or export it)}"

project_ref="$(node -e 'const u=new URL(process.env.NEXT_PUBLIC_SUPABASE_URL); console.log(u.hostname.split(".")[0])')"

echo "Deploying to Supabase project: ${project_ref}"

echo "1) Ensure CLI is authenticated"
if ! supabase projects list >/dev/null 2>&1; then
  echo "Supabase CLI is not logged in. Run: supabase login"
  exit 1
fi

echo "2) Link project (idempotent)"
supabase link --project-ref "$project_ref" --yes >/dev/null

echo "3) Push DB migrations"
# Some supabase-cli versions may still prompt even with --yes.
yes y | supabase db push --include-all --yes

echo "4) Deploy Edge Functions (server-side bundle, no Docker)"
# NOTE: This project currently returns "Invalid JWT" when platform-level JWT verification is enabled,
# so we disable gateway verification and do JWT verification inside each function.
supabase functions deploy submit_attempt --project-ref "$project_ref" --use-api --no-verify-jwt
supabase functions deploy set_attempt_step --project-ref "$project_ref" --use-api --no-verify-jwt
supabase functions deploy coach_chat --project-ref "$project_ref" --use-api --no-verify-jwt

echo "Done."
