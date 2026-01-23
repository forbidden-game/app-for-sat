# Admin Dashboard (SAT)

日期：2026-01-14

Purpose: internal console to manage question bank and operations that power the per-student AI teacher.

## Run (local)

```bash
cd web/admin-dashboard
npm install
npm run dev
```

## Env

Create `web/admin-dashboard/.env.local`:

```
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
```

## Tests

```bash
npm run lint
npm run test
```
