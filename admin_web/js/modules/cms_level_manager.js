import { refreshAudit, refreshOverview } from '../core/app_bus.js';
import { broadcastWebControlPing } from '../core/rest_broadcast.js';
import { getSupabase } from '../core/supabase_client.js';
import { escapeHtml, showToast } from '../core/ui_utils.js';
import { buildLevelManagerTemplate, renderLevelGridHtml } from './cms_level_manager_view.js';

const state = {
  mounted: false,
  busy: false,
  categories: [],
  selectedCatId: '',
  onMutated: null,
  onJumpToPublish: null,
};

function computeNeedsRepublish(cat) {
  if (!cat || Number(cat.pack_version || 0) <= 0) return false;
  if (!cat.questions_updated_at) return false;
  if (!cat.pack_published_at) return true;
  return new Date(cat.questions_updated_at).getTime() > new Date(cat.pack_published_at).getTime();
}

function getSelectedCategory() {
  return state.categories.find((c) => c.id === state.selectedCatId) || state.categories[0] || null;
}

function setBusy(busy) {
  state.busy = Boolean(busy);
  const saveBtn = document.getElementById('btn-lvl-save-cat');
  const rangeBtn = document.getElementById('btn-lvl-apply-range');
  if (saveBtn) saveBtn.disabled = state.busy;
  if (rangeBtn) rangeBtn.disabled = state.busy;
}

function renderSelectedCategory() {
  if (!state.mounted) return;
  const cat = getSelectedCategory();
  const gridEl = document.getElementById('lvl-mgr-grid');
  const summaryEl = document.getElementById('lvl-mgr-summary');
  const hintEl = document.getElementById('lvl-mgr-range-hint');
  const bannerEl = document.getElementById('lvl-mgr-republish-banner');
  if (!gridEl) return;

  if (!cat) {
    gridEl.innerHTML = renderLevelGridHtml(null);
    if (summaryEl) summaryEl.textContent = '0 مستوى';
    bannerEl?.classList.add('hidden');
    return;
  }

  state.selectedCatId = cat.id;
  const total = Math.max(1, Math.min(100, Number(cat.total_levels || 10)));
  const status = cat.availability_status || (cat.is_visible === false ? 'hidden' : 'open');

  document.getElementById('lvl-mgr-cat-status').value = status;
  document.getElementById('lvl-mgr-cat-msg').value = cat.coming_soon_message || '';
  document.getElementById('lvl-mgr-from').max = String(total);
  document.getElementById('lvl-mgr-to').max = String(total);
  if (Number(document.getElementById('lvl-mgr-to').value) > total) {
    document.getElementById('lvl-mgr-to').value = String(total);
  }
  if (hintEl) hintEl.textContent = `1..${total}`;

  const overrides = cat.level_overrides && typeof cat.level_overrides === 'object' ? cat.level_overrides : {};
  let csCount = 0;
  let hidCount = 0;
  Object.values(overrides).forEach((ov) => {
    if (ov?.status === 'coming_soon') csCount += 1;
    else if (ov?.status === 'hidden') hidCount += 1;
  });
  if (summaryEl) {
    summaryEl.textContent = `${total} مستوى • ⏳ ${csCount} • 🚫 ${hidCount}`;
  }

  bannerEl?.classList.toggle('hidden', !computeNeedsRepublish(cat));
  gridEl.innerHTML = renderLevelGridHtml(cat);
}

export function syncLevelManagerCategories(categories) {
  state.categories = Array.isArray(categories) ? categories : [];
  const sel = document.getElementById('lvl-mgr-cat');
  if (!sel) return;
  const prev = state.selectedCatId || sel.value;
  sel.innerHTML = state.categories
    .map((c) => {
      const tag = c.availability_status === 'coming_soon'
        ? ' ⏳'
        : c.availability_status === 'hidden' || c.is_visible === false
          ? ' 🚫'
          : '';
      return `<option value="${escapeHtml(c.id)}">${escapeHtml(c.name)}${tag} (${escapeHtml(c.id)})</option>`;
    })
    .join('');
  if (prev && state.categories.some((c) => c.id === prev)) {
    sel.value = prev;
    state.selectedCatId = prev;
  } else if (state.categories.length > 0) {
    sel.value = state.categories[0].id;
    state.selectedCatId = state.categories[0].id;
  }
  renderSelectedCategory();
}

async function handleSaveCategoryAvailability(e) {
  e.preventDefault();
  if (state.busy) return;
  const client = getSupabase();
  const cat = getSelectedCategory();
  if (!client || !cat) return;

  const status = document.getElementById('lvl-mgr-cat-status').value;
  const message = document.getElementById('lvl-mgr-cat-msg').value.trim();

  setBusy(true);
  try {
    const { error } = await client.rpc('admin_upsert_category_availability', {
      p_category_id: cat.id,
      p_availability_status: status,
      p_coming_soon_message: message,
    });
    if (error) throw error;
    showToast(`تم تحديث حالة قسم «${cat.name}» بنجاح ✅`);
    broadcastWebControlPing('ALL');
    await Promise.all([state.onMutated?.(), refreshOverview(), refreshAudit()]);
  } catch (err) {
    showToast(`تعذر تحديث حالة القسم: ${err?.message || err}`, true);
  } finally {
    setBusy(false);
  }
}

async function applyLevelRangeOverride(catId, fromLevel, toLevel, status, message) {
  const client = getSupabase();
  if (!client || !catId) return;
  setBusy(true);
  try {
    const { error } = await client.rpc('admin_bulk_set_level_overrides', {
      p_category_id: catId,
      p_from_level: fromLevel,
      p_to_level: toLevel,
      p_status: status,
      p_message: message || '',
    });
    if (error) throw error;
    showToast(`تم تحديث المستويات ${fromLevel}..${toLevel} ← (${status}) ✅`);
    broadcastWebControlPing('ALL');
    await Promise.all([state.onMutated?.(), refreshAudit()]);
  } catch (err) {
    showToast(`تعذر تحديث المستويات: ${err?.message || err}`, true);
  } finally {
    setBusy(false);
  }
}

async function handleApplyRange(e) {
  e.preventDefault();
  if (state.busy) return;
  const cat = getSelectedCategory();
  if (!cat) return;
  const fromLv = Number.parseInt(document.getElementById('lvl-mgr-from').value || '1', 10);
  const toLv = Number.parseInt(document.getElementById('lvl-mgr-to').value || '1', 10);
  const status = document.getElementById('lvl-mgr-range-status').value;
  const message = document.getElementById('lvl-mgr-range-msg').value.trim();
  if (!Number.isFinite(fromLv) || !Number.isFinite(toLv) || fromLv < 1 || toLv < fromLv) {
    return showToast('يرجى إدخال نطاق مستويات صحيح (من <= إلى).', true);
  }
  await applyLevelRangeOverride(cat.id, fromLv, toLv, status, message);
}

async function handleGridClick(e) {
  const btn = e.target.closest('button[data-level-num]');
  if (!btn || state.busy) return;
  const cat = getSelectedCategory();
  if (!cat) return;
  const lv = Number.parseInt(btn.dataset.levelNum, 10);
  const curr = btn.dataset.levelStatus || 'open';
  const next = curr === 'open' ? 'coming_soon' : curr === 'coming_soon' ? 'hidden' : 'open';
  const msg = document.getElementById('lvl-mgr-range-msg')?.value.trim() || '';
  await applyLevelRangeOverride(cat.id, lv, lv, next, next === 'coming_soon' ? msg : '');
}

export function mountLevelManager(container, { onMutated, onJumpToPublish } = {}) {
  if (state.mounted || !container) return;
  state.onMutated = onMutated || null;
  state.onJumpToPublish = onJumpToPublish || null;
  container.innerHTML = buildLevelManagerTemplate();
  state.mounted = true;

  document.getElementById('lvl-mgr-cat').addEventListener('change', (e) => {
    state.selectedCatId = e.target.value;
    renderSelectedCategory();
  });
  document.getElementById('lvl-mgr-cat-form').addEventListener('submit', handleSaveCategoryAvailability);
  document.getElementById('lvl-mgr-range-form').addEventListener('submit', handleApplyRange);
  document.getElementById('lvl-mgr-grid').addEventListener('click', handleGridClick);
  document.getElementById('btn-lvl-jump-publish').addEventListener('click', () => {
    state.onJumpToPublish?.(state.selectedCatId);
  });
}
