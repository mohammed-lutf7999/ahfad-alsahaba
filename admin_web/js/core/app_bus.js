import { broadcastWebControlPing } from './rest_broadcast.js';
import { getSupabase } from './supabase_client.js';
import { showToast } from './ui_utils.js';

const handlers = {
  refreshOverview: async () => {},
  refreshAudit: async () => {},
  switchToTab: async () => {},
  selectPlayerForAnnouncement: async () => {},
  onOverviewHydrated: () => {},
};

export function registerAppBus(overrides) {
  Object.assign(handlers, overrides);
}

export function refreshOverview() {
  return handlers.refreshOverview();
}

export function refreshAudit() {
  return handlers.refreshAudit();
}

export function switchToTab(tabName) {
  return handlers.switchToTab(tabName);
}

export function selectPlayerForAnnouncement(playerObj) {
  return handlers.selectPlayerForAnnouncement(playerObj);
}

export function notifyOverviewHydrated(overview) {
  handlers.onOverviewHydrated(overview);
}

export async function toggleEntityVisibility(entityType, id, nextVisible, afterSuccess) {
  const client = getSupabase();
  if (!client) return;
  try {
    const { data, error } = await client.rpc('admin_set_content_visibility', {
      p_entity_type: entityType,
      p_id: id,
      p_is_visible: nextVisible,
    });
    if (error) throw error;
    showToast(nextVisible ? 'تم إظهار العنصر فوراً ✅' : 'تم إخفاء العنصر بأمان 👁️‍🗨️');
    broadcastWebControlPing('ALL');
    if (data?.cms_version) {
      const pill = document.getElementById('topbar-cms-ver');
      if (pill) pill.textContent = `#${data.cms_version}`;
    }
    await Promise.all([afterSuccess?.(), refreshOverview(), refreshAudit()]);
  } catch (err) {
    showToast(`تعذر تغيير حالة الظهور: ${err.message}`, true);
    await afterSuccess?.();
  }
}
