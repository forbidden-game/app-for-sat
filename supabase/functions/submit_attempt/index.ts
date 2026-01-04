import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { scoreAttempt } from "../_shared/scoring.ts";

serve(async (req) => {
  const body = await req.json();
  if (!body.question || !body.attempt) {
    return new Response(JSON.stringify({ error: "invalid_payload" }), { status: 400 });
  }
  const result = scoreAttempt(body.question, body.attempt);
  return new Response(JSON.stringify({ ...result }), { status: 200 });
});
