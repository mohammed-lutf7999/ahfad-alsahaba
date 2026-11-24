import { registerAppBus } from './core/app_bus.js';
import { initAuth, logout } from './core/auth.js';
import { adminState } from './core/supabase_client.js';
import { showToast } from './core/ui_utils.js';
import { loadOverview } from './modules/overview_bar.js';

const TAB_LOADERS = {
  release: () => import('./modules/tab_release.js'),
  announcements: () => import('./modules/tab_announcements.js'),
  events: () => import('./modules/tab_events.js'),
  store: () => import('./modules/tab_cms_store.js'),
  content: () => import('./modules/tab_content_hub.js'),
  players: () => import('./modules/tab_players.js'),
  telemetry: () => import('./modules/tab_telemetry.js'),
  moderation: () => import('./modules/tab_moderation.js'),
};

const loadedModules = new Map();
const loadedDataTabs = new Set();
let activeTab = 'release';

async function ensureTabMounted(tabName) {
  const loader = TAB_LOADERS[tabName];
  const container = document.getElementById(`tab-${tabName}`);
  if (!loader || !container) return null;

  let mod = loadedModules.get(tabName);
  if (!mod) {
    mod = await loader();
    loadedModules.set(tabName, mod);
  }
  mod.mount(container);
  return mod;
}

async function activateTab(tabName, { forceReload = false } = {}) {
  const targetBtn = document.querySelector(`.tab-btn[data-tab="${tabName}"]`);
  const targetPanel = document.getElementById(`tab-${tabName}`);
  if (!targetBtn || !targetPanel) return null;

  document.querySelectorAll('.tab-btn').forEach((b) => b.classList.remove('active'));
  document.querySelectorAll('.tab-panel').forEach((p) => p.classList.remove('active'));
  targetBtn.classList.add('active');
  targetPanel.classList.add('active');
  activeTab = tabName;

  try {
    const mod = await ensureTabMounted(tabName);
    if (!mod) return null;
    if (adminState.isAdmin && (forceReload || !loadedDataTabs.has(tabName))) {
      loadedDataTabs.add(tabName);
      await mod.load?.();
    }
    return mod;
  } catch (err) {
    showToast(`تعذر تحميل وحدة التبويب (${tabName}): ${err?.message || err}`, true);
    return null;
  }
}

async function refreshAllDashboard() {
  loadedDataTabs.clear();
  await loadOverview();
  await activateTab(activeTab, { forceReload: true });
}

async function refreshAuditIfMounted() {
  const telemetryMod = loadedModules.get('telemetry');
  if (telemetryMod && loadedDataTabs.has('telemetry')) {
    await telemetryMod.loadAuditLogs?.();
  } else {
    loadedDataTabs.delete('telemetry');
  }
}

async function selectPlayerInAnnouncements(playerObj) {
  const mod = await activateTab('announcements');
  mod?.selectPlayer?.(playerObj);
}

function handleOverviewHydrated(ov) {
  const releaseMod = loadedModules.get('release');
  if (releaseMod && ov?.release_config) {
    releaseMod.hydrateReleaseForm?.(ov.release_config);
  }
}

async function handleLogout() {
  loadedDataTabs.clear();
  await logout();
}

function bindShellListeners() {
  document.getElementById('btn-logout').addEventListener('click', handleLogout);
  document.getElementById('btn-refresh-all').addEventListener('click', refreshAllDashboard);

  document.querySelectorAll('.tab-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      activateTab(btn.dataset.tab);
    });
  });
}

async function boot() {
  registerAppBus({
    refreshOverview: loadOverview,
    refreshAudit: refreshAuditIfMounted,
    switchToTab: (tabName) => activateTab(tabName),
    selectPlayerForAnnouncement: selectPlayerInAnnouncements,
    onOverviewHydrated: handleOverviewHydrated,
  });

  bindShellListeners();
  await ensureTabMounted(activeTab);
  await initAuth(refreshAllDashboard);
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', boot);
} else {
  boot();
}
