/* ============================================================================
 * معركة أحفاد الصحابة — أداة الاستيراد الجماعي لملفات JSON وحزم Gzip CDN
 * Standalone module for Plan 20 (v1.2.0+22) — JSON ONLY (No CSV).
 * - Pre-flight client-side JSON validator (IDs, duplicates, 4 options, 0..3)
 * - Supports existing category OR creating a new category with flexible levels
 * - Chunked batch upsert (200 questions/call) via `admin_bulk_upsert_quiz_questions`
 * - Native browser `CompressionStream('gzip')` upload to `question-packs` bucket
 *   with `contentType: 'application/octet-stream'` (NO `Content-Encoding: gzip`
 *   to prevent Double-Gzip corruption on Flutter clients).
 * ============================================================================ */

(function () {
  'use strict';

  const CHUNK_SIZE = 200;
  const BUCKET_NAME = 'question-packs';
  const state = {
    parsedQuestions: [],
    parsedMeta: null,
    validationErrors: [],
    validationWarnings: [],
    isBusy: false,
  };

  function bridge() {
    return window.SahabaAdminBridge || null;
  }

  function sb() {
    return bridge()?.getSupabase?.() || null;
  }

  function esc(v) {
    if (bridge()?.escapeHtml) return bridge().escapeHtml(v);
    return String(v ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function toast(msg, isErr = false) {
    if (bridge()?.showToast) {
      bridge().showToast(msg, isErr);
    } else {
      console[isErr ? 'error' : 'log'](msg);
    }
  }

  function normalizeQuestionText(text) {
    return String(text || '')
      .trim()
      .toLowerCase()
      .replace(/[\u0640\u064B-\u065F\u0670]/g, '')
      .replace(/[أإآ]/g, 'ا')
      .replace(/ة/g, 'ه')
      .replace(/\s+/g, ' ');
  }

  function validateAndNormalizeJson(rawData) {
    const errors = [];
    const warnings = [];
    const normalized = [];
    let meta = null;

    const pushCandidate = (item, fallbackLevel, indexInLevel) => {
      if (!item || typeof item !== 'object') {
        errors.push(`عنصر غير صالح في المستوى ${fallbackLevel} (فهرس ${indexInLevel}).`);
        return;
      }
      const rawId = String(item.id || '').trim();
      const levelNum = Number(item.levelNumber ?? item.level_number ?? fallbackLevel);
      const qText = String(item.question ?? item.question_text ?? '').trim();
      const rawOptions = Array.isArray(item.options) ? item.options : [];
      const cleanOptions = rawOptions.map((o) => String(o ?? '').trim());
      const correct = Number(item.correct ?? item.correct_index ?? -1);
      const explanation = String(item.explanation ?? '').trim();
      const sortOrder = Number(item.sortOrder ?? item.sort_order ?? (100 + indexInLevel));

      if (!/^[a-zA-Z0-9_-]{3,80}$/.test(rawId)) {
        errors.push(`معرّف السؤال غير صالح "${rawId}" (يجب 3–80 حرفاً إنجليزياً/أرقاماً/شرطة).`);
        return;
      }
      if (!Number.isInteger(levelNum) || levelNum < 1 || levelNum > 100) {
        errors.push(`رقم المستوى غير صالح (${levelNum}) للسؤال ${rawId} (المسموح 1..100).`);
        return;
      }
      if (qText.length < 3) {
        errors.push(`نص السؤال قصير جداً للمعرّف ${rawId}.`);
        return;
      }
      if (cleanOptions.length !== 4 || cleanOptions.some((o) => o.length === 0)) {
        errors.push(`السؤال ${rawId} يجب أن يحتوي على 4 خيارات غير فارغة تماماً.`);
        return;
      }
      if (!Number.isInteger(correct) || correct < 0 || correct > 3) {
        errors.push(`فهرس الإجابة الصحيحة (${correct}) غير صالح للسؤال ${rawId} (المسموح 0..3).`);
        return;
      }
      if (!explanation) {
        warnings.push(`السؤال ${rawId} بدون شرح تاريخي/شرعي (explanation).`);
      }

      normalized.push({
        id: rawId,
        level_number: levelNum,
        question_text: qText,
        options: cleanOptions,
        correct_index: correct,
        explanation,
        sync_scope: item.syncScope === 'all_with_fallback' ? 'all_with_fallback' : 'solo_only',
        sort_order: Number.isFinite(sortOrder) ? Math.trunc(sortOrder) : 100,
        is_visible: item.isVisible !== false,
      });
    };

    if (Array.isArray(rawData)) {
      rawData.forEach((item, idx) => pushCandidate(item, Number(item?.levelNumber ?? item?.level_number ?? 1), idx));
    } else if (rawData && typeof rawData === 'object' && rawData.levels && typeof rawData.levels === 'object') {
      meta = {
        categoryId: String(rawData.categoryId || rawData.category_id || '').trim().toLowerCase(),
        categoryName: String(rawData.categoryName || rawData.category_name || '').trim(),
        description: String(rawData.description || '').trim(),
        colorHex: String(rawData.colorHex || rawData.color_hex || '#1B5E20').trim(),
        iconName: String(rawData.iconName || rawData.iconKey || 'quiz_rounded').trim(),
        totalLevels: Number(rawData.totalLevels || rawData.total_levels || 0) || null,
        questionsPerLevel: Number(rawData.questionsPerLevel || rawData.questions_per_level || 10) || 10,
        levelDrawMode: rawData.levelDrawMode === 'rotating_pool' ? 'rotating_pool' : 'fixed',
      };
      const levelKeys = Object.keys(rawData.levels).sort((a, b) => Number(a) - Number(b));
      for (const lk of levelKeys) {
        const lvlNum = Number(lk);
        const list = rawData.levels[lk];
        if (!Array.isArray(list)) {
          errors.push(`المستوى "${lk}" يجب أن يكون مصفوفة أسئلة.`);
          continue;
        }
        list.forEach((item, idx) => pushCandidate(item, lvlNum, idx));
      }
    } else {
      errors.push('صيغة JSON غير مدعومة: يجب أن يحتوي الملف على كائن به حقل "levels" أو مصفوفة أسئلة.');
    }

    // Duplicate ID and duplicate text checks
    const seenIds = new Set();
    const seenTexts = new Map();
    for (const q of normalized) {
      if (seenIds.has(q.id)) {
        errors.push(`تكرار معرّف السؤال "${q.id}" داخل الملف.`);
      } else {
        seenIds.add(q.id);
      }
      const normText = normalizeQuestionText(q.question_text);
      if (seenTexts.has(normText)) {
        warnings.push(`نص سؤال مكرر بين (${seenTexts.get(normText)}) و(${q.id}).`);
      } else {
        seenTexts.set(normText, q.id);
      }
    }

    if (normalized.length === 0 && errors.length === 0) {
      errors.push('الملف لا يحتوي على أي أسئلة صالحة للاستيراد.');
    }

    return { normalized, meta, errors, warnings };
  }

  async function compressJsonToGzipBytes(obj) {
    const jsonText = JSON.stringify(obj);
    const rawBytes = new TextEncoder().encode(jsonText);
    if (typeof CompressionStream === 'undefined') {
      throw new Error('المتصفح الحالي لا يدعم CompressionStream("gzip"). استخدم Edge أو Chrome حديثاً.');
    }
    const cs = new CompressionStream('gzip');
    const writer = cs.writable.getWriter();
    writer.write(rawBytes);
    writer.close();
    const compressedBuffer = await new Response(cs.readable).arrayBuffer();
    const gzBytes = new Uint8Array(compressedBuffer);
    return { rawBytes, gzBytes };
  }

  function renderPanel(mountEl) {
    mountEl.innerHTML = `
      <div class="panel glass-card" id="bulk-json-importer-panel" style="margin-bottom: 16px;">
        <div class="panel-header-row">
          <h2 class="panel-title">📦 استيراد ملف أسئلة JSON ونشر حزم Gzip CDN (حتى 1,000+ سؤال)</h2>
          <span id="bulk-import-status-badge" class="badge-pill">JSON فقط</span>
        </div>

        <div class="stack-sm">
          <div class="grid-2">
            <div>
              <label class="field-label" for="bulk-target-mode">وجهة الاستيراد</label>
              <select id="bulk-target-mode" class="input">
                <option value="existing">الاستيراد إلى قسم موجود</option>
                <option value="new">إنشاء قسم جديد + استيراد ملفه دفعة واحدة</option>
              </select>
            </div>
            <div id="bulk-existing-cat-wrap">
              <label class="field-label" for="bulk-existing-cat">اختر القسم المستهدف</label>
              <select id="bulk-existing-cat" class="input">
                <option value="seerah">السيرة النبوية (seerah)</option>
                <option value="quran">القرآن الكريم (quran)</option>
                <option value="hadith">الحديث الشريف (hadith)</option>
                <option value="fiqh">الفقه الإسلامي (fiqh)</option>
                <option value="history">التاريخ الإسلامي (history)</option>
                <option value="aqeedah">العقيدة الإسلامية (aqeedah)</option>
              </select>
            </div>
          </div>

          <div id="bulk-new-cat-fields" class="grid-2" style="display: none;">
            <div>
              <label class="field-label" for="bulk-new-cat-id">معرّف القسم الجديد (إنجليزي صغير)</label>
              <input id="bulk-new-cat-id" class="input" type="text" placeholder="مثال: companions_conquests" />
            </div>
            <div>
              <label class="field-label" for="bulk-new-cat-name">اسم القسم العربي</label>
              <input id="bulk-new-cat-name" class="input" type="text" placeholder="مثال: الفتوحات الإسلامية الكبرى" />
            </div>
            <div>
              <label class="field-label" for="bulk-new-cat-desc">وصف مختصر</label>
              <input id="bulk-new-cat-desc" class="input" type="text" placeholder="اختبر معرفتك ببطولات الصحابة" />
            </div>
            <div>
              <label class="field-label" for="bulk-new-cat-color">اللون (Hex)</label>
              <input id="bulk-new-cat-color" class="input" type="text" value="#1B5E20" />
            </div>
          </div>

          <div class="grid-3">
            <div>
              <label class="field-label" for="bulk-total-levels">عدد المستويات (1–100)</label>
              <input id="bulk-total-levels" class="input" type="number" min="1" max="100" value="10" />
            </div>
            <div>
              <label class="field-label" for="bulk-q-per-level">عدد الأسئلة في كل مستوى (1–100)</label>
              <input id="bulk-q-per-level" class="input" type="number" min="1" max="100" value="10" />
            </div>
            <div>
              <label class="field-label" for="bulk-draw-mode">نمط السحب</label>
              <select id="bulk-draw-mode" class="input">
                <option value="fixed">ثابت (fixed)</option>
                <option value="rotating_pool">وعاء متجدد تلقائياً (rotating_pool)</option>
              </select>
            </div>
          </div>

          <div>
            <label class="field-label" for="bulk-json-file">اختر ملف الأسئلة (JSON فقط)</label>
            <input id="bulk-json-file" class="input" type="file" accept=".json,application/json" />
          </div>

          <div id="bulk-validation-report" class="muted" style="font-size: 13px; line-height: 1.7;"></div>

          <div class="record-actions" style="flex-wrap: wrap; gap: 8px;">
            <button id="btn-bulk-upload-db" class="btn btn-primary" type="button" disabled>⬆️ رفع الأسئلة للقاعدة (دفعات 200)</button>
            <button id="btn-bulk-save-config" class="btn btn-outline" type="button">⚙️ حفظ إعدادات المستويات والنمط للقسم</button>
            <button id="btn-bulk-publish-gzip" class="btn btn-outline" type="button">📦 ضغط ونشر حزمة Gzip CDN للقسم</button>
          </div>
          <div id="bulk-progress-log" class="muted" style="font-size: 12.5px;"></div>
        </div>
      </div>
    `;
  }

  function syncCategoryDropdownFromDom() {
    const srcSelect = document.getElementById('quiz-filter-cat');
    const dstSelect = document.getElementById('bulk-existing-cat');
    if (!srcSelect || !dstSelect || srcSelect.options.length <= 1) return;
    const prev = dstSelect.value;
    const items = [];
    for (let i = 1; i < srcSelect.options.length; i += 1) {
      const opt = srcSelect.options[i];
      if (opt.value) items.push({ value: opt.value, text: opt.textContent || opt.value });
    }
    if (items.length === 0) return;
    dstSelect.innerHTML = items
      .map((it) => `<option value="${esc(it.value)}">${esc(it.text)}</option>`)
      .join('');
    if (prev && items.some((it) => it.value === prev)) {
      dstSelect.value = prev;
    }
  }

  function renderValidationSummary() {
    const reportEl = document.getElementById('bulk-validation-report');
    const uploadBtn = document.getElementById('btn-bulk-upload-db');
    const badgeEl = document.getElementById('bulk-import-status-badge');
    if (!reportEl || !uploadBtn || !badgeEl) return;

    const count = state.parsedQuestions.length;
    const levelCounts = new Map();
    let maxLvl = 1;
    for (const q of state.parsedQuestions) {
      levelCounts.set(q.level_number, (levelCounts.get(q.level_number) || 0) + 1);
      if (q.level_number > maxLvl) maxLvl = q.level_number;
    }

    const parts = [];
    if (state.validationErrors.length > 0) {
      badgeEl.textContent = `❌ ${state.validationErrors.length} خطأ`;
      uploadBtn.disabled = true;
      parts.push(`<strong style="color:#f87171;">أخطاء تمنع الرفع (${state.validationErrors.length}):</strong>`);
      parts.push(
        state.validationErrors
          .slice(0, 8)
          .map((e) => `• ${esc(e)}`)
          .join('<br>')
      );
    } else if (count > 0) {
      badgeEl.textContent = `✅ ${count} سؤال جاهز`;
      uploadBtn.disabled = false;
      parts.push(
        `<strong style="color:#34d399;">تم فحص ${count} سؤالاً بنجاح</strong> عبر ${levelCounts.size} مستوى (أعلى مستوى: ${maxLvl}).`
      );
    } else {
      badgeEl.textContent = 'JSON فقط';
      uploadBtn.disabled = true;
    }

    if (state.validationWarnings.length > 0) {
      parts.push(
        `<div style="color:#fbbf24; margin-top:4px;">تنبيهات غير مانعة (${state.validationWarnings.length}): ` +
          state.validationWarnings
            .slice(0, 4)
            .map((w) => esc(w))
            .join(' | ') +
          '</div>'
      );
    }

    reportEl.innerHTML = parts.join('<br>');
  }

  function getActiveCategoryId() {
    const mode = document.getElementById('bulk-target-mode')?.value || 'existing';
    if (mode === 'new') {
      return String(document.getElementById('bulk-new-cat-id')?.value || '').trim().toLowerCase();
    }
    return String(document.getElementById('bulk-existing-cat')?.value || '').trim().toLowerCase();
  }

  async function ensureCategoryAndConfigSaved(client) {
    const mode = document.getElementById('bulk-target-mode')?.value || 'existing';
    const catId = getActiveCategoryId();
    const totalLevels = Math.max(1, Math.min(100, Number(document.getElementById('bulk-total-levels')?.value || 10)));
    const qPerLevel = Math.max(1, Math.min(100, Number(document.getElementById('bulk-q-per-level')?.value || 10)));
    const drawMode = document.getElementById('bulk-draw-mode')?.value === 'rotating_pool' ? 'rotating_pool' : 'fixed';

    if (!/^[a-z0-9_]{2,48}$/.test(catId)) {
      throw new Error('معرّف القسم غير صالح (أحرف إنجليزية صغيرة وأرقام وشرطة سفلية فقط).');
    }

    if (mode === 'new') {
      const name = String(document.getElementById('bulk-new-cat-name')?.value || '').trim();
      const desc = String(document.getElementById('bulk-new-cat-desc')?.value || '').trim();
      const color = String(document.getElementById('bulk-new-cat-color')?.value || '#1B5E20').trim();
      if (name.length < 2) {
        throw new Error('يرجى إدخال اسم القسم العربي قبل الحفظ.');
      }
      const { error: catErr } = await client.rpc('admin_upsert_quiz_category', {
        p_id: catId,
        p_name: name,
        p_description: desc,
        p_icon_name: state.parsedMeta?.iconName || 'quiz_rounded',
        p_color_hex: color,
        p_total_levels: totalLevels,
        p_sort_order: 100,
        p_is_visible: true,
        p_is_locked: false,
      });
      if (catErr) throw catErr;
    }

    const { error: cfgErr } = await client.rpc('admin_update_quiz_category_config', {
      p_category_id: catId,
      p_total_levels: totalLevels,
      p_questions_per_level: qPerLevel,
      p_level_draw_mode: drawMode,
    });
    if (cfgErr) throw cfgErr;
    return catId;
  }

  async function handleBulkUpload() {
    if (state.isBusy || state.parsedQuestions.length === 0) return;
    const client = sb();
    if (!client) {
      toast('يرجى تسجيل الدخول كمشرف أولاً', true);
      return;
    }

    const logEl = document.getElementById('bulk-progress-log');
    state.isBusy = true;
    try {
      if (logEl) logEl.textContent = 'جارٍ تجهيز القسم وإعدادات المستويات...';
      const catId = await ensureCategoryAndConfigSaved(client);

      const total = state.parsedQuestions.length;
      let uploaded = 0;
      for (let i = 0; i < total; i += CHUNK_SIZE) {
        const chunk = state.parsedQuestions.slice(i, i + CHUNK_SIZE);
        if (logEl) {
          logEl.textContent = `جارٍ رفع الدفعة ${Math.floor(i / CHUNK_SIZE) + 1} (${uploaded}/${total})...`;
        }
        const { error } = await client.rpc('admin_bulk_upsert_quiz_questions', {
          p_category_id: catId,
          p_questions: chunk,
        });
        if (error) throw error;
        uploaded += chunk.length;
      }

      if (logEl) {
        logEl.textContent = `✅ تم رفع ${uploaded} سؤالاً بنجاح إلى القسم (${catId}). اضغط الآن "ضغط ونشر حزمة Gzip CDN" لتوزيعها للاعبين.`;
      }
      toast(`تم استيراد ${uploaded} سؤالاً بنجاح`);
      await bridge()?.broadcastWebControlPing?.('ALL');
    } catch (err) {
      const msg = err?.message || String(err);
      if (logEl) logEl.textContent = `❌ فشل الاستيراد: ${msg}`;
      toast(`فشل الاستيراد: ${msg}`, true);
    } finally {
      state.isBusy = false;
    }
  }

  async function handleSaveConfigOnly() {
    if (state.isBusy) return;
    const client = sb();
    if (!client) {
      toast('يرجى تسجيل الدخول كمشرف أولاً', true);
      return;
    }
    const logEl = document.getElementById('bulk-progress-log');
    state.isBusy = true;
    try {
      const catId = await ensureCategoryAndConfigSaved(client);
      if (logEl) logEl.textContent = `✅ تم حفظ إعدادات المستويات والنمط للقسم (${catId}).`;
      toast('تم حفظ إعدادات القسم بنجاح');
      await bridge()?.broadcastWebControlPing?.('ALL');
    } catch (err) {
      const msg = err?.message || String(err);
      if (logEl) logEl.textContent = `❌ خطأ في حفظ الإعدادات: ${msg}`;
      toast(msg, true);
    } finally {
      state.isBusy = false;
    }
  }

  async function handlePublishGzipPack() {
    if (state.isBusy) return;
    const client = sb();
    if (!client) {
      toast('يرجى تسجيل الدخول كمشرف أولاً', true);
      return;
    }
    const catId = getActiveCategoryId();
    if (!catId) {
      toast('اختر القسم المستهدف أولاً', true);
      return;
    }

    const logEl = document.getElementById('bulk-progress-log');
    state.isBusy = true;
    try {
      if (logEl) logEl.textContent = `جارٍ تصدير أسئلة القسم (${catId}) من القاعدة...`;
      const { data: payload, error: expErr } = await client.rpc('admin_export_category_pack_payload', {
        p_category_id: catId,
      });
      if (expErr) throw expErr;
      if (!payload || !payload.questionsCount) {
        throw new Error('لا توجد أسئلة سحابية مرئية في هذا القسم لتصديرها كحزمة.');
      }

      if (logEl) logEl.textContent = `جارٍ ضغط ${payload.questionsCount} سؤالاً عبر CompressionStream('gzip')...`;
      const { rawBytes, gzBytes } = await compressJsonToGzipBytes(payload);
      const packVer = Number(payload.packVersion || 1);
      const storagePath = `${catId}_v${packVer}.json.gz`;

      // CRITICAL: Upload as application/octet-stream with NO Content-Encoding: gzip
      // to prevent Double-Gzip / CDN auto-decompression ambiguity on Flutter clients.
      const blob = new Blob([gzBytes], { type: 'application/octet-stream' });
      const { error: upErr } = await client.storage
        .from(BUCKET_NAME)
        .upload(storagePath, blob, {
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
      if (logEl) {
        logEl.textContent = `✅ نُشرت الحزمة ${storagePath} (${payload.questionsCount} سؤالاً — ${rawKb} KB ← ${gzKb} KB Gzip).`;
      }
      toast(`تم نشر حزمة Gzip CDN بنجاح (${gzKb} KB)`);
      await bridge()?.broadcastWebControlPing?.('ALL');
    } catch (err) {
      const msg = err?.message || String(err);
      if (logEl) logEl.textContent = `❌ فشل نشر الحزمة: ${msg}`;
      toast(`فشل نشر الحزمة: ${msg}`, true);
    } finally {
      state.isBusy = false;
    }
  }

  function bindEvents() {
    const modeSelect = document.getElementById('bulk-target-mode');
    const existingWrap = document.getElementById('bulk-existing-cat-wrap');
    const newFields = document.getElementById('bulk-new-cat-fields');
    const fileInput = document.getElementById('bulk-json-file');

    modeSelect?.addEventListener('change', () => {
      const isNew = modeSelect.value === 'new';
      if (existingWrap) existingWrap.style.display = isNew ? 'none' : '';
      if (newFields) newFields.style.display = isNew ? '' : 'none';
    });

    fileInput?.addEventListener('change', async (ev) => {
      const file = ev.target.files?.[0];
      if (!file) return;
      try {
        const text = await file.text();
        const raw = JSON.parse(text);
        const { normalized, meta, errors, warnings } = validateAndNormalizeJson(raw);
        state.parsedQuestions = normalized;
        state.parsedMeta = meta;
        state.validationErrors = errors;
        state.validationWarnings = warnings;

        if (meta) {
          if (meta.totalLevels) {
            const el = document.getElementById('bulk-total-levels');
            if (el) el.value = String(meta.totalLevels);
          }
          if (meta.questionsPerLevel) {
            const el = document.getElementById('bulk-q-per-level');
            if (el) el.value = String(meta.questionsPerLevel);
          }
          if (meta.levelDrawMode) {
            const el = document.getElementById('bulk-draw-mode');
            if (el) el.value = meta.levelDrawMode;
          }
          if (meta.categoryId) {
            const existingSelect = document.getElementById('bulk-existing-cat');
            const existsInList =
              existingSelect && Array.from(existingSelect.options).some((o) => o.value === meta.categoryId);
            if (existsInList) {
              if (modeSelect) modeSelect.value = 'existing';
              existingSelect.value = meta.categoryId;
              modeSelect?.dispatchEvent(new Event('change'));
            } else {
              if (modeSelect) modeSelect.value = 'new';
              const idEl = document.getElementById('bulk-new-cat-id');
              const nameEl = document.getElementById('bulk-new-cat-name');
              const descEl = document.getElementById('bulk-new-cat-desc');
              const colorEl = document.getElementById('bulk-new-cat-color');
              if (idEl) idEl.value = meta.categoryId;
              if (nameEl) nameEl.value = meta.categoryName;
              if (descEl) descEl.value = meta.description;
              if (colorEl && meta.colorHex) colorEl.value = meta.colorHex;
              modeSelect?.dispatchEvent(new Event('change'));
            }
          }
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

    document.getElementById('btn-bulk-upload-db')?.addEventListener('click', handleBulkUpload);
    document.getElementById('btn-bulk-save-config')?.addEventListener('click', handleSaveConfigOnly);
    document.getElementById('btn-bulk-publish-gzip')?.addEventListener('click', handlePublishGzipPack);

    // Sync categories whenever content tab is opened
    document.querySelector('[data-tab="content"]')?.addEventListener('click', () => {
      setTimeout(syncCategoryDropdownFromDom, 400);
    });
  }

  function init() {
    const mountEl = document.getElementById('bulk-json-importer-mount');
    if (!mountEl) return;
    renderPanel(mountEl);
    bindEvents();
    syncCategoryDropdownFromDom();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
