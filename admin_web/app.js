import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

// Public project URL and publishable anon key only (from lib/core/supabase_config.dart).
// NEVER place any service_role key or management token in client/web code.
const SUPABASE_URL = 'https://khatzzpqxaiwuoodgcst.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_Zp9URQMtw71oyhZztDGsmg_hT9FfyIv';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
});

const state = {
  user: null,
  isAdmin: false,
  dashboardHydrated: false,
  verifiedAccessToken: null,
  verifyPromise: null,
  selectedPlayer: null,
  searchTimer: null,
  editingEventId: null,
  announcements: [],
  events: [],
};

// ==================== SECURITY & FORMATTING HELPERS ====================

function escapeHtml(raw) {
  return String(raw ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function safeHexColor(rawHex, fallback = '#D4AF37') {
  const cleaned = String(rawHex ?? '').trim();
  return /^#[0-9a-fA-F]{6}$/.test(cleaned) ? cleaned : fallback;
}

function isValidPlayerCode(code) {
  return /^SAH-[A-Z0-9]{4,8}$/.test(String(code ?? '').trim().toUpperCase());
}

function isValidHttpUrl(rawUrl) {
  const cleaned = String(rawUrl ?? '').trim();
  const lower = cleaned.toLowerCase();
  if (!lower.startsWith('https://') && !lower.startsWith('http://')) {
    return false;
  }
  try {
    const parsed = new URL(cleaned);
    return Boolean(parsed.hostname);
  } catch {
    return false;
  }
}

function setAuthWarning(message) {
  const el = document.getElementById('auth-warning');
  if (!message) {
    el.textContent = '';
    el.classList.add('hidden');
    return;
  }
  el.textContent = message;
  el.classList.remove('hidden');
}

function toIsoOrNull(localDateTimeValue) {
  const trimmed = String(localDateTimeValue ?? '').trim();
  if (!trimmed) return null;
  const parsed = new Date(trimmed);
  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
}

function toLocalInputValue(isoString) {
  if (!isoString) return '';
  const d = new Date(isoString);
  if (Number.isNaN(d.getTime())) return '';
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function formatDateDisplay(isoString) {
  if (!isoString) return 'غير محدد';
  const d = new Date(isoString);
  if (Number.isNaN(d.getTime())) return 'غير محدد';
  return d.toLocaleString('ar-EG', { dateStyle: 'medium', timeStyle: 'short' });
}

function showToast(message, isError = false) {
  const container = document.getElementById('toast-container');
  const el = document.createElement('div');
  el.className = `toast ${isError ? 'error' : ''}`;
  el.textContent = message;
  container.appendChild(el);
  window.setTimeout(() => el.remove(), 4200);
}

const ICON_EMOJI_MAP = {
  auto_awesome: '✨',
  mosque: '🕌',
  stars: '🌟',
  celebration: '🎉',
  military_tech: '🎖️',
  emoji_events: '🏆',
  campaign: '📣',
  bolt: '⚡',
  castle: '🏰',
  menu_book: '📖',
  shield: '🛡️',
};

// ==================== AUTH & AUTHORIZATION ====================

async function verifySessionAndLoad(session, eventName = '') {
  const authView = document.getElementById('auth-view');
  const dashView = document.getElementById('dashboard-view');
  const unauthorizedPanel = document.getElementById('unauthorized-panel');

  if (!session?.user) {
    state.user = null;
    state.isAdmin = false;
    state.dashboardHydrated = false;
    state.verifiedAccessToken = null;
    dashView.classList.add('hidden');
    authView.classList.remove('hidden');
    return;
  }

  if (
    state.isAdmin &&
    state.user?.id === session.user.id &&
    state.verifiedAccessToken === session.access_token
  ) {
    return;
  }

  if (state.verifyPromise) {
    return state.verifyPromise;
  }

  state.verifyPromise = (async () => {
    try {
      const sameAdminAlreadyOpen =
        state.isAdmin &&
        state.dashboardHydrated &&
        state.user?.id === session.user.id &&
        eventName === 'TOKEN_REFRESHED';

      const { data, error } = await supabase.rpc('check_is_admin');
      if (error || data !== true) {
        await supabase.auth.signOut();
        state.user = null;
        state.isAdmin = false;
        state.dashboardHydrated = false;
        state.verifiedAccessToken = null;
        dashView.classList.add('hidden');
        authView.classList.remove('hidden');
        unauthorizedPanel.classList.remove('hidden');
        document.getElementById('unauthorized-msg').textContent =
          `الحساب (${session.user.email ?? 'غير معروف'}) غير مسجل في قائمة المشرفين (app_admins). تم تسجيل الخروج فوراً.`;
        return;
      }

      setAuthWarning('');
      unauthorizedPanel.classList.add('hidden');
      state.user = session.user;
      state.isAdmin = true;
      state.verifiedAccessToken = session.access_token;
      document.getElementById('admin-user-email').textContent = session.user.email ?? 'مشرف';
      authView.classList.add('hidden');
      dashView.classList.remove('hidden');

      if (!sameAdminAlreadyOpen) {
        await loadAllDashboardData();
        state.dashboardHydrated = true;
      }
    } catch (err) {
      setAuthWarning(`تعذر التحقق من صلاحيات الجلسة: ${err.message}`);
      showToast(`خطأ في التحقق من الصلاحيات: ${err.message}`, true);
    } finally {
      state.verifyPromise = null;
    }
  })();

  return state.verifyPromise;
}

async function loginWithGoogle() {
  const redirectTo = `${window.location.origin}${window.location.pathname}`;
  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: { redirectTo },
  });
  if (error) showToast(`تعذر بدء تسجيل Google: ${error.message}`, true);
}

async function loginWithMagicLink(e) {
  e.preventDefault();
  const emailInput = document.getElementById('admin-email-input');
  const email = emailInput.value.trim();
  if (!email) return;

  const btn = document.getElementById('btn-magic-login');
  btn.disabled = true;
  try {
    const emailRedirectTo = `${window.location.origin}${window.location.pathname}`;
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: { emailRedirectTo },
    });
    if (error) throw error;
    document.getElementById('otp-verify-form').classList.remove('hidden');
    showToast(`تم إرسال رابط ورمز الدخول إلى ${email} ✅`);
  } catch (err) {
    showToast(`فشل إرسال رابط الدخول: ${err.message}`, true);
  } finally {
    btn.disabled = false;
  }
}

async function verifyOtpCode(e) {
  e.preventDefault();
  const email = document.getElementById('admin-email-input').value.trim();
  const token = document.getElementById('admin-otp-input').value.trim();
  if (!email || !token) return;

  const btn = document.getElementById('btn-verify-otp');
  btn.disabled = true;
  try {
    const { data, error } = await supabase.auth.verifyOtp({
      email,
      token,
      type: 'email',
    });
    if (error) throw error;
    if (data?.session) {
      await verifySessionAndLoad(data.session);
    }
  } catch (err) {
    showToast(`رمز التحقق غير صحيح أو منتهي: ${err.message}`, true);
  } finally {
    btn.disabled = false;
  }
}

async function logout() {
  await supabase.auth.signOut();
  state.user = null;
  state.isAdmin = false;
  state.dashboardHydrated = false;
  state.verifiedAccessToken = null;
  setAuthWarning('');
  document.getElementById('unauthorized-panel').classList.add('hidden');
  document.getElementById('dashboard-view').classList.add('hidden');
  document.getElementById('auth-view').classList.remove('hidden');
}

// ==================== DATA LOADING ====================

async function loadAllDashboardData() {
  await Promise.all([
    loadOverview(),
    loadAnnouncements(),
    loadDynamicEvents(),
  ]);
}

async function loadOverview() {
  const { data, error } = await supabase.rpc('admin_get_overview');
  if (error) {
    showToast(`تعذر تحميل الإحصائيات: ${error.message}`, true);
    return;
  }
  const ov = data ?? {};
  document.getElementById('stat-total-accounts').textContent = ov.total_accounts ?? 0;
  document.getElementById('stat-active-24h').textContent = ov.active_24h ?? 0;
  document.getElementById('stat-directory-players').textContent = ov.directory_players ?? 0;
  document.getElementById('stat-guest-players').textContent = ov.guest_players ?? 0;
  document.getElementById('stat-active-events').textContent = ov.active_events ?? 0;
  document.getElementById('stat-active-announcements').textContent = ov.active_announcements ?? 0;

  if (ov.release_config) {
    hydrateReleaseForm(ov.release_config);
  }
}

function hydrateReleaseForm(rc) {
  const maint = Boolean(rc.maintenance_mode);
  document.getElementById('rc-maintenance-mode').checked = maint;
  document.getElementById('rc-maintenance-title').value = rc.maintenance_title ?? 'صيانة وتحسينات مؤقتة';
  document.getElementById('rc-maintenance-message').value = rc.maintenance_message ?? '';
  document.getElementById('rc-min-version').value = rc.min_version_code ?? 1;
  document.getElementById('rc-latest-version').value = rc.latest_version_code ?? 19;
  document.getElementById('rc-latest-name').value = rc.latest_version_name ?? '1.0.18';
  document.getElementById('rc-update-url').value = rc.update_url ?? '';
  document.getElementById('rc-update-title').value = rc.update_title ?? 'تحديث جديد متاح';
  document.getElementById('rc-update-message').value = rc.update_message ?? '';

  const flags = rc.feature_flags ?? {};
  document.getElementById('flag-online-multiplayer').checked = flags.online_multiplayer ?? true;
  document.getElementById('flag-ghost-matches').checked = flags.ghost_matches ?? true;
  document.getElementById('flag-private-rooms').checked = flags.private_rooms ?? true;
  document.getElementById('flag-knights-store').checked = flags.knights_store ?? true;
  document.getElementById('flag-show-event-banner').checked = flags.show_event_banner ?? true;
  document.getElementById('flag-daily-challenges').checked = flags.daily_challenges ?? true;

  document.getElementById('topbar-config-ver').textContent = `#${rc.config_version ?? 1}`;
  const maintPill = document.getElementById('topbar-maint-pill');
  maintPill.textContent = maint ? 'وضع الصيانة مفعّل ⚠️' : 'النظام يعمل طبيعياً ✅';
  maintPill.className = `status-pill ${maint ? 'status-maint' : 'status-ok'}`;
}

// ==================== RELEASE CONTROL & FLAGS ====================

async function handleSaveRelease(e) {
  e.preventDefault();
  const minVer = Number.parseInt(document.getElementById('rc-min-version').value, 10);
  const latestVer = Number.parseInt(document.getElementById('rc-latest-version').value, 10);
  const latestName = document.getElementById('rc-latest-name').value.trim();
  const updateTitle = document.getElementById('rc-update-title').value.trim();
  const updateMessage = document.getElementById('rc-update-message').value.trim();
  const maintTitle = document.getElementById('rc-maintenance-title').value.trim();
  const maintMessage = document.getElementById('rc-maintenance-message').value.trim();
  const updateUrl = document.getElementById('rc-update-url').value.trim();

  if (!maintTitle || !maintMessage || !latestName || !updateTitle || !updateMessage) {
    showToast('تأكد من ملء جميع نصوص الصيانة والإصدار دون الاقتصار على مسافات.', true);
    return;
  }

  if (!Number.isFinite(minVer) || minVer < 1 || !Number.isFinite(latestVer) || latestVer < minVer) {
    showToast('يجب أن يكون أحدث رقم بناء >= الحد الأدنى الإلزامي.', true);
    return;
  }

  if (updateUrl && !isValidHttpUrl(updateUrl)) {
    showToast('يجب أن يبدأ رابط المتجر بـ https:// أو http://', true);
    return;
  }

  const maint = document.getElementById('rc-maintenance-mode').checked;
  if (maint && !window.confirm('هل أنت متأكد من تفعيل وضع الصيانة الشامل لجميع اللاعبين؟')) {
    return;
  }

  const btn = document.getElementById('btn-save-release');
  btn.disabled = true;
  try {
    const { data, error } = await supabase.rpc('admin_upsert_release_config', {
      p_platform: 'android',
      p_min_version_code: minVer,
      p_latest_version_code: latestVer,
      p_latest_version_name: latestName,
      p_update_title: updateTitle,
      p_update_message: updateMessage,
      p_update_url: updateUrl || null,
      p_maintenance_mode: maint,
      p_maintenance_title: maintTitle,
      p_maintenance_message: maintMessage,
      p_feature_flags: {
        online_multiplayer: document.getElementById('flag-online-multiplayer').checked,
        ghost_matches: document.getElementById('flag-ghost-matches').checked,
        private_rooms: document.getElementById('flag-private-rooms').checked,
        knights_store: document.getElementById('flag-knights-store').checked,
        show_event_banner: document.getElementById('flag-show-event-banner').checked,
        daily_challenges: document.getElementById('flag-daily-challenges').checked,
      },
    });
    if (error) throw error;
    if (data) hydrateReleaseForm(data);
    showToast('تم حفظ ونشر إعدادات الإصدار والأعلام ✅');
  } catch (err) {
    showToast(`فشل الحفظ: ${err.message}`, true);
  } finally {
    btn.disabled = false;
  }
}

// ==================== ANNOUNCEMENTS & USER SEARCH ====================

async function loadAnnouncements() {
  const { data, error } = await supabase.rpc('admin_list_announcements', { p_limit: 50 });
  if (error) {
    showToast(`تعذر تحميل الرسائل: ${error.message}`, true);
    return;
  }
  state.announcements = Array.isArray(data) ? data : [];
  document.getElementById('ann-count-pill').textContent = state.announcements.length;
  renderAnnouncementsList();
}

function renderAnnouncementsList() {
  const container = document.getElementById('announcements-list');
  if (!state.announcements.length) {
    container.innerHTML = '<p class="muted-text">لا توجد رسائل منشورة حالياً.</p>';
    return;
  }

  container.innerHTML = state.announcements
    .map((ann) => {
      const targetText =
        ann.target_scope === 'single_user'
          ? `موجهة: ${escapeHtml(ann.target_player_code || ann.target_user_id || 'لاعب')}`
          : 'للجميع';
      const versionMeta =
        ann.min_version_code || ann.max_version_code
          ? `<span>البناء: ${escapeHtml(ann.min_version_code ?? 1)}..${escapeHtml(ann.max_version_code ?? '∞')}</span>`
          : '';
      const expiryMeta = ann.expires_at
        ? `<span class="gold-text">ينتهي: ${escapeHtml(formatDateDisplay(ann.expires_at))}</span>`
        : '';
      const routeMeta = ann.cta_route
        ? `<span class="sky-text">المسار: ${escapeHtml(ann.cta_route)}</span>`
        : '';

      return `
        <article class="record-card">
          <div class="record-top">
            <div class="record-actions">
              <span class="badge-pill">${escapeHtml(ann.message_type)}</span>
              <span class="muted-text">${targetText}</span>
            </div>
            <div class="record-actions">
              <span class="muted-text">👁️ ${escapeHtml(ann.receipt_count ?? 0)}</span>
              <label class="switch">
                <input
                  type="checkbox"
                  data-toggle-ann="${escapeHtml(ann.id)}"
                  ${ann.is_active ? 'checked' : ''}
                />
                <span class="slider"></span>
              </label>
            </div>
          </div>
          <strong>${escapeHtml(ann.title)}</strong>
          <p class="muted-text">${escapeHtml(ann.body)}</p>
          <div class="record-actions muted-text">${versionMeta} ${expiryMeta} ${routeMeta}</div>
        </article>
      `;
    })
    .join('');

  container.querySelectorAll('input[data-toggle-ann]').forEach((input) => {
    input.addEventListener('change', () => toggleAnnouncement(input.dataset.toggleAnn, input.checked));
  });
}

async function toggleAnnouncement(id, nextActive) {
  const { data, error } = await supabase.rpc('admin_set_announcement_active', {
    p_announcement_id: id,
    p_is_active: nextActive,
  });
  if (error || data !== true) {
    showToast(`تعذر تحديث الرسالة: ${error?.message ?? ''}`, true);
    await loadAnnouncements();
    return;
  }
  showToast(nextActive ? 'تم تفعيل الرسالة ✅' : 'تم إيقاف الرسالة ⏸️');
  await Promise.all([loadAnnouncements(), loadOverview()]);
}

async function executeUserSearch(query) {
  const { data, error } = await supabase.rpc('admin_search_users', {
    p_query: query.trim(),
    p_limit: 20,
  });
  if (error) {
    showToast(`فشل البحث عن اللاعبين: ${error.message}`, true);
    return;
  }
  const results = Array.isArray(data) ? data : [];
  renderSearchResults(results);
}

function renderSearchResults(results) {
  const box = document.getElementById('user-search-results');
  if (!results.length) {
    box.innerHTML = '<p class="muted-text">لم يُعثر على لاعبين مطابقين.</p>';
    return;
  }
  box.innerHTML = results
    .map((p, index) => {
      const targetable = Boolean(p.user_id) || isValidPlayerCode(p.player_code);
      const roleLabel = p.is_guest ? 'ضيف 🎭' : escapeHtml(p.email || 'حساب Google');
      const codeLabel = p.player_code ? ` • ${escapeHtml(p.player_code)}` : '';
      return `
        <button
          type="button"
          class="search-item"
          data-pick-index="${index}"
          ${targetable ? '' : 'disabled'}
        >
          <div>
            <strong>${escapeHtml(p.display_name || 'لاعب')}</strong>
            <div class="muted-text">${roleLabel}${codeLabel} • 🏆 ${escapeHtml(p.trophies ?? 1000)}</div>
          </div>
          <span class="gold-text">${targetable ? 'اختيار' : 'بلا معرّف'}</span>
        </button>
      `;
    })
    .join('');

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

async function handleCreateAnnouncement(e) {
  e.preventDefault();
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

  if (!title || !body) {
    showToast('عنوان ونص الرسالة مطلوبان.', true);
    return;
  }
  if ((ctaLabel && !ctaRoute) || (!ctaLabel && ctaRoute)) {
    showToast('لإظهار زر إجراء في النافذة، أدخل نص الزر والمسار/الرابط معاً.', true);
    return;
  }
  if (minVer !== null && (!Number.isFinite(minVer) || minVer < 1)) {
    showToast('رقم البناء الأدنى يجب أن يكون >= 1.', true);
    return;
  }
  if (maxVer !== null && (!Number.isFinite(maxVer) || maxVer < 1)) {
    showToast('رقم البناء الأقصى يجب أن يكون >= 1.', true);
    return;
  }
  if (minVer !== null && maxVer !== null && maxVer < minVer) {
    showToast('الحد الأقصى للإصدار يجب أن يكون >= الحد الأدنى.', true);
    return;
  }

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
      if (!isValidPlayerCode(manualCode)) {
        showToast('صيغة كود اللاعب غير صالحة (المطلوب SAH-XXXX).', true);
        return;
      }
      targetPlayerCode = manualCode;
    }
    if (!targetUserId && !targetPlayerCode) {
      showToast('اختر لاعباً من نتائج البحث أو أدخل كود SAH-XXXX.', true);
      return;
    }
  }

  const btn = document.getElementById('btn-publish-announcement');
  btn.disabled = true;
  try {
    const { error } = await supabase.rpc('admin_create_announcement', {
      p_title: title,
      p_body: body,
      p_message_type: type,
      p_target_scope: scope,
      p_target_user_id: targetUserId,
      p_target_player_code: targetPlayerCode,
      p_cta_label: ctaLabel,
      p_cta_route: ctaRoute,
      p_is_dismissible: !locked,
      p_expires_at: expiresAt,
      p_min_version_code: minVer,
      p_max_version_code: maxVer,
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
    updateAnnouncementPreview();
    showToast('تم إرسال ونشر الرسالة بنجاح 🚀');
    await Promise.all([loadAnnouncements(), loadOverview()]);
  } catch (err) {
    showToast(`فشل نشر الرسالة: ${err.message}`, true);
  } finally {
    btn.disabled = false;
  }
}

function updateAnnouncementPreview() {
  const type = document.getElementById('ann-type').value;
  const scope = document.getElementById('ann-scope').value;
  const title = document.getElementById('ann-title').value.trim() || 'معاينة عنوان الرسالة';
  const body = document.getElementById('ann-body').value.trim() || 'سيظهر نص الرسالة بهذا التنسيق داخل هاتف اللاعب.';
  const ctaLabel = document.getElementById('ann-cta-label').value.trim();
  const ctaRoute = document.getElementById('ann-cta-route').value.trim();
  const isLocked = type === 'mandatory' || document.getElementById('ann-locked').checked;

  const badgeStyles = {
    normal: { label: 'إشعار 📢', color: '#38bdf8', bg: 'rgba(56,189,248,0.2)' },
    mandatory: { label: 'إشعار إلزامي ⚠️', color: '#e11d48', bg: 'rgba(225,29,72,0.24)' },
    admin: { label: 'رسالة إدارية 🛡️', color: '#f3c644', bg: 'rgba(243,198,68,0.18)' },
    motivational: { label: 'رسالة تحفيزية ✨', color: '#10b981', bg: 'rgba(16,185,129,0.2)' },
  }[type];

  const preview = document.getElementById('ann-live-preview');
  preview.style.borderColor = badgeStyles.color;
  preview.innerHTML = `
    <span class="preview-badge" style="color:${badgeStyles.color};background:${badgeStyles.bg};">
      ${escapeHtml(badgeStyles.label)}${scope === 'single_user' ? ' • موجهة لك' : ''}
    </span>
    <h3 style="margin:4px 0 6px;font-size:1.05rem;">${escapeHtml(title)}</h3>
    <p class="muted-text" style="margin-bottom:14px;">${escapeHtml(body)}</p>
    ${
      ctaLabel && ctaRoute
        ? `<div class="btn btn-gold btn-block btn-sm" style="margin-bottom:8px;">${escapeHtml(ctaLabel)}</div>`
        : ''
    }
    <div class="btn btn-outline btn-block btn-sm">${isLocked ? 'فهمت وأوافق' : 'حسناً'}</div>
  `;
}

// ==================== DYNAMIC EVENTS ====================

async function loadDynamicEvents() {
  const { data, error } = await supabase.rpc('admin_list_dynamic_events');
  if (error) {
    showToast(`تعذر تحميل الأحداث: ${error.message}`, true);
    return;
  }
  state.events = Array.isArray(data) ? data : [];
  document.getElementById('ev-count-pill').textContent = state.events.length;
  renderEventsList();
}

function renderEventsList() {
  const container = document.getElementById('events-list');
  if (!state.events.length) {
    container.innerHTML = '<p class="muted-text">لا توجد أحداث ديناميكية حالياً.</p>';
    return;
  }
  const now = Date.now();
  container.innerHTML = state.events
    .map((ev) => {
      const hex = safeHexColor(ev.theme_color_hex);
      const startOk = !ev.starts_at || new Date(ev.starts_at).getTime() <= now;
      const endOk = !ev.ends_at || new Date(ev.ends_at).getTime() > now;
      const statusLabel = !ev.is_active
        ? 'متوقف ⏸️'
        : startOk && endOk
          ? 'مباشر الآن 🟢'
          : !startOk
            ? 'مجدول ⏳'
            : 'منتهٍ ⛔';

      return `
        <article class="record-card" style="border-color:${hex};">
          <div class="record-top">
            <div>
              <strong>${ICON_EMOJI_MAP[ev.icon_name] ?? '✨'} ${escapeHtml(ev.title)}</strong>
              <div class="muted-text">${statusLabel} • أولوية ${escapeHtml(ev.priority ?? 100)}</div>
            </div>
            <label class="switch">
              <input type="checkbox" data-toggle-event="${escapeHtml(ev.id)}" ${ev.is_active ? 'checked' : ''} />
              <span class="slider"></span>
            </label>
          </div>
          <div class="record-actions">
            <button class="btn btn-outline btn-sm" data-edit-event="${escapeHtml(ev.id)}" type="button">✏️ تعديل</button>
            <button class="btn btn-danger-outline btn-sm" data-delete-event="${escapeHtml(ev.id)}" type="button">🗑️ حذف</button>
          </div>
        </article>
      `;
    })
    .join('');

  container.querySelectorAll('input[data-toggle-event]').forEach((input) => {
    input.addEventListener('change', () => toggleDynamicEvent(input.dataset.toggleEvent, input.checked));
  });
  container.querySelectorAll('button[data-edit-event]').forEach((btn) => {
    btn.addEventListener('click', () => startEditingEvent(btn.dataset.editEvent));
  });
  container.querySelectorAll('button[data-delete-event]').forEach((btn) => {
    btn.addEventListener('click', () => deleteDynamicEvent(btn.dataset.deleteEvent));
  });
}

function syncEventTargetVisibility() {
  const actionType = document.getElementById('ev-action-type').value;
  document.getElementById('ev-target-wrap').classList.toggle('hidden', actionType === 'none');
}

function startEditingEvent(id) {
  const ev = state.events.find((item) => item.id === id);
  if (!ev) return;
  state.editingEventId = ev.id;
  document.getElementById('event-form-heading').textContent = '✏️ تعديل الحدث المحدد';
  document.getElementById('btn-save-event-text').textContent = 'حفظ تعديلات الحدث';
  document.getElementById('btn-cancel-event-edit').classList.remove('hidden');

  document.getElementById('ev-badge').value = ev.badge_text ?? 'حدث نشط';
  document.getElementById('ev-priority').value = ev.priority ?? 100;
  document.getElementById('ev-title').value = ev.title ?? '';
  document.getElementById('ev-subtitle').value = ev.subtitle ?? '';
  document.getElementById('ev-body').value = ev.body ?? '';
  document.getElementById('ev-action-type').value = ev.action_type ?? 'open_event_screen';
  document.getElementById('ev-cta-label').value = ev.cta_label ?? 'اكتشف الآن';
  document.getElementById('ev-action-target').value = ev.action_target ?? '';
  const hex = safeHexColor(ev.theme_color_hex);
  document.getElementById('ev-color').value = hex;
  document.getElementById('ev-color-picker').value = hex.toLowerCase();
  document.getElementById('ev-icon').value = ev.icon_name ?? 'auto_awesome';
  document.getElementById('ev-starts-at').value = toLocalInputValue(ev.starts_at);
  document.getElementById('ev-ends-at').value = toLocalInputValue(ev.ends_at);
  document.getElementById('ev-is-active').checked = Boolean(ev.is_active);
  syncEventTargetVisibility();
  updateEventPreview();
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function resetEventForm() {
  state.editingEventId = null;
  document.getElementById('event-form').reset();
  document.getElementById('ev-badge').value = 'موسم نشط الآن';
  document.getElementById('ev-priority').value = '100';
  document.getElementById('ev-cta-label').value = 'اكتشف الآن';
  document.getElementById('ev-color').value = '#D4AF37';
  document.getElementById('ev-color-picker').value = '#d4af37';
  document.getElementById('ev-is-active').checked = true;
  document.getElementById('event-form-heading').textContent = '🌟 إنشاء حدث ديناميكي جديد';
  document.getElementById('btn-save-event-text').textContent = 'نشر الحدث الآن';
  document.getElementById('btn-cancel-event-edit').classList.add('hidden');
  syncEventTargetVisibility();
  updateEventPreview();
}

async function handleSaveEvent(e) {
  e.preventDefault();
  const title = document.getElementById('ev-title').value.trim();
  const actionType = document.getElementById('ev-action-type').value;
  const actionTarget = actionType === 'none' ? '' : document.getElementById('ev-action-target').value.trim();
  const rawHex = document.getElementById('ev-color').value.trim();
  const parsedPriority = Number.parseInt(document.getElementById('ev-priority').value, 10);
  const startsAt = toIsoOrNull(document.getElementById('ev-starts-at').value);
  const endsAt = toIsoOrNull(document.getElementById('ev-ends-at').value);

  if (!title) {
    showToast('عنوان الحدث مطلوب ولا يمكن أن يكون فارغاً.', true);
    return;
  }
  if (!/^#[0-9a-fA-F]{6}$/.test(rawHex)) {
    showToast('أدخل كود لون Hex صحيح مكوناً من 6 خانات مثل #D4AF37.', true);
    return;
  }
  if ((actionType === 'navigate_route' || actionType === 'open_url') && !actionTarget) {
    showToast('أدخل المسار أو الرابط المستهدف لهذا الإجراء.', true);
    return;
  }
  if (actionType === 'open_url' && !isValidHttpUrl(actionTarget)) {
    showToast('يجب أن يبدأ الرابط الخارجي بـ https:// أو http://', true);
    return;
  }
  if (startsAt && endsAt && new Date(endsAt).getTime() <= new Date(startsAt).getTime()) {
    showToast('وقت انتهاء الحدث يجب أن يكون بعد وقت بدئه.', true);
    return;
  }

  const btn = document.getElementById('btn-save-event');
  btn.disabled = true;
  try {
    const { error } = await supabase.rpc('admin_upsert_dynamic_event', {
      p_id: state.editingEventId,
      p_badge_text: document.getElementById('ev-badge').value.trim() || 'حدث نشط',
      p_title: title,
      p_subtitle: document.getElementById('ev-subtitle').value.trim(),
      p_body: document.getElementById('ev-body').value.trim(),
      p_cta_label: document.getElementById('ev-cta-label').value.trim() || 'اكتشف الآن',
      p_action_type: actionType,
      p_action_target: actionTarget,
      p_theme_color_hex: safeHexColor(rawHex),
      p_icon_name: document.getElementById('ev-icon').value,
      p_priority: Number.isFinite(parsedPriority) ? parsedPriority : 100,
      p_is_active: document.getElementById('ev-is-active').checked,
      p_starts_at: startsAt,
      p_ends_at: endsAt,
    });
    if (error) throw error;

    const wasEditing = Boolean(state.editingEventId);
    resetEventForm();
    showToast(wasEditing ? 'تم تحديث الحدث بنجاح ✅' : 'تم نشر الحدث الجديد 🎉');
    await Promise.all([loadDynamicEvents(), loadOverview()]);
  } catch (err) {
    showToast(`فشل حفظ الحدث: ${err.message}`, true);
  } finally {
    btn.disabled = false;
  }
}

async function toggleDynamicEvent(id, nextActive) {
  const { error } = await supabase.rpc('admin_toggle_dynamic_event', {
    p_event_id: id,
    p_is_active: nextActive,
  });
  if (error) {
    showToast(`تعذر تغيير حالة الحدث: ${error.message}`, true);
    await loadDynamicEvents();
    return;
  }
  showToast(nextActive ? 'تم تفعيل الحدث ✅' : 'تم إيقاف الحدث ⏸️');
  await Promise.all([loadDynamicEvents(), loadOverview()]);
}

async function deleteDynamicEvent(id) {
  const ev = state.events.find((item) => item.id === id);
  if (!window.confirm(`حذف الحدث «${ev?.title ?? ''}» نهائياً؟`)) return;
  const { data, error } = await supabase.rpc('admin_delete_dynamic_event', {
    p_event_id: id,
  });
  if (error || data !== true) {
    showToast(`تعذر حذف الحدث: ${error?.message ?? ''}`, true);
    return;
  }
  if (state.editingEventId === id) resetEventForm();
  showToast('تم حذف الحدث بنجاح 🗑️');
  await Promise.all([loadDynamicEvents(), loadOverview()]);
}

function updateEventPreview() {
  const badge = document.getElementById('ev-badge').value.trim() || 'حدث نشط';
  const title = document.getElementById('ev-title').value.trim() || 'معاينة عنوان الحدث الديناميكي';
  const subtitle = document.getElementById('ev-subtitle').value.trim() || 'يظهر هذا البانر في الشاشة الرئيسية للاعبين';
  const cta = document.getElementById('ev-cta-label').value.trim() || 'اكتشف الآن';
  const actionType = document.getElementById('ev-action-type').value;
  const hex = safeHexColor(document.getElementById('ev-color').value);
  const icon = ICON_EMOJI_MAP[document.getElementById('ev-icon').value] ?? '✨';

  document.getElementById('event-live-preview').innerHTML = `
    <div class="preview-banner" style="border-color:${hex};background:linear-gradient(90deg, ${hex}33, rgba(0,0,0,0.45));">
      <div style="display:flex;align-items:center;gap:10px;min-width:0;">
        <div style="width:40px;height:40px;border-radius:12px;display:grid;place-items:center;background:${hex}2e;border:1px solid ${hex}88;flex-shrink:0;">
          ${icon}
        </div>
        <div style="min-width:0;">
          <span class="preview-badge" style="color:${hex};background:${hex}2e;margin-bottom:2px;">${escapeHtml(badge)}</span>
          <div style="font-weight:800;font-size:0.92rem;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${escapeHtml(title)}</div>
          <div class="muted-text" style="white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${escapeHtml(subtitle)}</div>
        </div>
      </div>
      ${
        actionType !== 'none'
          ? `<span class="btn btn-sm" style="background:${hex};color:#0d061a;flex-shrink:0;">${escapeHtml(cta)}</span>`
          : ''
      }
    </div>
  `;
}

// ==================== WIRE UP EVENTS & BOOT ====================

function bindUiListeners() {
  document.getElementById('btn-google-login').addEventListener('click', loginWithGoogle);
  document.getElementById('magic-link-form').addEventListener('submit', loginWithMagicLink);
  document.getElementById('btn-toggle-otp-box').addEventListener('click', () => {
    document.getElementById('otp-verify-form').classList.toggle('hidden');
  });
  document.getElementById('otp-verify-form').addEventListener('submit', verifyOtpCode);
  document.getElementById('btn-logout').addEventListener('click', logout);
  document.getElementById('btn-refresh-all').addEventListener('click', loadAllDashboardData);

  // Tabs
  document.querySelectorAll('.tab-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.tab-btn').forEach((b) => b.classList.remove('active'));
      document.querySelectorAll('.tab-panel').forEach((p) => p.classList.remove('active'));
      btn.classList.add('active');
      document.getElementById(`tab-${btn.dataset.tab}`).classList.add('active');
    });
  });

  // Release form
  document.getElementById('release-form').addEventListener('submit', handleSaveRelease);

  // Announcement form & live preview
  document.getElementById('announcement-form').addEventListener('submit', handleCreateAnnouncement);
  document.getElementById('ann-scope').addEventListener('change', (e) => {
    document.getElementById('single-user-box').classList.toggle('hidden', e.target.value !== 'single_user');
    updateAnnouncementPreview();
  });

  document.getElementById('ann-type').addEventListener('change', (e) => {
    const lockedBox = document.getElementById('ann-locked');
    if (e.target.value === 'mandatory') {
      lockedBox.checked = true;
      lockedBox.disabled = true;
    } else {
      lockedBox.disabled = false;
    }
    updateAnnouncementPreview();
  });

  ['ann-title', 'ann-body', 'ann-cta-label', 'ann-cta-route', 'ann-locked'].forEach((id) => {
    document.getElementById(id).addEventListener('input', updateAnnouncementPreview);
    document.getElementById(id).addEventListener('change', updateAnnouncementPreview);
  });

  document.querySelectorAll('button[data-ann-route]').forEach((btn) => {
    btn.addEventListener('click', () => {
      document.getElementById('ann-cta-route').value = btn.dataset.annRoute;
      if (!document.getElementById('ann-cta-label').value.trim()) {
        document.getElementById('ann-cta-label').value = btn.dataset.annCta;
      }
      updateAnnouncementPreview();
    });
  });

  // Debounced player search
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

  // Event form & live preview
  document.getElementById('event-form').addEventListener('submit', handleSaveEvent);
  document.getElementById('btn-cancel-event-edit').addEventListener('click', resetEventForm);
  document.getElementById('ev-color-picker').addEventListener('input', (e) => {
    document.getElementById('ev-color').value = e.target.value.toUpperCase();
    updateEventPreview();
  });
  document.getElementById('ev-color').addEventListener('input', (e) => {
    const valid = safeHexColor(e.target.value, '');
    if (valid) document.getElementById('ev-color-picker').value = valid.toLowerCase();
    updateEventPreview();
  });

  ['ev-badge', 'ev-title', 'ev-subtitle', 'ev-cta-label', 'ev-action-type', 'ev-icon'].forEach((id) => {
    document.getElementById(id).addEventListener('input', updateEventPreview);
    document.getElementById(id).addEventListener('change', updateEventPreview);
  });
  document.getElementById('ev-action-type').addEventListener('change', syncEventTargetVisibility);

  syncEventTargetVisibility();
  updateAnnouncementPreview();
  updateEventPreview();
}

function checkUrlAuthError() {
  const searchParams = new URLSearchParams(window.location.search);
  const hashRaw = window.location.hash.startsWith('#') ? window.location.hash.slice(1) : '';
  const hashParams = new URLSearchParams(hashRaw);
  const errDesc =
    searchParams.get('error_description') ||
    hashParams.get('error_description') ||
    searchParams.get('error') ||
    hashParams.get('error');
  if (errDesc) {
    setAuthWarning(`تعذر إتمام تسجيل الدخول عبر OAuth: ${errDesc}`);
  }
}

async function init() {
  bindUiListeners();
  checkUrlAuthError();
  const { data } = await supabase.auth.getSession();
  await verifySessionAndLoad(data.session, 'INITIAL_SESSION');

  supabase.auth.onAuthStateChange((event, session) => {
    verifySessionAndLoad(session, event);
  });
}

init();
