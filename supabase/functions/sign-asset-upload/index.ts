import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

export const config = {
  verify_jwt: false,
};

type SignUploadBody = {
  question_id: string;
  file_name: string;
  content_type: string;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !supabaseServiceRoleKey) {
  throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.");
}

const supabase = createClient(supabaseUrl, supabaseServiceRoleKey, {
  auth: { persistSession: false },
});

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function verifyAdmin(authHeader: string | null): Promise<string | null> {
  if (!authHeader?.startsWith("Bearer ")) return null;
  const token = authHeader.slice(7);

  const { data: userData, error: userError } = await supabase.auth.getUser(token);
  if (userError || !userData.user) return null;

  const { data: profile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", userData.user.id)
    .single();

  if (profile?.role !== "admin") return null;
  return userData.user.id;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, content-type",
      },
    });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const adminId = await verifyAdmin(req.headers.get("authorization"));
  if (!adminId) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  let body: SignUploadBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const { question_id, file_name, content_type } = body;
  if (!question_id || !file_name || !content_type) {
    return jsonResponse({ error: "missing_fields" }, 400);
  }

  const allowedTypes = ["image/png", "image/jpeg", "image/gif", "image/webp", "image/svg+xml"];
  if (!allowedTypes.includes(content_type)) {
    return jsonResponse({ error: "invalid_content_type" }, 400);
  }

  const ext = file_name.split(".").pop() || "png";
  const storagePath = `questions/${question_id}/${crypto.randomUUID()}.${ext}`;

  const { data: signedData, error: signError } = await supabase.storage
    .from("question-assets")
    .createSignedUploadUrl(storagePath);

  if (signError || !signedData) {
    return jsonResponse({ error: "failed_to_sign", details: signError?.message }, 500);
  }

  const publicUrl = `${supabaseUrl}/storage/v1/object/public/question-assets/${storagePath}`;

  return jsonResponse({
    signed_url: signedData.signedUrl,
    token: signedData.token,
    storage_path: storagePath,
    public_url: publicUrl,
  });
});
