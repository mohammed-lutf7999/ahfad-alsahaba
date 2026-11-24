import { refreshAudit, refreshOverview } from '../core/app_bus.js';
import { BULK_CHUNK_SIZE, QUESTION_PACKS_BUCKET } from '../core/config.js';
import { broadcastWebControlPing } from '../core/rest_broadcast.js';
import { getSupabase } from '../core/supabase_client.js';
import { escapeHtml, showToast } from '../core/ui_utils.js';
import {
  buildBulkImporterTemplate,
  renderBulkValidationReport,
} from './bulk_json_importer_view.js';
import {
  compressJsonToGzipBytes,
  stripUtf8Bom,
  validateAndNormalizeJson,
} from './bulk_json_validator.js';

const state = {
  mounted: false,
  parsedQuestions: [],
  parsedMeta: null,
  validationErrors: [],
  validationWarnings: [],
  isBusy: false,
  onCategoriesMutated: null,
};

function getActiveCategoryId() {
  const mode = document.getElementById('bulk-target-mode')?.value || 'existing';
  const id = mode === 'new' ? 'bulk-new-cat-id' : 'bulk-existing-cat';
  return String(document.getElementById(id)?.value || '').trim().toLowerCase();
}

function setBusy(busy) {
  state.isBusy = Boolean(busy);
  const uploadBtn = document.getElementById('btn-bulk-upload-db');
  const cfgBtn = document.getElementById('btn-bulk-save-config');
  const pubBtn = document.getElementById('btn-bulk-publish-gzip');
  if (cfgBtn) cfgBtn.disabled = state.isBusy;
  if (pubBtn) pubBtn.disabled = state.isBusy;
  if (uploadBtn) {
    uploadBtn.disabled =
      state.isBusy || state.validationErrors.length > 0 || state.parsedQuestions.length === 0;
  }
}

function renderValidationSummary() {
  const reportEl = document.getElementById('bulk-validation-report');
  const uploadBtn = document.getElementById('btn-bulk-upload-db');
  const badgeEl = document.getElementById('bulk-import-status-badge');
  if (!reportEl || !uploadBtn || !badgeEl) return;

  const summary = renderBulkValidationReport(state);
  badgeEl.textContent = summary.badgeText;
  uploadBtn.disabled = state.isBusy || !summary.canUpload;
  reportEl.innerHTML = summary.html;
}

export async function hydrateConfigForCategory(catId) {
  const client = getSupabase();
  if (!client || !catId) return;
  try {
    const { data, error } = await client
      .from('quiz_categories')
      .select('total_levels, questions_per_level, level_draw_mode')
      .eq('id', catId)
      .maybeSingle();
    if (error || !data) return;
    if (data.total_levels) document.getElementById('bulk-total-levels').value = String(data.total_levels);
    if (data.questions_per_level) document.getElementById('bulk-q-per-level').value = String(data.questions_per_level);
    if (data.level_draw_mode) document.getElementById('bulk-draw-mode').value = String(data.level_draw_mode);
  } catch {
    // Non-fatal; keep current UI values
  }
}

export function syncBulkCategories(categories) {
  const dst = document.getElementById('bulk-existing-cat');
  if (!dst || !Array.isArray(categories) || categories.length === 0) return;
  const prev = dst.value;
  dst.innerHTML = categories
    .map((c) => `<option value="${escapeHtml(c.id)}">${escapeHtml(c.name)} (${escapeHtml(c.id)})</option>`)
    .join('');
  if (prev && categories.some((c) => c.id === prev)) {
    dst.value = prev;
  }
}

export function refreshBulkActiveConfig() {
  const mode = document.getElementById('bulk-target-mode')?.value;
  const catId = document.getElementById('bulk-existing-cat')?.value;
  if (mode === 'existing' && catId) {
    hydrateConfigForCategory(catId);
  }
}

async function ensureCategoryAndConfigSaved(client, { saveConfigForExisting = true } = {}) {
  const mode = document.getElementById('bulk-target-mode').value;
  const catId = getActiveCategoryId();
  const totalLevels = Math.max(1, Math.min(100, Number(document.getElementById('bulk-total-levels').value || 10)));
  const qPerLevel = Math.max(1, Math.min(100, Number(document.getElementById('bulk-q-per-level').value || 10)));
  const drawMode = document.getElementById('bulk-draw-mode').value === 'rotating_pool' ? 'rotating_pool' : 'fixed';

  if (!/^[a-z0-9_]{2,48}$/.test(catId)) {
    throw new Error('معرّف القسم غير صالح (أحرف إنجليزية صغيرة وأرقام وشرطة سفلية فقط).');
  }

  if (mode === 'new') {
    const name = document.getElementById('bulk-new-cat-name').value.trim();
    const desc = document.getElementById('bulk-new-cat-desc').value.trim();
    const color = document.getElementById('bulk-new-cat-color').value.trim() || '#1B5E20';
    if (name.length < 2) throw new Error('يرجى إدخال اسم القسم العربي قبل الحفظ.');

    const { error: catErr } = await client.rpc('admin_upsert_quiz_category', {
      p_id: catId, p_name: name, p_description: desc,
      p_icon_name: state.parsedMeta?.iconName || 'quiz_rounded',
      p_color_hex: color, p_total_levels: totalLevels, p_sort_order: 100,
      p_is_visible: true, p_is_locked: false,
    });
    if (catErr) throw catErr;

    const { error: cfgErr } = await client.rpc('admin_update_quiz_category_config', {
      p_category_id: catId, p_total_levels: totalLevels,
      p_questions_per_level: qPerLevel, p_level_draw_mode: drawMode,
    });
    if (cfgErr) throw cfgErr;
    return catId;
  }

  if (saveConfigForExisting) {
    const { error: cfgErr } = await client.rpc('admin_update_quiz_category_config', {
      p_category_id: catId, p_total_levels: totalLevels,
      p_questions_per_level: qPerLevel, p_level_draw_mode: drawMode,
    });
    if (cfgErr) throw cfgErr;
  }
  return catId;
}

async function handleBulkUpload() {
  if (state.isBusy || state.parsedQuestions.length === 0) return;
  const client = getSupabase();
  if (!client) return showToast('يرجى تسجيل الدخول كمشرف أولاً', true);
  const logEl = document.getElementById('bulk-progress-log');
  setBusy(true);
  try {
    logEl.textContent = 'جارٍ تجهيز القسم...';
    const catId = await ensureCategoryAndConfigSaved(client, { saveConfigForExisting: false });
    const total = state.parsedQuestions.length;
    let uploaded = 0;
    for (let i = 0; i < total; i += BULK_CHUNK_SIZE) {
      const chunk = state.parsedQuestions.slice(i, i + BULK_CHUNK_SIZE);
      logEl.textContent = `جارٍ رفع الدفعة ${Math.floor(i / BULK_CHUNK_SIZE) + 1} (${uploaded}/${total})...`;
      const { error } = await client.rpc('admin_bulk_upsert_quiz_questions', {
        p_category_id: catId,
        p_questions: chunk,
      });
      if (error) throw error;
      uploaded += chunk.length;
    }
    logEl.textContent = `✅ تم رفع ${uploaded} سؤالاً بنجاح إلى القسم (${catId}). اضغط الآن "ضغط ونشر حزمة Gzip CDN" لتوزيعها للاعبين.`;
    showToast(`تم استيراد ${uploaded} سؤالاً بنجاح`);
    broadcastWebControlPing('ALL');
    await Promise.all([state.onCategoriesMutated?.(), refreshOverview(), refreshAudit()]);
  } catch (err) {
    const msg = err?.message || String(err);
    logEl.textContent = `❌ فشل الاستيراد: ${msg}`;
    showToast(`فشل الاستيراد: ${msg}`, true);
  } finally {
    setBusy(false);
  }
}

async function handleSaveConfigOnly() {
  if (state.isBusy) return;
  const client = getSupabase();
  if (!client) return showToast('يرجى تسجيل الدخول كمشرف أولاً', true);
  const logEl = document.getElementById('bulk-progress-log');
  setBusy(true);
  try {
    const catId = await ensureCategoryAndConfigSaved(client, { saveConfigForExisting: true });
    logEl.textContent = `✅ تم حفظ إعدادات المستويات والنمط للقسم (${catId}).`;
    showToast('تم حفظ إعدادات القسم بنجاح');
    broadcastWebControlPing('ALL');
    await Promise.all([state.onCategoriesMutated?.(), refreshAudit()]);
  } catch (err) {
    const msg = err?.message || String(err);
    logEl.textContent = `❌ خطأ في حفظ الإعدادات: ${msg}`;
    showToast(msg, true);
  } finally {
    setBusy(false);
  }
}

async function handlePublishGzipPack() {
  if (state.isBusy) return;
  const client = getSupabase();
  if (!client) return showToast('يرجى تسجيل الدخول كمشرف أولاً', true);
  const catId = getActiveCategoryId();
  if (!catId) return showToast('اختر القسم المستهدف أولاً', true);

  const logEl = document.getElementById('bulk-progress-log');
  setBusy(true);
  try {
    logEl.textContent = `جارٍ تصدير أسئلة القسم (${catId}) من القاعدة...`;
    const { data: payload, error: expErr } = await client.rpc('admin_export_category_pack_payload', {
      p_category_id: catId,
    });
    if (expErr) throw expErr;
    if (!payload || !payload.questionsCount) {
      throw new Error('لا توجد أسئلة سحابية مرئية في هذا القسم لتصديرها كحزمة.');
    }

    logEl.textContent = `جارٍ ضغط ${payload.questionsCount} سؤالاً عبر CompressionStream('gzip')...`;
    const { rawBytes, gzBytes } = await compressJsonToGzipBytes(payload);
    const storagePath = `${catId}_v${Number(payload.packVersion || 1)}.json.gz`;

    // CRITICAL: application/octet-stream with NO Content-Encoding: gzip (prevents Double-Gzip on Flutter)
    const blob = new Blob([gzBytes], { type: 'application/octet-stream' });
    const { error: upErr } = await client.storage.from(QUESTION_PACKS_BUCKET).upload(storagePath, blob, {
      contentType: 'application/octet-stream',
      cacheControl: '31536000',
      upsert: true,
    });
    if (upErr) throw upErr;

    const { error: pubErr } = await client.rpc('admin_publish_category_pack', {
      p_category_id: catId,
      p_pack_storage_path: storagePath,
      p_questions_count: Number(payload.questionsCount || 0),
    });
    if (pubErr) throw pubErr;

    const rawKb = (rawBytes.byteLength / 1024).toFixed(1);
    const gzKb = (gzBytes.byteLength / 1024).toFixed(1);
    logEl.textContent = `✅ نُشرت الحزمة ${storagePath} (${payload.questionsCount} سؤالاً — ${rawKb} KB ← ${gzKb} KB Gzip).`;
    showToast(`تم نشر حزمة Gzip CDN بنجاح (${gzKb} KB)`);
    broadcastWebControlPing('ALL');
    await Promise.all([refreshOverview(), refreshAudit()]);
  } catch (err) {
    const msg = err?.message || String(err);
    logEl.textContent = `❌ فشل نشر الحزمة: ${msg}`;
    showToast(`فشل نشر الحزمة: ${msg}`, true);
  } finally {
    setBusy(false);
  }
}

export function mountBulkImporter(mountEl, { onCategoriesMutated } = {}) {
  if (state.mounted || !mountEl) return;
  state.onCategoriesMutated = onCategoriesMutated || null;
  mountEl.innerHTML = buildBulkImporterTemplate();
  state.mounted = true;

  const modeSelect = document.getElementById('bulk-target-mode');
  const existingSelect = document.getElementById('bulk-existing-cat');
  const existingWrap = document.getElementById('bulk-existing-cat-wrap');
  const newFields = document.getElementById('bulk-new-cat-fields');

  modeSelect.addEventListener('change', () => {
    const isNew = modeSelect.value === 'new';
    existingWrap.classList.toggle('hidden', isNew);
    newFields.classList.toggle('hidden', !isNew);
    if (!isNew && existingSelect.value) hydrateConfigForCategory(existingSelect.value);
  });

  existingSelect.addEventListener('change', () => {
    if (existingSelect.value) hydrateConfigForCategory(existingSelect.value);
  });

  document.getElementById('bulk-json-file').addEventListener('change', async (ev) => {
    const file = ev.target.files?.[0];
    if (!file) return;
    try {
      const raw = JSON.parse(stripUtf8Bom(await file.text()));
      const { normalized, meta, errors, warnings } = validateAndNormalizeJson(raw);
      state.parsedQuestions = normalized;
      state.parsedMeta = meta;
      state.validationErrors = errors;
      state.validationWarnings = warnings;

      let maxLvl = 1;
      for (const q of normalized) if (q.level_number > maxLvl) maxLvl = q.level_number;

      if (meta) {
        if (meta.totalLevels) document.getElementById('bulk-total-levels').value = String(meta.totalLevels);
        if (meta.questionsPerLevel) document.getElementById('bulk-q-per-level').value = String(meta.questionsPerLevel);
        if (meta.levelDrawMode) document.getElementById('bulk-draw-mode').value = meta.levelDrawMode;
        if (meta.categoryId) {
          const exists = Array.from(existingSelect.options).some((o) => o.value === meta.categoryId);
          if (exists) {
            modeSelect.value = 'existing';
            existingSelect.value = meta.categoryId;
          } else {
            modeSelect.value = 'new';
            document.getElementById('bulk-new-cat-id').value = meta.categoryId;
            document.getElementById('bulk-new-cat-name').value = meta.categoryName;
            document.getElementById('bulk-new-cat-desc').value = meta.description;
            if (meta.colorHex) document.getElementById('bulk-new-cat-color').value = meta.colorHex;
          }
          modeSelect.dispatchEvent(new Event('change'));
        }
      }
      if (modeSelect.value === 'new' && (!meta || !meta.totalLevels) && normalized.length > 0) {
        document.getElementById('bulk-total-levels').value = String(maxLvl);
      }
      renderValidationSummary();
    } catch (parseErr) {
      state.parsedQuestions = [];
      state.parsedMeta = null;
      state.validationErrors = [`ملف JSON غير صالح: ${parseErr?.message || parseErr}`];
      state.validationWarnings = [];
      renderValidationSummary();
    }
  });

  document.getElementById('btn-bulk-upload-db').addEventListener('click', handleBulkUpload);
  document.getElementById('btn-bulk-save-config').addEventListener('click', handleSaveConfigOnly);
  document.getElementById('btn-bulk-publish-gzip').addEventListener('click', handlePublishGzipPack);
}
