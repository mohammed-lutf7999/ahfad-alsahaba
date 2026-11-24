import { escapeHtml } from '../core/ui_utils.js';

export function buildBulkImporterTemplate() {
  return `
    <div class="panel glass-card mb-md" id="bulk-json-importer-panel">
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
        <div id="bulk-new-cat-fields" class="grid-2 hidden">
          <div>
            <label class="field-label" for="bulk-new-cat-id">معرّف القسم الجديد (إنجليزي صغير)</label>
            <input id="bulk-new-cat-id" class="input ltr-input" type="text" placeholder="مثال: companions_conquests" />
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
            <input id="bulk-new-cat-color" class="input ltr-input" type="text" value="#1B5E20" />
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
        <div class="record-actions">
          <button id="btn-bulk-upload-db" class="btn btn-primary" type="button" disabled>⬆️ رفع الأسئلة للقاعدة (دفعات 200)</button>
          <button id="btn-bulk-save-config" class="btn btn-outline" type="button">⚙️ حفظ إعدادات المستويات والنمط للقسم</button>
          <button id="btn-bulk-publish-gzip" class="btn btn-outline" type="button">📦 ضغط ونشر حزمة Gzip CDN للقسم</button>
        </div>
        <div id="bulk-progress-log" class="muted" style="font-size: 12.5px;"></div>
      </div>
    </div>
  `;
}

export function renderBulkValidationReport({ parsedQuestions, validationErrors, validationWarnings }) {
  const count = parsedQuestions.length;
  const levelCounts = new Map();
  let maxLvl = 1;
  for (const q of parsedQuestions) {
    levelCounts.set(q.level_number, (levelCounts.get(q.level_number) || 0) + 1);
    if (q.level_number > maxLvl) maxLvl = q.level_number;
  }

  let badgeText = 'JSON فقط';
  let canUpload = false;
  const parts = [];

  if (validationErrors.length > 0) {
    badgeText = `❌ ${validationErrors.length} خطأ`;
    parts.push(`<strong style="color:#f87171;">أخطاء تمنع الرفع (${validationErrors.length}):</strong>`);
    parts.push(validationErrors.slice(0, 8).map((e) => `• ${escapeHtml(e)}`).join('<br>'));
  } else if (count > 0) {
    badgeText = `✅ ${count} سؤال جاهز`;
    canUpload = true;
    parts.push(
      `<strong style="color:#34d399;">تم فحص ${count} سؤالاً بنجاح</strong> عبر ${levelCounts.size} مستوى (أعلى مستوى: ${maxLvl}).`,
    );
  }

  if (validationWarnings.length > 0) {
    parts.push(
      `<div style="color:#fbbf24; margin-top:4px;">تنبيهات غير مانعة (${validationWarnings.length}): ` +
        validationWarnings.slice(0, 4).map((w) => escapeHtml(w)).join(' | ') +
        '</div>',
    );
  }

  return { badgeText, canUpload, html: parts.join('<br>') };
}
