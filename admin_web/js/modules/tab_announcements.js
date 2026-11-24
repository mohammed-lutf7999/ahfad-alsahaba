import { refreshOverview } from '../core/app_bus.js';
import { broadcastWebControlPing } from '../core/rest_broadcast.js';
import { getSupabase } from '../core/supabase_client.js';
import { escapeHtml, isValidPlayerCode, showToast, toIsoOrNull } from '../core/ui_utils.js';
import {
  buildAnnouncementsTemplate,
  renderAnnouncementPreviewHtml,
  renderAnnouncementsListHtml,
  renderUserSearchResultsHtml,
} from './tab_announcements_view.js';

const state = {
  mounted: false,
  announcements: [],
  selectedPlayer: null,
  searchTimer: null,
};

function renderSelectedPlayerBanner() {
  const banner = document.getElementById('selected-player-banner');
  if (!state.selectedPlayer) {
    banner.classList.add('hidden');
    banner.innerHTML = '';
    return;
  }
  const p = state.selectedPlayer;
  const codeText = p.player_code ? ` (${escapeHtml(p.player_code)})` : '';
  banner.classList.remove('hidden');
  banner.innerHTML = `
    <span>✅ المستهدف: ${escapeHtml(p.display_name || 'لاعب')}${codeText}</span>
    <button id="btn-clear-selected-player" class="btn btn-sm btn-danger-outline" type="button">إلغاء</button>
  `;
  document.getElementById('btn-clear-selected-player').addEventListener('click', () => {
    state.selectedPlayer = null;
    renderSelectedPlayerBanner();
  });
}

function updatePreview() {
  const type = document.getElementById('ann-type').value;
  const { borderColor, html } = renderAnnouncementPreviewHtml({
    type,
    scope: document.getElementById('ann-scope').value,
    title: document.getElementById('ann-title').value.trim() || 'معاينة عنوان الرسالة',
    body: document.getElementById('ann-body').value.trim() || 'سيظهر نص الرسالة بهذا التنسيق داخل هاتف اللاعب.',
    ctaLabel: document.getElementById('ann-cta-label').value.trim(),
    ctaRoute: document.getElementById('ann-cta-route').value.trim(),
    isLocked: type === 'mandatory' || document.getElementById('ann-locked').checked,
  });
  const preview = document.getElementById('ann-live-preview');
  preview.style.borderColor = borderColor;
  preview.innerHTML = html;
}

async function executeUserSearch(query) {
  const supabase = getSupabase();
  if (!supabase) return;
  const { data, error } = await supabase.rpc('admin_search_users', { p_query: query.trim(), p_limit: 20 });
  if (error) {
    showToast(`فشل البحث عن اللاعبين: ${error.message}`, true);
    return;
  }
  const results = Array.isArray(data) ? data : [];
  const box = document.getElementById('user-search-results');
  box.innerHTML = renderUserSearchResultsHtml(results);
  box.querySelectorAll('button[data-pick-index]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const picked = results[Number(btn.dataset.pickIndex)];
      if (!picked) return;
      state.selectedPlayer = picked;
      document.getElementById('manual-player-code').value = '';
      renderSelectedPlayerBanner();
    });
  });
}

function renderList() {
  const container = document.getElementById('announcements-list');
  document.getElementById('ann-count-pill').textContent = state.announcements.length;
  container.innerHTML = renderAnnouncementsListHtml(state.announcements);
  container.querySelectorAll('input[data-toggle-ann]').forEach((input) => {
    input.addEventListener('change', () => toggleAnnouncement(input.dataset.toggleAnn, input.checked));
  });
}

async function toggleAnnouncement(id, nextActive) {
  const supabase = getSupabase();
  if (!supabase) return;
  const { data, error } = await supabase.rpc('admin_set_announcement_active', {
    p_announcement_id: id,
    p_is_active: nextActive,
  });
  if (error || data !== true) {
    showToast(`تعذر تحديث الرسالة: ${error?.message ?? ''}`, true);
    await load();
    return;
  }
  showToast(nextActive ? 'تم تفعيل الرسالة ✅' : 'تم إيقاف الرسالة ⏸️');
  await Promise.all([load(), refreshOverview()]);
}

async function handleCreate(e) {
  e.preventDefault();
  const supabase = getSupabase();
  if (!supabase) return;

  const type = document.getElementById('ann-type').value;
  const scope = document.getElementById('ann-scope').value;
  const title = document.getElementById('ann-title').value.trim();
  const body = document.getElementById('ann-body').value.trim();
  const ctaLabel = document.getElementById('ann-cta-label').value.trim() || null;
  const ctaRoute = document.getElementById('ann-cta-route').value.trim() || null;
  const minRaw = document.getElementById('ann-min-ver').value.trim();
  const maxRaw = document.getElementById('ann-max-ver').value.trim();
  const minVer = minRaw ? Number.parseInt(minRaw, 10) : null;
  const maxVer = maxRaw ? Number.parseInt(maxRaw, 10) : null;
  const expiresAt = toIsoOrNull(document.getElementById('ann-expires-at').value);
  const locked = type === 'mandatory' ? true : document.getElementById('ann-locked').checked;

  if (!title || !body) return showToast('عنوان ونص الرسالة مطلوبان.', true);
  if ((ctaLabel && !ctaRoute) || (!ctaLabel && ctaRoute)) {
    return showToast('لإظهار زر إجراء في النافذة، أدخل نص الزر والمسار/الرابط معاً.', true);
  }
  if (minVer !== null && (!Number.isFinite(minVer) || minVer < 1)) return showToast('رقم البناء الأدنى يجب أن يكون >= 1.', true);
  if (maxVer !== null && (!Number.isFinite(maxVer) || maxVer < 1)) return showToast('رقم البناء الأقصى يجب أن يكون >= 1.', true);
  if (minVer !== null && maxVer !== null && maxVer < minVer) return showToast('الحد الأقصى للإصدار يجب أن يكون >= الحد الأدنى.', true);

  let targetUserId = null;
  let targetPlayerCode = null;
  if (scope === 'single_user') {
    const manualCode = document.getElementById('manual-player-code').value.trim().toUpperCase();
    if (state.selectedPlayer) {
      targetUserId = state.selectedPlayer.user_id || null;
      targetPlayerCode = isValidPlayerCode(state.selectedPlayer.player_code)
        ? state.selectedPlayer.player_code.trim().toUpperCase()
        : null;
    } else if (manualCode) {
      if (!isValidPlayerCode(manualCode)) return showToast('صيغة كود اللاعب غير صالحة (المطلوب SAH-XXXX).', true);
      targetPlayerCode = manualCode;
    }
    if (!targetUserId && !targetPlayerCode) {
      return showToast('اختر لاعباً من نتائج البحث أو أدخل كود SAH-XXXX.', true);
    }
  }

  const btn = document.getElementById('btn-publish-announcement');
  btn.disabled = true;
  try {
    const { error } = await supabase.rpc('admin_create_announcement', {
      p_title: title, p_body: body, p_message_type: type, p_target_scope: scope,
      p_target_user_id: targetUserId, p_target_player_code: targetPlayerCode,
      p_cta_label: ctaLabel, p_cta_route: ctaRoute, p_is_dismissible: !locked,
      p_expires_at: expiresAt, p_min_version_code: minVer, p_max_version_code: maxVer,
    });
    if (error) throw error;

    e.target.reset();
    const lockedBox = document.getElementById('ann-locked');
    lockedBox.disabled = false;
    lockedBox.checked = false;
    state.selectedPlayer = null;
    renderSelectedPlayerBanner();
    document.getElementById('user-search-results').innerHTML = '';
    document.getElementById('single-user-box').classList.add('hidden');
    updatePreview();
    showToast('تم إرسال ونشر الرسالة بنجاح 🚀');
    broadcastWebControlPing(scope === 'single_user' ? targetPlayerCode || 'SINGLE' : 'ALL', targetUserId);
    await Promise.all([load(), refreshOverview()]);
  } catch (err) {
    showToast(`فشل نشر الرسالة: ${err.message}`, true);
  } finally {
    btn.disabled = false;
  }
}

export function selectPlayer(playerObj) {
  if (!playerObj || !state.mounted) return;
  state.selectedPlayer = {
    user_id: playerObj.user_id || null,
    player_code: playerObj.player_code || null,
    display_name: playerObj.display_name || 'لاعب',
  };
  document.getElementById('ann-scope').value = 'single_user';
  document.getElementById('single-user-box').classList.remove('hidden');
  document.getElementById('manual-player-code').value = '';
  renderSelectedPlayerBanner();
  updatePreview();
}

export function mount(container) {
  if (state.mounted || !container) return;
  container.innerHTML = buildAnnouncementsTemplate();
  state.mounted = true;

  document.getElementById('announcement-form').addEventListener('submit', handleCreate);
  document.getElementById('ann-scope').addEventListener('change', (e) => {
    document.getElementById('single-user-box').classList.toggle('hidden', e.target.value !== 'single_user');
    updatePreview();
  });
  document.getElementById('ann-type').addEventListener('change', (e) => {
    const lockedBox = document.getElementById('ann-locked');
    lockedBox.disabled = e.target.value === 'mandatory';
    if (e.target.value === 'mandatory') lockedBox.checked = true;
    updatePreview();
  });
  ['ann-title', 'ann-body', 'ann-cta-label', 'ann-cta-route', 'ann-locked'].forEach((id) => {
    const el = document.getElementById(id);
    el.addEventListener('input', updatePreview);
    el.addEventListener('change', updatePreview);
  });
  container.querySelectorAll('button[data-ann-route]').forEach((btn) => {
    btn.addEventListener('click', () => {
      document.getElementById('ann-cta-route').value = btn.dataset.annRoute;
      if (!document.getElementById('ann-cta-label').value.trim()) {
        document.getElementById('ann-cta-label').value = btn.dataset.annCta;
      }
      updatePreview();
    });
  });

  const searchInput = document.getElementById('user-search-input');
  searchInput.addEventListener('input', () => {
    window.clearTimeout(state.searchTimer);
    const q = searchInput.value.trim();
    if (!q) {
      document.getElementById('user-search-results').innerHTML = '';
      return;
    }
    state.searchTimer = window.setTimeout(() => executeUserSearch(q), 350);
  });
  document.getElementById('btn-search-users').addEventListener('click', () => {
    const q = searchInput.value.trim();
    if (q) executeUserSearch(q);
  });
  document.getElementById('manual-player-code').addEventListener('input', (e) => {
    if (state.selectedPlayer && e.target.value.trim()) {
      state.selectedPlayer = null;
      renderSelectedPlayerBanner();
    }
  });
  updatePreview();
}

export async function load() {
  const supabase = getSupabase();
  if (!supabase) return;
  const { data, error } = await supabase.rpc('admin_list_announcements', { p_limit: 50 });
  if (error) {
    showToast(`تعذر تحميل الرسائل: ${error.message}`, true);
    return;
  }
  state.announcements = Array.isArray(data) ? data : [];
  renderList();
}
