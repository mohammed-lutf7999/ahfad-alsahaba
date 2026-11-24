import { refreshAudit, refreshOverview, toggleEntityVisibility } from '../core/app_bus.js';
import { broadcastWebControlPing } from '../core/rest_broadcast.js';
import { getSupabase } from '../core/supabase_client.js';
import { safeHexColor, showToast } from '../core/ui_utils.js';
import {
  buildStoreTemplate,
  renderStoreItemsHtml,
  renderStorePreviewHtml,
} from './tab_cms_store_view.js';

const PREVIEW_INPUT_IDS = [
  'st-title', 'st-desc', 'st-coins', 'st-gems', 'st-visible',
  'st-th-bg1', 'st-th-bg2', 'st-th-card', 'st-th-gold', 'st-th-sec',
  'st-fr-c1', 'st-fr-c2', 'st-fr-glow', 'st-fr-pattern', 'st-fr-gems', 'st-badge-color',
];

const state = { mounted: false, items: [], filter: 'all', editingId: null };

function collectMetadata(cat) {
  if (cat === 'theme') {
    const bg1 = safeHexColor(document.getElementById('st-th-bg1').value, '#1a0b2e').toUpperCase();
    const bg2 = safeHexColor(document.getElementById('st-th-bg2').value, '#2d1b4e').toUpperCase();
    const card = safeHexColor(document.getElementById('st-th-card').value, '#24143d').toUpperCase();
    const gold = safeHexColor(document.getElementById('st-th-gold').value, '#f3c644').toUpperCase();
    const sec = safeHexColor(document.getElementById('st-th-sec').value, '#38bdf8').toUpperCase();
    return {
      deepBackground: bg1, surfaceCard: card, sovereignAccent: gold, secondaryAccent: sec, previewColor: gold,
      bg_primary: bg1, bg_secondary: bg2, surface_card: card, accent_gold: gold, accent_secondary: sec,
    };
  }
  if (cat === 'frame') {
    const c1 = safeHexColor(document.getElementById('st-fr-c1').value, '#f3c644').toUpperCase();
    const c2 = safeHexColor(document.getElementById('st-fr-c2').value, '#10b981').toUpperCase();
    const glow = safeHexColor(document.getElementById('st-fr-glow').value, '#f3c644').toUpperCase();
    const pattern = document.getElementById('st-fr-pattern').value || 'aurora';
    const gems = document.getElementById('st-fr-gems').checked;
    return {
      primaryColor: c1, secondaryColor: c2, highlightColor: glow, previewColor: c2,
      hasCornerGems: gems, hasOctagonalStar: true, pattern_type: pattern,
    };
  }
  const qtyRaw = document.getElementById('st-powerup-qty').value.trim();
  const badgeHex = safeHexColor(document.getElementById('st-badge-color').value, '#f3c644').toUpperCase();
  const meta = { previewColor: badgeHex, sovereignAccent: badgeHex };
  if (qtyRaw && Number.isFinite(Number(qtyRaw))) {
    meta.quantity = Number.parseInt(qtyRaw, 10);
  }
  return meta;
}

function updatePreview() {
  const previewEl = document.getElementById('store-live-preview');
  if (!previewEl) return;
  const cat = document.getElementById('st-category').value;
  previewEl.innerHTML = renderStorePreviewHtml({
    cat,
    title: document.getElementById('st-title').value.trim() || 'اسم عنصر المتجر',
    desc: document.getElementById('st-desc').value.trim() || 'وصف عنصر سوق الفرسان يظهر هنا',
    coins: Number.parseInt(document.getElementById('st-coins').value || '0', 10) || 0,
    gems: Number.parseInt(document.getElementById('st-gems').value || '0', 10) || 0,
    visible: document.getElementById('st-visible').checked,
    meta: collectMetadata(cat),
  });
}

function syncMetadataPanels() {
  const cat = document.getElementById('st-category').value;
  document.getElementById('store-meta-theme').classList.toggle('hidden', cat !== 'theme');
  document.getElementById('store-meta-frame').classList.toggle('hidden', cat !== 'frame');
  document.getElementById('store-meta-badge').classList.toggle('hidden', cat !== 'title' && cat !== 'powerup');
  updatePreview();
}

function resetForm() {
  state.editingId = null;
  document.getElementById('store-cms-form').reset();
  document.getElementById('st-id').readOnly = false;
  document.getElementById('store-form-heading').textContent = '🛒 إضافة / تعديل عنصر متجر';
  document.getElementById('st-coins').value = '500';
  document.getElementById('st-gems').value = '0';
  document.getElementById('st-min-level').value = '1';
  document.getElementById('st-sort').value = '100';
  document.getElementById('st-visible').checked = true;
  syncMetadataPanels();
}

function populateForm(item) {
  state.editingId = item.id;
  document.getElementById('store-form-heading').textContent = `✏️ تعديل: ${item.title}`;
  const idInput = document.getElementById('st-id');
  idInput.value = item.id ?? '';
  idInput.readOnly = true;
  document.getElementById('st-category').value = item.category ?? 'title';
  document.getElementById('st-title').value = item.title ?? '';
  document.getElementById('st-desc').value = item.description ?? '';
  document.getElementById('st-coins').value = item.price_coins ?? 0;
  document.getElementById('st-gems').value = item.price_gems ?? 0;
  document.getElementById('st-min-level').value = item.min_level ?? 1;
  document.getElementById('st-asset-key').value = item.asset_key ?? '';
  document.getElementById('st-sort').value = item.sort_order ?? 100;
  document.getElementById('st-visible').checked = item.is_visible !== false;

  const meta = item.metadata && typeof item.metadata === 'object' ? item.metadata : {};
  if (item.category === 'theme') {
    document.getElementById('st-th-bg1').value = safeHexColor(meta.deepBackground ?? meta.bg_primary, '#1a0b2e').toLowerCase();
    document.getElementById('st-th-bg2').value = safeHexColor(meta.bg_secondary ?? meta.surfaceCard, '#2d1b4e').toLowerCase();
    document.getElementById('st-th-card').value = safeHexColor(meta.surfaceCard ?? meta.surface_card, '#24143d').toLowerCase();
    document.getElementById('st-th-gold').value = safeHexColor(meta.sovereignAccent ?? meta.accent_gold, '#f3c644').toLowerCase();
    document.getElementById('st-th-sec').value = safeHexColor(meta.secondaryAccent ?? meta.accent_secondary, '#38bdf8').toLowerCase();
  } else if (item.category === 'frame') {
    document.getElementById('st-fr-c1').value = safeHexColor(meta.primaryColor ?? meta.primary_color, '#f3c644').toLowerCase();
    document.getElementById('st-fr-c2').value = safeHexColor(meta.secondaryColor ?? meta.secondary_color, '#10b981').toLowerCase();
    document.getElementById('st-fr-glow').value = safeHexColor(meta.highlightColor ?? meta.glow_color, '#f3c644').toLowerCase();
    document.getElementById('st-fr-pattern').value = meta.pattern_type || 'aurora';
    document.getElementById('st-fr-gems').checked = (meta.hasCornerGems ?? meta.show_gems) !== false;
  } else {
    document.getElementById('st-badge-color').value = safeHexColor(
      meta.previewColor ?? meta.sovereignAccent ?? meta.accent_color,
      '#f3c644',
    ).toLowerCase();
    document.getElementById('st-powerup-qty').value = meta.quantity ?? '';
  }
  syncMetadataPanels();
}

function renderList() {
  const listEl = document.getElementById('store-items-list');
  const pillEl = document.getElementById('store-count-pill');
  if (!listEl || !pillEl) return;
  const filtered = state.filter === 'all' ? state.items : state.items.filter((it) => it.category === state.filter);
  pillEl.textContent = filtered.length;
  listEl.innerHTML = renderStoreItemsHtml(filtered);

  listEl.querySelectorAll('button[data-edit-store]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const found = state.items.find((i) => i.id === btn.dataset.editStore);
      if (found) populateForm(found);
    });
  });
  listEl.querySelectorAll('input[data-vis-store]').forEach((input) => {
    input.addEventListener('change', () => {
      toggleEntityVisibility('store_item', input.dataset.visStore, input.checked, load);
    });
  });
}

async function handleSave(e) {
  e.preventDefault();
  const client = getSupabase();
  if (!client) return;
  const id = document.getElementById('st-id').value.trim().toLowerCase();
  const category = document.getElementById('st-category').value;
  if (!/^[a-z0-9_]{3,64}$/.test(id)) {
    return showToast('معرّف العنصر يجب أن يحتوي 3..64 حرفاً إنجليزياً صغيراً أو أرقاماً أو _.', true);
  }

  const btn = document.getElementById('btn-save-store-item');
  btn.disabled = true;
  try {
    const { error } = await client.rpc('admin_upsert_store_item', {
      p_id: id,
      p_title: document.getElementById('st-title').value.trim(),
      p_description: document.getElementById('st-desc').value.trim(),
      p_category: category,
      p_price_coins: Number.parseInt(document.getElementById('st-coins').value || '0', 10) || 0,
      p_price_gems: Number.parseInt(document.getElementById('st-gems').value || '0', 10) || 0,
      p_min_level: Number.parseInt(document.getElementById('st-min-level').value || '1', 10) || 1,
      p_asset_key: document.getElementById('st-asset-key').value.trim(),
      p_is_visible: document.getElementById('st-visible').checked,
      p_sort_order: Number.parseInt(document.getElementById('st-sort').value || '100', 10) || 100,
      p_metadata: collectMetadata(category),
    });
    if (error) throw error;
    showToast('تم حفظ عنصر المتجر وتحديث الكتالوغ السحابي ✅');
    broadcastWebControlPing('ALL');
    resetForm();
    await Promise.all([load(), refreshOverview(), refreshAudit()]);
  } catch (err) {
    showToast(`فشل حفظ العنصر: ${err.message}`, true);
  } finally {
    btn.disabled = false;
  }
}

export function mount(container) {
  if (state.mounted || !container) return;
  container.innerHTML = buildStoreTemplate();
  state.mounted = true;

  document.getElementById('st-category').addEventListener('change', syncMetadataPanels);
  document.getElementById('btn-reset-store-form').addEventListener('click', resetForm);
  document.getElementById('store-cms-form').addEventListener('submit', handleSave);
  PREVIEW_INPUT_IDS.forEach((id) => {
    const el = document.getElementById(id);
    if (!el) return;
    el.addEventListener('input', updatePreview);
    el.addEventListener('change', updatePreview);
  });
  container.querySelectorAll('button[data-store-filter]').forEach((btn) => {
    btn.addEventListener('click', () => {
      container.querySelectorAll('button[data-store-filter]').forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');
      state.filter = btn.dataset.storeFilter;
      renderList();
    });
  });
  syncMetadataPanels();
}

export async function load() {
  const client = getSupabase();
  if (!client) return;
  const { data, error } = await client.rpc('admin_list_store_items');
  if (error) {
    showToast(`تعذر تحميل عناصر المتجر: ${error.message}`, true);
    return;
  }
  state.items = Array.isArray(data) ? data : [];
  renderList();
}
