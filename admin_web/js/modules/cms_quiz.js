import { refreshAudit, refreshOverview, toggleEntityVisibility } from '../core/app_bus.js';
import { broadcastWebControlPing } from '../core/rest_broadcast.js';
import { getSupabase } from '../core/supabase_client.js';
import { escapeHtml, safeHexColor, showToast } from '../core/ui_utils.js';
import {
  mountBulkImporter,
  refreshBulkActiveConfig,
  syncBulkCategories,
} from './bulk_json_importer.js';
import {
  buildQuizTemplate,
  renderQuizCategoriesHtml,
  renderQuizQuestionsHtml,
} from './cms_quiz_view.js';

const state = { mounted: false, categories: [], questions: [] };

function populateSelects() {
  const qCatSel = document.getElementById('qz-q-cat');
  const filterSel = document.getElementById('quiz-filter-cat');
  if (!qCatSel || !filterSel) return;

  const prevQCat = qCatSel.value;
  const prevFilter = filterSel.value;

  qCatSel.innerHTML = state.categories
    .map((c) => `<option value="${escapeHtml(c.id)}">${escapeHtml(c.name)} (${escapeHtml(c.total_levels ?? 10)} مراحل)</option>`)
    .join('');
  if (prevQCat && state.categories.some((c) => c.id === prevQCat)) {
    qCatSel.value = prevQCat;
  }

  filterSel.innerHTML =
    '<option value="">كل الأقسام</option>' +
    state.categories.map((c) => `<option value="${escapeHtml(c.id)}">${escapeHtml(c.name)}</option>`).join('');
  filterSel.value = prevFilter;

  syncBulkCategories(state.categories);
}

function renderCategories() {
  const listEl = document.getElementById('quiz-categories-list');
  document.getElementById('quiz-cat-count').textContent = state.categories.length;
  listEl.innerHTML = renderQuizCategoriesHtml(state.categories);

  listEl.querySelectorAll('button[data-edit-qz-cat]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const cat = state.categories.find((c) => c.id === btn.dataset.editQzCat);
      if (!cat) return;
      document.getElementById('qz-cat-id').value = cat.id;
      document.getElementById('qz-cat-id').readOnly = true;
      document.getElementById('qz-cat-name').value = cat.name ?? '';
      document.getElementById('qz-cat-desc').value = cat.description ?? '';
      document.getElementById('qz-cat-levels').value = cat.total_levels ?? 10;
      document.getElementById('qz-cat-icon').value = cat.icon_name ?? 'quiz_rounded';
      const hex = safeHexColor(cat.color_hex, '#1B5E20');
      document.getElementById('qz-cat-color').value = hex;
      document.getElementById('qz-cat-color-picker').value = hex.toLowerCase();
      document.getElementById('qz-cat-sort').value = cat.sort_order ?? 10;
      document.getElementById('qz-cat-visible').checked = cat.is_visible !== false;
      document.getElementById('qz-cat-locked').checked = Boolean(cat.is_locked);
      document.getElementById('quiz-cat-heading').textContent = `✏️ تعديل قسم: ${cat.name}`;
    });
  });

  listEl.querySelectorAll('input[data-vis-qz-cat]').forEach((input) => {
    input.addEventListener('change', () => {
      toggleEntityVisibility('quiz_category', input.dataset.visQzCat, input.checked, loadQuizContent);
    });
  });
}

function renderQuestions() {
  const listEl = document.getElementById('quiz-questions-list');
  listEl.innerHTML = renderQuizQuestionsHtml(state.questions);

  listEl.querySelectorAll('button[data-edit-qz-q]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const q = state.questions.find((item) => item.id === btn.dataset.editQzQ);
      if (!q) return;
      const opts = Array.isArray(q.options) ? q.options : ['', '', '', ''];
      document.getElementById('qz-q-id').value = q.id;
      document.getElementById('qz-q-cat').value = q.category_id ?? 'quran';
      document.getElementById('qz-q-level').value = q.level_number ?? 1;
      document.getElementById('qz-q-scope').value = q.sync_scope || 'solo_only';
      document.getElementById('qz-q-text').value = q.question_text ?? '';
      document.getElementById('qz-opt-0').value = opts[0] ?? '';
      document.getElementById('qz-opt-1').value = opts[1] ?? '';
      document.getElementById('qz-opt-2').value = opts[2] ?? '';
      document.getElementById('qz-opt-3').value = opts[3] ?? '';
      document.getElementById('qz-q-correct').value = String(q.correct_index ?? 0);
      document.getElementById('qz-q-sort').value = q.sort_order ?? 10;
      document.getElementById('qz-q-exp').value = q.explanation ?? '';
      document.getElementById('qz-q-visible').checked = q.is_visible !== false;
      document.getElementById('quiz-q-heading').textContent = '✏️ تعديل سؤال سحابي';
    });
  });

  listEl.querySelectorAll('input[data-vis-qz-q]').forEach((input) => {
    input.addEventListener('change', () => {
      toggleEntityVisibility('quiz_question', input.dataset.visQzQ, input.checked, loadQuizContent);
    });
  });
}

function resetCategoryForm() {
  document.getElementById('quiz-category-form').reset();
  document.getElementById('qz-cat-id').readOnly = false;
  document.getElementById('qz-cat-levels').value = '10';
  document.getElementById('qz-cat-visible').checked = true;
  document.getElementById('quiz-cat-heading').textContent = '🏆 قسم مسابقة (إضافة / تعديل)';
}

function resetQuestionForm() {
  document.getElementById('quiz-question-form').reset();
  document.getElementById('qz-q-id').value = '';
  document.getElementById('qz-q-level').value = '1';
  document.getElementById('qz-q-visible').checked = true;
  document.getElementById('quiz-q-heading').textContent = '❓ إضافة / تعديل سؤال سحابي';
}

async function handleSaveCategory(e) {
  e.preventDefault();
  const client = getSupabase();
  if (!client) return;
  const btn = document.getElementById('btn-save-quiz-cat');
  btn.disabled = true;
  try {
    const { error } = await client.rpc('admin_upsert_quiz_category', {
      p_id: document.getElementById('qz-cat-id').value.trim().toLowerCase(),
      p_name: document.getElementById('qz-cat-name').value.trim(),
      p_description: document.getElementById('qz-cat-desc').value.trim(),
      p_icon_name: document.getElementById('qz-cat-icon').value,
      p_color_hex: safeHexColor(document.getElementById('qz-cat-color').value, '#1B5E20'),
      p_total_levels: Number.parseInt(document.getElementById('qz-cat-levels').value || '10', 10) || 10,
      p_sort_order: Number.parseInt(document.getElementById('qz-cat-sort').value || '10', 10) || 10,
      p_is_visible: document.getElementById('qz-cat-visible').checked,
      p_is_locked: document.getElementById('qz-cat-locked').checked,
    });
    if (error) throw error;
    showToast('تم حفظ قسم المسابقة ✅');
    broadcastWebControlPing('ALL');
    resetCategoryForm();
    await Promise.all([loadQuizContent(), refreshOverview(), refreshAudit()]);
  } catch (err) {
    showToast(`فشل حفظ القسم: ${err.message}`, true);
  } finally {
    btn.disabled = false;
  }
}

async function handleSaveQuestion(e) {
  e.preventDefault();
  const client = getSupabase();
  if (!client) return;
  const options = [0, 1, 2, 3].map((i) => document.getElementById(`qz-opt-${i}`).value.trim());
  if (options.some((o) => !o)) {
    return showToast('جميع الخيارات الأربعة مطلوبة ولا يمكن ترك أي خيار فارغاً.', true);
  }
  const btn = document.getElementById('btn-save-quiz-q');
  btn.disabled = true;
  try {
    const idRaw = document.getElementById('qz-q-id').value.trim();
    const { error } = await client.rpc('admin_upsert_quiz_question', {
      p_id: idRaw || null,
      p_category_id: document.getElementById('qz-q-cat').value,
      p_level_number: Number.parseInt(document.getElementById('qz-q-level').value || '1', 10) || 1,
      p_question_text: document.getElementById('qz-q-text').value.trim(),
      p_options: options,
      p_correct_index: Number.parseInt(document.getElementById('qz-q-correct').value || '0', 10) || 0,
      p_explanation: document.getElementById('qz-q-exp').value.trim(),
      p_sync_scope: document.getElementById('qz-q-scope').value,
      p_sort_order: Number.parseInt(document.getElementById('qz-q-sort').value || '10', 10) || 10,
      p_is_visible: document.getElementById('qz-q-visible').checked,
    });
    if (error) throw error;
    showToast('تم حفظ السؤال السحابي بنجاح ✅');
    broadcastWebControlPing('ALL');
    resetQuestionForm();
    await Promise.all([loadQuizContent(), refreshOverview(), refreshAudit()]);
  } catch (err) {
    showToast(`فشل حفظ السؤال: ${err.message}`, true);
  } finally {
    btn.disabled = false;
  }
}

export function mountQuiz(container) {
  if (state.mounted || !container) return;
  container.innerHTML = buildQuizTemplate();
  state.mounted = true;

  document.getElementById('quiz-category-form').addEventListener('submit', handleSaveCategory);
  document.getElementById('quiz-question-form').addEventListener('submit', handleSaveQuestion);
  document.getElementById('quiz-filter-cat').addEventListener('change', loadQuizContent);
  document.getElementById('quiz-filter-level').addEventListener('change', loadQuizContent);
  document.getElementById('btn-reset-quiz-cat').addEventListener('click', resetCategoryForm);
  document.getElementById('btn-reset-quiz-q').addEventListener('click', resetQuestionForm);
  document.getElementById('qz-cat-color-picker').addEventListener('input', (e) => {
    document.getElementById('qz-cat-color').value = e.target.value.toUpperCase();
  });

  mountBulkImporter(document.getElementById('bulk-json-importer-mount'), {
    onCategoriesMutated: loadQuizContent,
  });
}

export function onQuizSubtabActivated() {
  refreshBulkActiveConfig();
}

export async function loadQuizContent() {
  const client = getSupabase();
  if (!client) return;
  const cat = document.getElementById('quiz-filter-cat')?.value || null;
  const lvlRaw = document.getElementById('quiz-filter-level')?.value.trim();
  const lvl = lvlRaw ? Number.parseInt(lvlRaw, 10) : null;
  const { data, error } = await client.rpc('admin_list_quiz_content', {
    p_category_id: cat || null,
    p_level_number: Number.isFinite(lvl) ? lvl : null,
    p_limit: 120,
  });
  if (error) {
    showToast(`تعذر تحميل المسابقات والأسئلة: ${error.message}`, true);
    return;
  }
  state.categories = Array.isArray(data?.categories) ? data.categories : [];
  state.questions = Array.isArray(data?.questions) ? data.questions : [];
  populateSelects();
  renderCategories();
  renderQuestions();
}
