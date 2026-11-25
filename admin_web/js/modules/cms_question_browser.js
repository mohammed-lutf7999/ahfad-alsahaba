import { refreshAudit, refreshOverview, toggleEntityVisibility } from '../core/app_bus.js';
import { broadcastWebControlPing } from '../core/rest_broadcast.js';
import { getSupabase } from '../core/supabase_client.js';
import { escapeHtml, showToast } from '../core/ui_utils.js';
import {
  buildQuestionBrowserTemplate,
  renderBrowserQuestionsHtml,
  renderHiddenLocalIdsHtml,
} from './cms_question_browser_view.js';

const state = {
  mounted: false,
  busy: false,
  categories: [],
  questions: [],
  hiddenLocalIds: [],
  selectedIds: new Set(),
  page: 1,
  pageSize: 25,
  totalCount: 0,
  packNeedsRepublish: false,
  onMutated: null,
  onJumpToPublish: null,
};

function updateSelectionBadge() {
  const el = document.getElementById('qb-selected-count');
  if (el) el.textContent = `المحدد: ${state.selectedIds.size}`;
}

function renderListAndFooter() {
  const listEl = document.getElementById('qb-list');
  const totalEl = document.getElementById('qb-total-badge');
  const pageInfo = document.getElementById('qb-page-info');
  const prevBtn = document.getElementById('btn-qb-prev');
  const nextBtn = document.getElementById('btn-qb-next');
  const banner = document.getElementById('qb-republish-banner');
  const localList = document.getElementById('qb-local-list');
  const localCount = document.getElementById('qb-local-count');

  const totalPages = Math.max(1, Math.ceil(state.totalCount / state.pageSize));
  if (totalEl) totalEl.textContent = `${state.totalCount} سؤال`;
  if (pageInfo) pageInfo.textContent = `صفحة ${state.page} من ${totalPages} (إجمالي ${state.totalCount})`;
  if (prevBtn) prevBtn.disabled = state.busy || state.page <= 1;
  if (nextBtn) nextBtn.disabled = state.busy || state.page >= totalPages;
  banner?.classList.toggle('hidden', !state.packNeedsRepublish);

  if (listEl) listEl.innerHTML = renderBrowserQuestionsHtml(state.questions, state.selectedIds);
  if (localList) localList.innerHTML = renderHiddenLocalIdsHtml(state.hiddenLocalIds);
  if (localCount) localCount.textContent = String(state.hiddenLocalIds.length);
  updateSelectionBadge();
}

export function syncQuestionBrowserCategories(categories) {
  state.categories = Array.isArray(categories) ? categories : [];
  const sel = document.getElementById('qb-filter-cat');
  if (!sel) return;
  const prev = sel.value;
  sel.innerHTML = state.categories
    .map((c) => `<option value="${escapeHtml(c.id)}">${escapeHtml(c.name)} (${escapeHtml(c.id)})</option>`)
    .join('');
  if (prev && state.categories.some((c) => c.id === prev)) {
    sel.value = prev;
  } else if (state.categories.length > 0) {
    sel.value = state.categories[0].id;
  }
}

export async function loadQuestionBrowser({ resetPage = false } = {}) {
  const client = getSupabase();
  if (!client || !state.mounted) return;
  if (resetPage) {
    state.page = 1;
    state.selectedIds.clear();
  }
  const catId = document.getElementById('qb-filter-cat')?.value || null;
  const lvlRaw = document.getElementById('qb-filter-level')?.value.trim();
  const lvl = lvlRaw ? Number.parseInt(lvlRaw, 10) : null;
  const vis = document.getElementById('qb-filter-vis')?.value || 'all';
  const search = document.getElementById('qb-filter-search')?.value.trim() || null;

  state.busy = true;
  try {
    const { data, error } = await client.rpc('admin_browse_quiz_questions', {
      p_category_id: catId || null,
      p_level_number: Number.isFinite(lvl) ? lvl : null,
      p_visibility: vis,
      p_search: search,
      p_page: state.page,
      p_page_size: state.pageSize,
    });
    if (error) throw error;
    state.questions = Array.isArray(data?.questions) ? data.questions : [];
    state.totalCount = Number(data?.total_count || 0);
    state.packNeedsRepublish = Boolean(data?.pack_needs_republish);
    state.hiddenLocalIds = Array.isArray(data?.hidden_local_question_ids)
      ? data.hidden_local_question_ids
      : [];
    renderListAndFooter();
  } catch (err) {
    showToast(`تعذر تحميل متصفح الأسئلة: ${err?.message || err}`, true);
  } finally {
    state.busy = false;
    renderListAndFooter();
  }
}

async function handleDeleteSingle(questionId) {
  if (!window.confirm('هل أنت متأكد من الحذف النهائي لهذا السؤال السحابي؟ لا يمكن التراجع.')) {
    return;
  }
  const client = getSupabase();
  if (!client) return;
  try {
    const { error } = await client.rpc('admin_delete_quiz_question', {
      p_question_id: questionId,
    });
    if (error) throw error;
    state.selectedIds.delete(questionId);
    showToast('تم حذف السؤال بنجاح ✅');
    broadcastWebControlPing('ALL');
    await Promise.all([loadQuestionBrowser(), state.onMutated?.(), refreshOverview(), refreshAudit()]);
  } catch (err) {
    showToast(`فشل حذف السؤال: ${err?.message || err}`, true);
  }
}

async function handleRunBulkAction() {
  const client = getSupabase();
  if (!client || state.busy) return;
  const catId = document.getElementById('qb-filter-cat')?.value;
  if (!catId) return showToast('اختر القسم أولاً قبل تنفيذ إجراء جماعي.', true);

  const action = document.getElementById('qb-bulk-action').value;
  const fromRaw = document.getElementById('qb-bulk-from').value.trim();
  const toRaw = document.getElementById('qb-bulk-to').value.trim();
  const fromLv = fromRaw ? Number.parseInt(fromRaw, 10) : null;
  const toLv = toRaw ? Number.parseInt(toRaw, 10) : null;
  const targetLv = Number.parseInt(document.getElementById('qb-bulk-target-level').value || '1', 10);
  const ids = Array.from(state.selectedIds);

  const hasValidRange = Number.isFinite(fromLv) && Number.isFinite(toLv) && fromLv >= 1 && toLv >= fromLv;
  if (ids.length === 0 && !hasValidRange) {
    return showToast('يجب تحديد سؤال واحد على الأقل أو إدخال نطاق مستويات صالح (من <= إلى).', true);
  }

  const scopeDesc = ids.length > 0 ? `${ids.length} سؤال محدد` : `المستويات ${fromLv}..${toLv} في القسم ${catId}`;
  if (action === 'delete') {
    if (!window.confirm(`⚠️ تأكيد الحذف الجماعي النهائي لـ (${scopeDesc})؟ لا يمكن التراجع عن هذا الإجراء.`)) {
      return;
    }
  } else if (!window.confirm(`تأكيد تنفيذ (${action}) على ${scopeDesc}؟`)) {
    return;
  }

  state.busy = true;
  try {
    const { data, error } = await client.rpc('admin_bulk_manage_questions', {
      p_category_id: catId,
      p_action: action,
      p_question_ids: ids.length > 0 ? ids : null,
      p_from_level: ids.length === 0 ? fromLv : null,
      p_to_level: ids.length === 0 ? toLv : null,
      p_target_level: action === 'move_level' ? targetLv : null,
    });
    if (error) throw error;
    state.selectedIds.clear();
    showToast(`تم تنفيذ الإجراء الجماعي (${action}) على ${data?.affected_count ?? 0} سؤالاً ✅`);
    broadcastWebControlPing('ALL');
    await Promise.all([loadQuestionBrowser(), state.onMutated?.(), refreshOverview(), refreshAudit()]);
  } catch (err) {
    showToast(`فشل الإجراء الجماعي: ${err?.message || err}`, true);
  } finally {
    state.busy = false;
    renderListAndFooter();
  }
}

async function toggleLocalHidden(questionId, hide) {
  const client = getSupabase();
  const catId = document.getElementById('qb-filter-cat')?.value;
  if (!client || !catId || !questionId) return;
  try {
    const { error } = await client.rpc('admin_toggle_hidden_local_question', {
      p_category_id: catId,
      p_question_id: questionId,
      p_hide: Boolean(hide),
    });
    if (error) throw error;
    showToast(hide ? `تم إخفاء السؤال المحلي (${questionId}) ✅` : `تم إظهار السؤال المحلي (${questionId}) ✅`);
    broadcastWebControlPing('ALL');
    await Promise.all([loadQuestionBrowser(), state.onMutated?.(), refreshAudit()]);
  } catch (err) {
    showToast(`تعذر تحديث السؤال المحلي: ${err?.message || err}`, true);
  }
}

export function mountQuestionBrowser(container, { onMutated, onJumpToPublish } = {}) {
  if (state.mounted || !container) return;
  state.onMutated = onMutated || null;
  state.onJumpToPublish = onJumpToPublish || null;
  container.innerHTML = buildQuestionBrowserTemplate();
  state.mounted = true;

  document.getElementById('btn-qb-search').addEventListener('click', () => loadQuestionBrowser({ resetPage: true }));
  document.getElementById('qb-filter-cat').addEventListener('change', () => loadQuestionBrowser({ resetPage: true }));
  document.getElementById('qb-filter-vis').addEventListener('change', () => loadQuestionBrowser({ resetPage: true }));
  document.getElementById('qb-bulk-action').addEventListener('change', (e) => {
    document.getElementById('qb-target-level-wrap').classList.toggle('hidden', e.target.value !== 'move_level');
  });
  document.getElementById('btn-qb-select-all').addEventListener('click', () => {
    state.questions.forEach((q) => state.selectedIds.add(q.id));
    renderListAndFooter();
  });
  document.getElementById('btn-qb-clear-sel').addEventListener('click', () => {
    state.selectedIds.clear();
    renderListAndFooter();
  });
  document.getElementById('btn-qb-run-bulk').addEventListener('click', handleRunBulkAction);
  document.getElementById('btn-qb-prev').addEventListener('click', () => {
    if (state.page > 1) {
      state.page -= 1;
      loadQuestionBrowser();
    }
  });
  document.getElementById('btn-qb-next').addEventListener('click', () => {
    const totalPages = Math.max(1, Math.ceil(state.totalCount / state.pageSize));
    if (state.page < totalPages) {
      state.page += 1;
      loadQuestionBrowser();
    }
  });
  document.getElementById('btn-qb-jump-publish').addEventListener('click', () => {
    state.onJumpToPublish?.(document.getElementById('qb-filter-cat')?.value || '');
  });

  document.getElementById('qb-list').addEventListener('change', (e) => {
    const cb = e.target.closest('input[data-qb-select]');
    if (!cb) return;
    if (cb.checked) state.selectedIds.add(cb.dataset.qbSelect);
    else state.selectedIds.delete(cb.dataset.qbSelect);
    updateSelectionBadge();
  });

  document.getElementById('qb-list').addEventListener('click', (e) => {
    const delBtn = e.target.closest('button[data-qb-delete]');
    if (delBtn) return handleDeleteSingle(delBtn.dataset.qbDelete);
    const togBtn = e.target.closest('button[data-qb-toggle]');
    if (togBtn) {
      const nextVis = togBtn.dataset.qbNext === 'true';
      toggleEntityVisibility('quiz_question', togBtn.dataset.qbToggle, nextVis, () => loadQuestionBrowser());
    }
  });

  document.getElementById('qb-local-hide-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const input = document.getElementById('qb-local-id');
    const qid = input.value.trim();
    if (!qid) return;
    await toggleLocalHidden(qid, true);
    input.value = '';
  });

  document.getElementById('qb-local-list').addEventListener('click', (e) => {
    const btn = e.target.closest('button[data-qb-unhide-local]');
    if (btn) toggleLocalHidden(btn.dataset.qbUnhideLocal, false);
  });
}
