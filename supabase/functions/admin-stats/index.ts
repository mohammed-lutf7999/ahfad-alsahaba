import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

import {
  errorMessage,
  handleCorsPreflight,
  jsonResponse,
  requireVerifiedAdmin,
} from "../_shared/cors_and_auth.ts";

serve(async (req: Request) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  try {
    const auth = await requireVerifiedAdmin(req);
    if (!auth.ok) return auth.response;

    const { supabase } = auth;

    // Total registered leaderboard users
    const { count: totalUsers, error: dbError } = await supabase
      .from("leaderboard")
      .select("*", { count: "exact", head: true });
    if (dbError) throw dbError;

    // Active users updated in last 15 minutes
    const fifteenMinutesAgo = new Date(Date.now() - 15 * 60 * 1000).toISOString();
    const { count: onlineUsers, error: onlineError } = await supabase
      .from("leaderboard")
      .select("*", { count: "exact", head: true })
      .gt("updated_at", fifteenMinutesAgo);
    if (onlineError) throw onlineError;

    return jsonResponse({
      totalUsers: totalUsers ?? 0,
      onlineUsers: onlineUsers ?? 0,
    });
  } catch (error: unknown) {
    return jsonResponse({ error: errorMessage(error) }, 400);
  }
});
