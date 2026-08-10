import { importPKCS8, SignJWT } from "npm:jose@5.10.0";

const appleIssuer = "https://appleid.apple.com";

export type AppleConfiguration = {
  clientId: string;
  clientSecret?: string;
  teamId?: string;
  keyId?: string;
  privateKey?: string;
};

export function readAppleConfiguration(): AppleConfiguration | null {
  const clientId = Deno.env.get("APPLE_CLIENT_ID")?.trim();
  if (!clientId) {
    return null;
  }

  const clientSecret = Deno.env.get("APPLE_CLIENT_SECRET")?.trim();
  const teamId = Deno.env.get("APPLE_TEAM_ID")?.trim();
  const keyId = Deno.env.get("APPLE_KEY_ID")?.trim();
  const privateKey = Deno.env.get("APPLE_PRIVATE_KEY")?.replace(/\\n/g, "\n").trim();

  if (clientSecret) {
    return { clientId, clientSecret };
  }

  if (teamId && keyId && privateKey) {
    return { clientId, teamId, keyId, privateKey };
  }

  return null;
}

export async function makeAppleClientSecret(config: AppleConfiguration): Promise<string> {
  if (config.clientSecret) {
    return config.clientSecret;
  }

  if (!config.teamId || !config.keyId || !config.privateKey) {
    throw new Error("Apple client secret is not configured");
  }

  const key = await importPKCS8(config.privateKey, "ES256");
  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: config.keyId, typ: "JWT" })
    .setIssuer(config.teamId)
    .setAudience(appleIssuer)
    .setSubject(config.clientId)
    .setIssuedAt()
    .setExpirationTime("180d")
    .sign(key);
}

export async function exchangeAppleAuthorizationCode(
  config: AppleConfiguration,
  authorizationCode: string,
): Promise<{ refreshToken: string }> {
  const clientSecret = await makeAppleClientSecret(config);
  const body = new URLSearchParams({
    client_id: config.clientId,
    client_secret: clientSecret,
    code: authorizationCode,
    grant_type: "authorization_code",
  });

  const response = await fetch(`${appleIssuer}/auth/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  const payload = await response.json().catch(() => ({}));

  if (!response.ok || typeof payload.refresh_token !== "string") {
    throw new Error(
      typeof payload.error_description === "string"
        ? payload.error_description
        : "Apple authorization code exchange failed",
    );
  }

  return { refreshToken: payload.refresh_token };
}

export async function revokeAppleRefreshToken(
  config: AppleConfiguration,
  refreshToken: string,
): Promise<void> {
  const clientSecret = await makeAppleClientSecret(config);
  const body = new URLSearchParams({
    client_id: config.clientId,
    client_secret: clientSecret,
    token: refreshToken,
    token_type_hint: "refresh_token",
  });

  const response = await fetch(`${appleIssuer}/auth/revoke`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });

  if (!response.ok) {
    const payload = await response.json().catch(() => ({}));
    const description = typeof payload.error_description === "string"
      ? payload.error_description
      : "Apple token revocation failed";
    throw new Error(description);
  }
}
