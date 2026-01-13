#!/bin/sh
set -eu

SERVICE_NAME="ai-coach-worker.service"
ENV_FILE="/etc/app-for-sat/ai-coach.env"
WORKER_DIR="/root/apps/app-for-sat/ai-coach/coach-service"
LOG_FILE="/var/log/ai-coach-healthcheck.log"

log() {
  msg="$1"
  printf "%s %s\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$msg" | tee -a "$LOG_FILE"
}

if [ ! -f "$ENV_FILE" ]; then
  log "ERROR: missing env file $ENV_FILE"
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]; then
  log "ERROR: missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY"
  exit 1
fi

if ! systemctl is-active --quiet "$SERVICE_NAME"; then
  log "ERROR: $SERVICE_NAME is not active"
  systemctl --no-pager status "$SERVICE_NAME" || true
  exit 1
fi

if [ ! -d "$WORKER_DIR" ]; then
  log "ERROR: missing worker dir $WORKER_DIR"
  exit 1
fi

cd "$WORKER_DIR"

log "INFO: checking queue health"

node - <<'NODE'
const { createClient } = require("@supabase/supabase-js");

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  process.exit(1);
}

const client = createClient(url, key, { auth: { persistSession: false } });

async function run() {
  const now = new Date();
  const staleCutoff = new Date(now.getTime() - 15 * 60 * 1000).toISOString();

  const queued = await client
    .from("ai_jobs")
    .select("id", { count: "exact", head: true })
    .eq("status", "queued");

  const running = await client
    .from("ai_jobs")
    .select("id", { count: "exact", head: true })
    .eq("status", "running");

  const stale = await client
    .from("ai_jobs")
    .select("id", { count: "exact", head: true })
    .eq("status", "running")
    .lt("updated_at", staleCutoff);

  if (queued.error) throw queued.error;
  if (running.error) throw running.error;
  if (stale.error) throw stale.error;

  const queuedCount = queued.count ?? 0;
  const runningCount = running.count ?? 0;
  const staleCount = stale.count ?? 0;

  console.log(`queued=${queuedCount} running=${runningCount} stale_running=${staleCount}`);

  if (staleCount > 0) {
    console.error("stale running jobs detected");
    process.exitCode = 2;
  }
}

run().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
NODE

log "INFO: healthcheck completed"
