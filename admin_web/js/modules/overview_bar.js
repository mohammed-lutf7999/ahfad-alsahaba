import { notifyOverviewHydrated } from '../core/app_bus.js';
import { adminState, getSupabase } from '../core/supabase_client.js';
import { escapeHtml, showToast } from '../core/ui_utils.js';

export function updateTopbarReleaseStatus(rc) {
  if (!rc) return;
  const maint = Boolean(rc.maintenance_mode);
  const verEl = document.getElementById('topbar-config-ver');
  const maintPill = document.getElementById('topbar-maint-pill');
  if (verEl) verEl.textContent = `#${rc.config_version ?? 1}`;
  if (maintPill) {
    maintPill.textContent = maint ? 'وضع الصيانة مفعّل ⚠️' : 'النظام يعمل طبيعياً ✅';
    maintPill.className = `status-pill ${maint ? 'status-maint' : 'status-ok'}`;
  }
  const flags = rc.feature_flags ?? {};
  adminState.livePingEnabled = flags.live_announcement_ping ?? true;
}

export function renderVersionBreakdown(ov) {
  const listEl = document.getElementById('version-breakdown-list');
  const totalEl = document.getElementById('version-breakdown-total');
  if (!listEl || !totalEl) return;

  const rows = Array.isArray(ov?.version_breakdown) ? ov.version_breakdown : [];
  const total = rows.reduce((sum, r) => sum + Number(r.players_count || 0), 0);
  totalEl.textContent = `إجمالي الدليل: ${total}`;

  if (!rows.length) {
    listEl.innerHTML = '<p class="muted-text">لا توجد بيانات توزيع إصدارات مسجّلة بعد.</p>';
    return;
  }

  listEl.innerHTML = rows
    .map((row) => {
      const count = Number(row.players_count || 0);
      const pct = total > 0 ? Math.round((count / total) * 100) : 0;
      const verLabel = row.app_version
        ? `${escapeHtml(row.app_version)} (b${escapeHtml(row.version_code ?? '?')})`
        : `Build ${escapeHtml(row.version_code ?? '?')}`;
      return `
        <div class="version-row">
          <span class="code-tag">${verLabel}</span>
          <div class="version-track">
            <div class="version-fill" style="width:${Math.max(4, pct)}%;"></div>
          </div>
          <span class="muted-text">${count} (${pct}%)</span>
        </div>
      `;
    })
    .join('');
}

export async function loadOverview() {
  const supabase = getSupabase();
  if (!supabase) return null;
  const { data, error } = await supabase.rpc('admin_get_overview');
  if (error) {
    showToast(`تعذر تحميل الإحصائيات: ${error.message}`, true);
    return null;
  }
  const ov = data ?? {};
  adminState.lastOverview = ov;

  const setText = (id, val) => {
    const el = document.getElementById(id);
    if (el) el.textContent = val;
  };
  setText('stat-total-accounts', ov.total_accounts ?? 0);
  setText('stat-active-24h', ov.active_24h ?? 0);
  setText('stat-directory-players', ov.directory_players ?? 0);
  setText('stat-guest-players', ov.guest_players ?? 0);
  setText('stat-active-events', ov.active_events ?? 0);
  setText('stat-active-announcements', ov.active_announcements ?? 0);
  setText('stat-store-items', ov.store_items_count ?? 0);
  setText('stat-library-items', ov.library_items_count ?? 0);
  setText('stat-quiz-questions', ov.quiz_questions_count ?? 0);
  setText('stat-ghosts-summary', `${ov.active_ghosts ?? 0} / ${ov.total_ghosts ?? 0}`);
  setText('topbar-cms-ver', `#${ov.cms_version ?? 1}`);

  renderVersionBreakdown(ov);
  if (ov.release_config) {
    updateTopbarReleaseStatus(ov.release_config);
  }
  notifyOverviewHydrated(ov);
  return ov;
}
