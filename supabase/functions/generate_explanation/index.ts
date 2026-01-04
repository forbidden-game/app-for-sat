import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

serve(async (req) => {
  const body = await req.json();
  if (!body.question_id) {
    return new Response(JSON.stringify({ error: "invalid_payload" }), { status: 400 });
  }
  const explanation = "[stub] explanation";
  return new Response(JSON.stringify({ content: explanation }), { status: 200 });
});
