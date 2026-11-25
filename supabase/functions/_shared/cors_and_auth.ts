import { createClient, type SupabaseClient, type User } from "https://esm.sh/@supabase/supabase-js@2.0.0";

export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

export function handleCorsPreflight(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  return null;
}

export function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}

export function createServiceRoleClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );
}

export type VerifiedAdminResult =
  | {
    ok: true;
    supabase: SupabaseClient;
    user: User;
    adminEmail: string;
    role: string;
  }
  | {
    ok: false;
    response: Response;
  };

/**
 * Verifies the Bearer JWT and confirms the caller is registered in `public.app_admins`.
 */
export async function requireVerifiedAdmin(req: Request): Promise<VerifiedAdminResult> {
  const supabase = createServiceRoleClient();

  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return {
      ok: false,
      response: jsonResponse({ error: "Missing Authorization header" }, 401),
    };
  }

  const jwt = authHeader.slice("Bearer ".length).trim();
  if (!jwt) {
    return {
      ok: false,
      response: jsonResponse({ error: "Empty Bearer token" }, 401),
    };
  }

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser(jwt);

  if (userError || !user) {
    return {
      ok: false,
      response: jsonResponse({ error: "Invalid user token" }, 401),
    };
  }

  const adminEmail = (user.email ?? "").trim().toLowerCase();
  if (!adminEmail) {
    return {
      ok: false,
      response: jsonResponse({ error: "Unauthorized: Admin access required" }, 403),
    };
  }

  const { data: adminRow, error: adminErr } = await supabase
    .from("app_admins")
    .select("email, role")
    .eq("email", adminEmail)
    .maybeSingle();

  if (adminErr || !adminRow) {
    return {
      ok: false,
      response: jsonResponse({ error: "Unauthorized: Admin access required" }, 403),
    };
  }

  return {
    ok: true,
    supabase,
    user,
    adminEmail,
    role: String(adminRow.role ?? "admin"),
  };
}

export function escapeHtml(raw: string): string {
  return raw
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

export function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
