import { refreshAudit, refreshOverview, toggleEntityVisibility } from '../core/app_bus.js';
import { broadcastWebControlPing } from '../core/rest_broadcast.js';
import { getSupabase } from '../core/supabase_client.js';
import { escapeHtml, safeHexColor, showToast } from '../core/ui_utils.js';
import {
  buildLibraryTemplate,
  renderLibraryItemsHtml,
  renderLibrarySectionsHtml,
} from './cms_library_view.js';

const state = { mounted: false, sections: [], items: [] };

function populateSelects() {
  const itemSecSel = document.getElementById('lib-item-section');
  const filterSel = document.getElementById('lib-filter-section');
  if (!itemSecSel || !filterSel) return;

  const prevItemSec = itemSecSel.value;
  const prevFilter = filterSel.value;

  itemSecSel.innerHTML = state.sections
    .map((s) => `<option value="${escapeHtml(s.id)}">${escapeHtml(s.title)} (${escapeHtml(s.id)})</option>`)
    .join('');
  if (prevItemSec && state.sections.some((s) => s.id === prevItemSec)) {
    itemSecSel.value = prevItemSec;
  }

  filterSel.innerHTML =
    '<option value="">كل الأقسام</option>' +
    state.sections.map((s) => `<option value="${escapeHtml(s.id)}">${escapeHtml(s.title)}</option>`).join('');
  filterSel.value = prevFilter;
}

function renderSections() {
  const listEl = document.getElementById('lib-sections-list');
  document.getElementById('lib-sec-count').textContent = state.sections.length;
  listEl.innerHTML = renderLibrarySectionsHtml(state.sections);

  listEl.querySelectorAll('button[data-edit-lib-sec]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const sec = state.sections.find((s) => s.id === btn.dataset.editLibSec);
      if (!sec) return;
      document.getElementById('lib-sec-id').value = sec.id;
      document.getElementById('lib-sec-id').readOnly = true;
      document.getElementById('lib-sec-title').value = sec.title ?? '';
      document.getElementById('lib-sec-icon').value = sec.icon_name ?? 'auto_stories_rounded';
      const hex = safeHexColor(sec.color_hex, '#D4AF37');
      document.getElementById('lib-sec-color').value = hex;
      document.getElementById('lib-sec-color-picker').value = hex.toLowerCase();
      document.getElementById('lib-sec-sort').value = sec.sort_order ?? 10;
      document.getElementById('lib-sec-visible').checked = sec.is_visible !== false;
      document.getElementById('lib-sec-heading').textContent = `✏️ تعديل قسم: ${sec.title}`;
    });
  });

  listEl.querySelectorAll('input[data-vis-lib-sec]').forEach((input) => {
    input.addEventListener('change', () => {
      toggleEntityVisibility('library_section', input.dataset.visLibSec, input.checked, loadLibraryContent);
    });
  });
}

function renderItems() {
  const listEl = document.getElementById('lib-items-list');
  listEl.innerHTML = renderLibraryItemsHtml(state.items);

  listEl.querySelectorAll('button[data-edit-lib-item]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const item = state.items.find((i) => i.id === btn.dataset.editLibItem);
      if (!item) return;
      document.getElementById('lib-item-id').value = item.id;
      document.getElementById('lib-item-section').value = item.section_id ?? '';
      document.getElementById('lib-item-title').value = item.title ?? '';
      document.getElementById('lib-item-subtitle').value = item.subtitle ?? '';
      document.getElementById('lib-item-content').value = item.content ?? '';
      document.getElementById('lib-item-source').value = item.source_ref ?? '';
      document.getElementById('lib-item-sort').value = item.sort_order ?? 10;
      document.getElementById('lib-item-visible').checked = item.is_visible !== false;
      document.getElementById('lib-item-heading').textContent = `✏️ تعديل بطاقة: ${item.title}`;
    });
  });

  listEl.querySelectorAll('input[data-vis-lib-item]').forEach((input) => {
    input.addEventListener('change', () => {
      toggleEntityVisibility('library_item', input.dataset.visLibItem, input.checked, loadLibraryContent);
    });
  });
}

function resetSectionForm() {
  document.getElementById('lib-section-form').reset();
  document.getElementById('lib-sec-id').readOnly = false;
  document.getElementById('lib-sec-visible').checked = true;
  document.getElementById('lib-sec-heading').textContent = '🗂️ قسم مكتبة (إضافة / تعديل)';
}

function resetItemForm() {
  document.getElementById('lib-item-form').reset();
  document.getElementById('lib-item-id').value = '';
  document.getElementById('lib-item-visible').checked = true;
  document.getElementById('lib-item-heading').textContent = '📝 مقال / قصة / بطاقة معرفة';
}

async function handleSaveSection(e) {
  e.preventDefault();
  const client = getSupabase();
  if (!client) return;
  const btn = document.getElementById('btn-save-lib-sec');
  btn.disabled = true;
  try {
    const { error } = await client.rpc('admin_upsert_library_section', {
      p_id: document.getElementById('lib-sec-id').value.trim().toLowerCase(),
      p_title: document.getElementById('lib-sec-title').value.trim(),
      p_icon_name: document.getElementById('lib-sec-icon').value,
      p_color_hex: safeHexColor(document.getElementById('lib-sec-color').value),
      p_sort_order: Number.parseInt(document.getElementById('lib-sec-sort').value || '10', 10) || 10,
      p_is_visible: document.getElementById('lib-sec-visible').checked,
    });
    if (error) throw error;
    showToast('تم حفظ قسم المكتبة ✅');
    broadcastWebControlPing('ALL');
    resetSectionForm();
    await Promise.all([loadLibraryContent(), refreshOverview(), refreshAudit()]);
  } catch (err) {
    showToast(`فشل حفظ القسم: ${err.message}`, true);
  } finally {
    btn.disabled = false;
  }
}

async function handleSaveItem(e) {
  e.preventDefault();
  const client = getSupabase();
  if (!client) return;
  const btn = document.getElementById('btn-save-lib-item');
  btn.disabled = true;
  try {
    const idRaw = document.getElementById('lib-item-id').value.trim();
    const { error } = await client.rpc('admin_upsert_library_item', {
      p_id: idRaw || null,
      p_section_id: document.getElementById('lib-item-section').value,
      p_title: document.getElementById('lib-item-title').value.trim(),
      p_subtitle: document.getElementById('lib-item-subtitle').value.trim(),
      p_content: document.getElementById('lib-item-content').value.trim(),
      p_source_ref: document.getElementById('lib-item-source').value.trim(),
      p_sort_order: Number.parseInt(document.getElementById('lib-item-sort').value || '10', 10) || 10,
      p_is_visible: document.getElementById('lib-item-visible').checked,
    });
    if (error) throw error;
    showToast('تم حفظ عنصر المكتبة ✅');
    broadcastWebControlPing('ALL');
    resetItemForm();
    await Promise.all([loadLibraryContent(), refreshOverview(), refreshAudit()]);
  } catch (err) {
    showToast(`فشل حفظ العنصر: ${err.message}`, true);
  } finally {
    btn.disabled = false;
  }
}

export function mountLibrary(container) {
  if (state.mounted || !container) return;
  container.innerHTML = buildLibraryTemplate();
  state.mounted = true;

  document.getElementById('lib-section-form').addEventListener('submit', handleSaveSection);
  document.getElementById('lib-item-form').addEventListener('submit', handleSaveItem);
  document.getElementById('lib-filter-section').addEventListener('change', loadLibraryContent);
  document.getElementById('btn-reset-lib-sec').addEventListener('click', resetSectionForm);
  document.getElementById('btn-reset-lib-item').addEventListener('click', resetItemForm);
  document.getElementById('lib-sec-color-picker').addEventListener('input', (e) => {
    document.getElementById('lib-sec-color').value = e.target.value.toUpperCase();
  });
}

export async function loadLibraryContent() {
  const client = getSupabase();
  if (!client) return;
  const filterSec = document.getElementById('lib-filter-section')?.value || null;
  const { data, error } = await client.rpc('admin_list_library_content', { p_section_id: filterSec || null });
  if (error) {
    showToast(`تعذر تحميل المكتبة السحابية: ${error.message}`, true);
    return;
  }
  state.sections = Array.isArray(data?.sections) ? data.sections : [];
  state.items = Array.isArray(data?.items) ? data.items : [];
  populateSelects();
  renderSections();
  renderItems();
}
