import { adminState, getSupabase } from './supabase_client.js';

export async function broadcastWebControlPing(targetCode = 'ALL', targetUserId = null) {
  try {
    const supabase = getSupabase();
    const flagEl = document.getElementById('flag-live-ping');
    const livePingOn = flagEl ? flagEl.checked : adminState.livePingEnabled;
    if (!supabase || !livePingOn) return;
    const ch = supabase.channel('app_control_live');
    await ch.send({
      type: 'broadcast',
      event: 'control_ping',
      payload: {
        target_code: String(targetCode || 'ALL').toUpperCase(),
        ...(targetUserId ? { target_user_id: targetUserId } : {}),
        ts: Date.now(),
      },
    });
    await supabase.removeChannel(ch);
  } catch (err) {
    console.warn('Ping broadcast skipped:', err?.message || err);
  }
}

export async function broadcastLiveArenaFinish(sessionId, leaderboard = []) {
  try {
    const supabase = getSupabase();
    if (!supabase || !sessionId) return;
    const ch = supabase.channel(`live_arena_${sessionId}`);
    await ch.send({
      type: 'broadcast',
      event: 'arena_event',
      payload: {
        type: 'finish',
        question_index: 999,
        leaderboard: Array.isArray(leaderboard) ? leaderboard : [],
        ts: Date.now(),
      },
    });
    await supabase.removeChannel(ch);
  } catch (err) {
    console.warn('Live arena finish broadcast skipped:', err?.message || err);
  }
}
