import { SUPABASE_ANON_KEY, SUPABASE_UNAVAILABLE_MSG, SUPABASE_URL } from './config.js';
import { setAuthWarning, showToast } from './ui_utils.js';

let clientInstance = null;

export const adminState = {
  user: null,
  isAdmin: false,
  livePingEnabled: true,
  lastOverview: null,
};

export function getSupabase() {
  if (clientInstance) return clientInstance;
  const supabaseLib = window.supabase;
  if (!supabaseLib?.createClient) return null;
  clientInstance = supabaseLib.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
    },
  });
  return clientInstance;
}

export function requireSupabase() {
  const client = getSupabase();
  if (client) return client;
  setAuthWarning(SUPABASE_UNAVAILABLE_MSG);
  showToast(SUPABASE_UNAVAILABLE_MSG, true);
  return null;
}
