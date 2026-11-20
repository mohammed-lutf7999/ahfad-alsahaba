import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.0.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function base64UrlEncode(input: Uint8Array | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const clean = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const binary = atob(clean);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

async function fetchGoogleAccessToken(sa: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlEncode(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = base64UrlEncode(
    JSON.stringify({
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }),
  );
  const signingInput = `${header}.${claim}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput),
  );
  const assertion = `${signingInput}.${base64UrlEncode(new Uint8Array(signature))}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const tokenJson = await tokenRes.json();
  if (!tokenRes.ok || !tokenJson.access_token) {
    throw new Error(`OAuth token exchange failed: ${JSON.stringify(tokenJson)}`);
  }
  return tokenJson.access_token as string;
}

/**
 * M14 Optional External FCM HTTP v1 Push Dispatcher.
 * Requires `FCM_SERVICE_ACCOUNT_JSON` secret in Supabase Edge Secrets and
 * `google-services.json` + `firebase_messaging` in the Android client build.
 */
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const jwt = authHeader.replace("Bearer ", "");
    const { data: { user }, error: userErr } = await supabase.auth.getUser(jwt);
    if (userErr || !user) {
      return new Response(JSON.stringify({ error: "Invalid JWT" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const adminEmail = (user.email ?? "").trim().toLowerCase();
    const { data: adminRow } = adminEmail
      ? await supabase
          .from("app_admins")
          .select("email")
          .eq("email", adminEmail)
          .maybeSingle()
      : { data: null };

    if (!adminRow) {
      return new Response(JSON.stringify({ error: "Admin access required" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const saRaw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
    if (!saRaw) {
      return new Response(
        JSON.stringify({
          ok: false,
          code: "FCM_NOT_CONFIGURED",
          message: "FCM_SERVICE_ACCOUNT_JSON secret is not configured in Supabase Edge Secrets yet.",
        }),
        {
          status: 503,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const serviceAccount = JSON.parse(saRaw);
    const accessToken = await fetchGoogleAccessToken(serviceAccount);

    const body = await req.json();
    const title = String(body?.title ?? "تنبيه من معركة أحفاد الصحابة").slice(0, 120);
    const message = String(body?.body ?? "").slice(0, 240);
    const route = String(body?.route ?? "/inbox");
    const playerCode = body?.player_code ? String(body.player_code).toUpperCase() : null;

    let query = supabase
      .from("player_push_tokens")
      .select("device_token")
      .eq("is_active", true)
      .limit(500);
    if (playerCode) query = query.eq("player_code", playerCode);

    const { data: targets, error: targetErr } = await query;
    if (targetErr) throw targetErr;

    let sent = 0;
    const staleTokens: string[] = [];
    for (const row of targets ?? []) {
      const fcmRes = await fetch(
        `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token: row.device_token,
              notification: { title, body: message },
              data: { route },
            },
          }),
        },
      );
      if (fcmRes.ok) {
        sent++;
      } else if (fcmRes.status === 404 || fcmRes.status === 410) {
        staleTokens.push(row.device_token);
      }
    }

    if (staleTokens.length > 0) {
      await supabase
        .from("player_push_tokens")
        .update({ is_active: false })
        .in("device_token", staleTokens);
    }

    return new Response(
      JSON.stringify({
        ok: true,
        sent,
        deactivated_stale: staleTokens.length,
        targets_total: (targets ?? []).length,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
