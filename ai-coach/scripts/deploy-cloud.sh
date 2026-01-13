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
: "${SUPABASE_SERVICE_ROLE_KEY:?Missing SUPABASE_SERVICE_ROLE_KEY (needed for some local tooling, keep in env file)}"
: "${SUPABASE_ACCESS_TOKEN:?Missing SUPABASE_ACCESS_TOKEN (Supabase Management API token)}"
: "${SUPABASE_DB_PASSWORD:?Missing SUPABASE_DB_PASSWORD (remote Postgres password)}"

project_ref="$(node -e 'const u=new URL(process.env.NEXT_PUBLIC_SUPABASE_URL); console.log(u.hostname.split(".")[0])')"

echo "Deploying to Supabase project: ${project_ref}"

echo "1) Login"
supabase login --token "$SUPABASE_ACCESS_TOKEN" --name "ai-coach-cloud" >/dev/null

echo "2) Link project"
supabase link --project-ref "$project_ref" --password "$SUPABASE_DB_PASSWORD" --yes >/dev/null

echo "3) Push DB migrations"
supabase db push --password "$SUPABASE_DB_PASSWORD" --include-all --yes

echo "4) Deploy Edge Functions (server-side bundle, no Docker)"
supabase functions deploy submit_attempt --project-ref "$project_ref" --use-api
supabase functions deploy set_attempt_step --project-ref "$project_ref" --use-api
supabase functions deploy coach_chat --project-ref "$project_ref" --use-api

echo "Done."
