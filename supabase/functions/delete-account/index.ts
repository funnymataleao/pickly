import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  readAppleConfiguration,
  revokeAppleRefreshToken,
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

  const authorization = request.headers.get("Authorization");
  const accessToken = authorization?.replace(/^Bearer\s+/i, "").trim();

  if (!accessToken) {
    return json({ error: "Missing authorization" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const publishableKey = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !publishableKey || !serviceRoleKey) {
    return json({ error: "Account deletion is not configured" }, 500);
  }

  const userClient = createClient(supabaseUrl, publishableKey, {
    global: {
      headers: { Authorization: `Bearer ${accessToken}` },
    },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return json({ error: "Invalid session" }, 401);
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  const hasAppleIdentity = userData.user.identities?.some(
    (identity) => identity.provider === "apple",
  ) ?? false;

  if (hasAppleIdentity) {
    const appleConfiguration = readAppleConfiguration();
    if (!appleConfiguration) {
      return json({ error: "Apple account deletion is not configured" }, 503);
    }

    const { data: tokenRecord, error: tokenError } = await adminClient
      .from("apple_provider_tokens")
      .select("refresh_token")
      .eq("user_id", userData.user.id)
      .maybeSingle();

    if (tokenError || !tokenRecord?.refresh_token) {
      return json({ error: "Apple account deletion is not ready for this account" }, 503);
    }

    try {
      await revokeAppleRefreshToken(appleConfiguration, tokenRecord.refresh_token);
    } catch (error) {
      console.error("Apple token revocation failed", error);
      return json({ error: "Could not revoke the Apple connection" }, 502);
    }

    const { error: tokenDeleteError } = await adminClient
      .from("apple_provider_tokens")
      .delete()
      .eq("user_id", userData.user.id);
    if (tokenDeleteError) {
      return json({ error: "Could not finish Apple account deletion" }, 502);
    }
  }

  const { error: deleteError } = await adminClient.auth.admin.deleteUser(userData.user.id);
  if (deleteError) {
    return json({ error: "Could not delete the account" }, 502);
  }

  // Deleting the user is the durable operation. If session revocation fails
  // afterwards, Supabase has already invalidated the deleted user's account;
  // do not report a false deletion failure to the client.
  await adminClient.auth.admin.signOut(accessToken, "global");

  return json({ deleted: true }, 200);
});

function json(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
