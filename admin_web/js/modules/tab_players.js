import {
  refreshAudit,
  refreshOverview,
  selectPlayerForAnnouncement,
} from '../core/app_bus.js';
import { broadcastWebControlPing } from '../core/rest_broadcast.js';
import { getSupabase } from '../core/supabase_client.js';
import { safeCsvCell, showToast } from '../core/ui_utils.js';
import {
  buildPlayersTemplate,
  renderInspectorListHtml,
  renderPlayerDossierHtml,
} from './tab_players_view.js';

const CSV_HEADERS = [
  'display_name', 'player_code', 'email', 'is_guest', 'player_level',
  'trophies', 'total_score', 'app_version', 'platform', 'last_seen_at',
];

const state = { mounted: false, rows: [], currentDetail: null };

function hydratePermissionsCard(d, hasUid) {
  const permUid = document.getElementById('perm-user-id');
  const permBtn = document.getElementById('btn-save-player-perms');
  const muteBox = document.getElementById('player-diwan-mute-box');
  if (!hasUid) {
    permUid.value = '';
    permBtn.disabled = true;
    muteBox.classList.add('hidden');
    return;
  }

  const perms = d?.permissions || {};
  const diwanMod = d?.diwan_moderation;
  permUid.value = d.user_id;
  permBtn.disabled = false;
  document.getElementById('perm-is-banned').checked = Boolean(perms.is_banned);
  document.getElementById('perm-ban-reason').value = perms.ban_reason || '';
  document.getElementById('perm-can-online').checked = perms.can_use_online !== false;
  document.getElementById('perm-can-diwan').checked = perms.can_use_diwan !== false;
  document.getElementById('perm-can-guilds').checked = perms.can_use_guilds !== false;
  document.getElementById('perm-notes').value = perms.notes || '';

  const durSel = document.getElementById('perm-ban-duration');
  if (perms.banned_until) {
    const diffHours = (new Date(perms.banned_until).getTime() - Date.now()) / (1000 * 3600);
    if (diffHours <= 24) durSel.value = '24';
    else if (diffHours <= 168) durSel.value = '168';
    else if (diffHours <= 720) durSel.value = '720';
    else durSel.value = 'permanent';
  } else {
    durSel.value = perms.is_banned ? 'permanent' : '24';
  }

  const hostSel = document.getElementById('perm-host-arena');
  if (perms.can_host_live_arenas === true) hostSel.value = 'allowed';
  else if (perms.can_host_live_arenas === false) hostSel.value = 'denied';
  else hostSel.value = 'inherit';

  muteBox.classList.toggle('hidden', !Boolean(perms.is_diwan_muted || diwanMod));
}

function renderDossier(d, fallbackName) {
  const dir = d?.directory || {};
  const prog = d?.progress || {};
  const lb = d?.leaderboard || {};
  const name = dir.display_name || lb.display_name || fallbackName;
  const hasUid = Boolean(d?.user_id);

  document.getElementById('btn-target-player-msg').classList.toggle('hidden', !hasUid && !d?.player_code);
  const compUid = document.getElementById('comp-user-id');
  const compLbl = document.getElementById('comp-target-label');
  const compBtn = document.getElementById('btn-grant-compensation');
  if (hasUid) {
    compUid.value = d.user_id;
    compLbl.textContent = `🎯 المستهدف للتعويض: ${name} (${d.user_id.slice(0, 8)}…)`;
    compLbl.classList.remove('hidden');
    compBtn.disabled = !prog || Object.keys(prog).length === 0;
  } else {
    compUid.value = '';
    compLbl.textContent = '⚠️ حساب ضيف غير مربوط بحساب سحابي (التعويض يتطلب user_progress مسجّلاً)';
    compLbl.classList.remove('hidden');
    compBtn.disabled = true;
  }

  document.getElementById('player-dossier-card').innerHTML = renderPlayerDossierHtml(d, name);
  hydratePermissionsCard(d, hasUid);
}

async function loadPlayerDetail(userId, playerCode, fallbackName = 'لاعب') {
  const client = getSupabase();
  if (!client) return;
  const { data, error } = await client.rpc('admin_get_player_detail', {
    p_user_id: userId || null,
    p_player_code: playerCode || null,
  });
  if (error) {
    showToast(`تعذر فتح ملف اللاعب: ${error.message}`, true);
    return;
  }
  state.currentDetail = data;
  renderDossier(data, fallbackName);
}

function renderList() {
  const listEl = document.getElementById('inspector-results-list');
  listEl.innerHTML = renderInspectorListHtml(state.rows);
  listEl.querySelectorAll('button[data-open-dossier]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const row = state.rows[Number(btn.dataset.openDossier)];
      if (row) loadPlayerDetail(row.user_id || null, row.player_code || null, row.display_name);
    });
  });
}

async function searchPlayers() {
  const client = getSupabase();
  if (!client) return;
  const q = document.getElementById('player-inspector-query').value.trim();
  const { data, error } = await client.rpc('admin_search_users', { p_query: q, p_limit: 50 });
  if (error) {
    showToast(`تعذر جلب اللاعبين: ${error.message}`, true);
    return;
  }
  state.rows = Array.isArray(data) ? data : [];
  renderList();
}

async function handleGrantCompensation(e) {
  e.preventDefault();
  const client = getSupabase();
  if (!client) return;
  const uid = document.getElementById('comp-user-id').value.trim();
  const coins = Number.parseInt(document.getElementById('comp-coins').value || '0', 10) || 0;
  const gems = Number.parseInt(document.getElementById('comp-gems').value || '0', 10) || 0;
  const xp = Number.parseInt(document.getElementById('comp-xp').value || '0', 10) || 0;
  const reason = document.getElementById('comp-reason').value.trim();

  if (!uid) return showToast('اختر لاعباً مسجّلاً أولاً.', true);
  if (coins < 0 || coins > 10000 || gems < 0 || gems > 100 || xp < 0 || xp > 5000) {
    return showToast('تجاوزت الحدود القصوى المسموحة للتعويض (10000 دنانير / 100 ياقوت / 5000 خبرة).', true);
  }
  if (coins === 0 && gems === 0 && xp === 0) return showToast('أدخل قيمة واحدة على الأقل للتعويض.', true);
  if (reason.length < 3) return showToast('يجب كتابة سبب واضح للتعويض (3 أحرف على الأقل).', true);
  if (!window.confirm(`تأكيد منح تعويض: 🪙 ${coins} | 💎 ${gems} | ⭐ ${xp}\nالسبب: ${reason}`)) return;

  const btn = document.getElementById('btn-grant-compensation');
  btn.disabled = true;
  try {
    const { data, error } = await client.rpc('admin_grant_player_compensation', {
      p_user_id: uid, p_coins_delta: coins, p_gems_delta: gems, p_xp_delta: xp, p_reason: reason,
    });
    if (error) throw error;
    showToast('تم منح التعويض وتوثيقه في سجل التدقيق ✅');
    broadcastWebControlPing(data?.player_code || 'SINGLE', uid);
    document.getElementById('comp-coins').value = '0';
    document.getElementById('comp-gems').value = '0';
    document.getElementById('comp-xp').value = '0';
    document.getElementById('comp-reason').value = '';
    await Promise.all([loadPlayerDetail(uid, null), refreshAudit(), refreshOverview()]);
  } catch (err) {
    showToast(`فشل منح التعويض: ${err.message}`, true);
  } finally {
    btn.disabled = false;
  }
}

async function handleSavePermissions(e) {
  e.preventDefault();
  const client = getSupabase();
  if (!client) return;
  const uid = document.getElementById('perm-user-id').value.trim();
  if (!uid) return showToast('اختر لاعباً مسجّلاً أولاً.', true);

  const isBanned = document.getElementById('perm-is-banned').checked;
  const durVal = document.getElementById('perm-ban-duration').value;
  const hostVal = document.getElementById('perm-host-arena').value;
  const btn = document.getElementById('btn-save-player-perms');
  btn.disabled = true;
  try {
    const { data, error } = await client.rpc('admin_upsert_player_permissions', {
      p_user_id: uid,
      p_is_banned: isBanned,
      p_ban_hours: isBanned && durVal !== 'permanent' ? Number.parseInt(durVal, 10) : null,
      p_ban_reason: document.getElementById('perm-ban-reason').value.trim(),
      p_can_use_online: document.getElementById('perm-can-online').checked,
      p_can_use_diwan: document.getElementById('perm-can-diwan').checked,
      p_can_use_guilds: document.getElementById('perm-can-guilds').checked,
      p_can_host_live_arenas: hostVal === 'allowed' ? true : hostVal === 'denied' ? false : null,
      p_notes: document.getElementById('perm-notes').value.trim(),
    });
    if (error) throw error;
    showToast('تم حفظ صلاحيات وحظر اللاعب بنجاح ✅');
    broadcastWebControlPing(data?.player_code || 'SINGLE', uid);
    await Promise.all([loadPlayerDetail(uid, null), refreshAudit(), refreshOverview()]);
  } catch (err) {
    showToast(`فشل حفظ الصلاحيات: ${err.message}`, true);
  } finally {
    btn.disabled = false;
  }
}

async function handleQuickUnmute() {
  const client = getSupabase();
  const uid = document.getElementById('perm-user-id').value.trim();
  if (!client || !uid) return;
  try {
    const { data, error } = await client.rpc('admin_moderate_diwan', {
      p_action: 'unmute_user',
      p_target_user_id: uid,
      p_reason: 'فك كتم فوري من ملف الدعم بالويب',
    });
    if (error) throw error;
    showToast('تم فك كتم اللاعب بنجاح 🕊️');
    broadcastWebControlPing(data?.player_code || 'SINGLE', uid);
    await loadPlayerDetail(uid, null);
  } catch (err) {
    showToast(`فشل فك الكتم: ${err.message}`, true);
  }
}

function exportCsv() {
  if (!state.rows.length) return showToast('قم بالبحث أو تحميل قائمة اللاعبين أولاً قبل التصدير.', true);
  const lines = [CSV_HEADERS.join(',')];
  for (const row of state.rows) {
    lines.push(CSV_HEADERS.map((h) => safeCsvCell(row[h])).join(','));
  }
  const blob = new Blob([`\uFEFF${lines.join('\n')}`], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `sahaba_players_${new Date().toISOString().slice(0, 10)}.csv`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
  showToast('تم تصدير ملف CSV الآمن بنجاح 📥');
}

export function mount(container) {
  if (state.mounted || !container) return;
  container.innerHTML = buildPlayersTemplate();
  state.mounted = true;

  document.getElementById('btn-inspector-search').addEventListener('click', searchPlayers);
  document.getElementById('player-inspector-query').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      searchPlayers();
    }
  });
  document.getElementById('btn-export-players-csv').addEventListener('click', exportCsv);
  document.getElementById('compensation-form').addEventListener('submit', handleGrantCompensation);
  document.getElementById('player-permissions-form').addEventListener('submit', handleSavePermissions);
  document.getElementById('btn-quick-unmute-web').addEventListener('click', handleQuickUnmute);
  document.getElementById('btn-target-player-msg').addEventListener('click', () => {
    const d = state.currentDetail;
    if (!d) return;
    selectPlayerForAnnouncement({
      user_id: d.user_id,
      player_code: d.player_code,
      display_name: d.directory?.display_name || d.leaderboard?.display_name || 'لاعب',
    });
  });
}

export async function load() {
  await searchPlayers();
}
