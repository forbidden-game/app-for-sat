# Parent Dashboard (SAT)
日期：2026-01-14

Purpose: parent-facing view of the AI teacher's long-term tracking (trends, strengths, risks).

## Run (local)
```bash
cd web/parent-dashboard
npm install
npm run dev
```

## Env
Create `web/parent-dashboard/.env.local`:
```
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
```

## Tests
```bash
npm run lint
npm run test
```
