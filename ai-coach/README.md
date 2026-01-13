# ai-coach

AI Coach feature workspace.

- Specs: `ai-coach/docs/README.md`
- Coach Service (Node/TS worker): `ai-coach/coach-service/`
- Notification Sender (Node/TS worker): `ai-coach/notification-sender/`
- Planning: `ai-coach/plan.md`

This directory is the primary home for AI Coach docs and implementation.

## Testing

All test suites assume a local Supabase stack.

```bash
supabase start
supabase db reset
```

Coach service tests (includes MiniMax LLM integration tests when `MINIMAX_API_KEY` is set):

```bash
cd ai-coach/coach-service
npm test
```

Notification sender tests:

```bash
cd ai-coach/notification-sender
npm test
```

Environment variables (defaults provided for local Supabase):
- `SUPABASE_URL` (default: `http://127.0.0.1:54321`)
- `SUPABASE_SERVICE_ROLE_KEY` (default: local dev key)
- `MINIMAX_API_KEY` (required for LLM integration tests)
