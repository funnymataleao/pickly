import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  exchangeAppleAuthorizationCode,
  readAppleConfiguration,
} from "../_shared/apple.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const accessToken = bearerToken(request.headers.get("Authorization"));
  if (!accessToken) {
    return json({ error: "Missing authorization" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const publishableKey = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const appleConfiguration = readAppleConfiguration();

  if (!supabaseUrl || !publishableKey || !serviceRoleKey) {
    return json({ error: "Account token storage is not configured" }, 500);
  }
  if (!appleConfiguration) {
    return json({ error: "Apple token exchange is not configured" }, 503);
  }

  let body: { authorization_code?: unknown };
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid request body" }, 400);
  }

  const authorizationCode = typeof body.authorization_code === "string"
    ? body.authorization_code.trim()
    : "";
  if (!authorizationCode) {
    return json({ error: "Missing authorization code" }, 400);
  }

  const userClient = createClient(supabaseUrl, publishableKey, {
    global: { headers: { Authorization: `Bearer ${accessToken}` } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return json({ error: "Invalid session" }, 401);
  }

  try {
    const { refreshToken } = await exchangeAppleAuthorizationCode(
      appleConfiguration,
      authorizationCode,
    );
    const adminClient = createClient(supabaseUrl, serviceRoleKey);
    const { error: storeError } = await adminClient
      .from("apple_provider_tokens")
      .upsert({
        user_id: userData.user.id,
        refresh_token: refreshToken,
        updated_at: new Date().toISOString(),
      }, { onConflict: "user_id" });

    if (storeError) {
      return json({ error: "Could not store the Apple provider token" }, 500);
    }
  } catch (error) {
    console.error("Apple token exchange failed", error);
    return json({ error: "Could not complete Apple account setup" }, 502);
  }

  return json({ stored: true }, 200);
});

function bearerToken(value: string | null): string | null {
  const token = value?.replace(/^Bearer\s+/i, "").trim();
  return token || null;
}

function json(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
