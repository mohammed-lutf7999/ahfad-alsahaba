import { escapeHtml, safeHexColor } from '../core/ui_utils.js';

export function buildLibraryTemplate() {
  return `
    <section class="stack-md">
      <div class="panel glass-card">
        <div class="panel-header-row">
          <h2 id="lib-sec-heading" class="panel-title">🗂️ قسم مكتبة (إضافة / تعديل)</h2>
          <button id="btn-reset-lib-sec" class="btn btn-outline btn-sm" type="button">قسم جديد</button>
        </div>
        <form id="lib-section-form" class="stack-sm">
          <div class="form-row">
            <div class="form-group">
              <label class="field-label" for="lib-sec-id">معرّف القسم (ID)</label>
              <input id="lib-sec-id" class="input ltr-input" type="text" placeholder="stories أو seerah_extra" pattern="[a-z0-9_]{2,48}" required />
            </div>
            <div class="form-group">
              <label class="field-label" for="lib-sec-title">اسم القسم</label>
              <input id="lib-sec-title" class="input" type="text" placeholder="مثال: شمائل الصحابة" required />
            </div>
          </div>
          <div class="form-row-3">
            <div class="form-group">
              <label class="field-label" for="lib-sec-icon">الأيقونة</label>
              <select id="lib-sec-icon" class="input">
                <option value="auto_stories_rounded">كتاب مفتوح</option>
                <option value="mosque_rounded">مسجد</option>
                <option value="menu_book_rounded">مصحف/كتاب</option>
                <option value="history_edu_rounded">تاريخ وسيرة</option>
                <option value="auto_awesome_rounded">نجم</option>
                <option value="shield_rounded">درع</option>
                <option value="emoji_events_rounded">كأس</option>
              </select>
            </div>
            <div class="form-group">
              <label class="field-label" for="lib-sec-color">اللون</label>
              <div class="color-row">
                <input id="lib-sec-color" class="input ltr-input" type="text" value="#D4AF37" />
                <input id="lib-sec-color-picker" class="color-swatch" type="color" value="#d4af37" />
              </div>
            </div>
            <div class="form-group">
              <label class="field-label" for="lib-sec-sort">الترتيب</label>
              <input id="lib-sec-sort" class="input" type="number" value="10" />
            </div>
          </div>
          <label class="inline-check">
            <input id="lib-sec-visible" type="checkbox" checked />
            <span>القسم مرئي للاعبين</span>
          </label>
          <button id="btn-save-lib-sec" class="btn btn-outline btn-block" type="submit">حفظ القسم</button>
        </form>
      </div>

      <div class="panel glass-card">
        <div class="panel-header-row">
          <h2 id="lib-item-heading" class="panel-title">📝 مقال / قصة / بطاقة معرفة</h2>
          <button id="btn-reset-lib-item" class="btn btn-outline btn-sm" type="button">عنصر جديد</button>
        </div>
        <form id="lib-item-form" class="stack-sm">
          <input id="lib-item-id" type="hidden" />
          <div class="form-row">
            <div class="form-group">
              <label class="field-label" for="lib-item-section">القسم التابع له</label>
              <select id="lib-item-section" class="input"></select>
            </div>
            <div class="form-group">
              <label class="field-label" for="lib-item-sort">الترتيب</label>
              <input id="lib-item-sort" class="input" type="number" value="10" />
            </div>
          </div>
          <div class="form-group">
            <label class="field-label" for="lib-item-title">عنوان البطاقة</label>
            <input id="lib-item-title" class="input" type="text" placeholder="مثال: ثبات بلال بن رباح رضي الله عنه" required />
          </div>
          <div class="form-row">
            <div class="form-group">
              <label class="field-label" for="lib-item-subtitle">عنوان فرعي / تصنيف</label>
              <input id="lib-item-subtitle" class="input" type="text" placeholder="مواقف الإيمان..." />
            </div>
            <div class="form-group">
              <label class="field-label" for="lib-item-source">المصدر الموثق (اختياري)</label>
              <input id="lib-item-source" class="input" type="text" placeholder="السيرة النبوية لابن هشام" />
            </div>
          </div>
          <div class="form-group">
            <label class="field-label" for="lib-item-content">المحتوى الكامل</label>
            <textarea id="lib-item-content" class="input" rows="4" placeholder="اكتب النص العلمي أو القصة الكاملة هنا..." required></textarea>
          </div>
          <label class="inline-check">
            <input id="lib-item-visible" type="checkbox" checked />
            <span>مرئي داخل المكتبة</span>
          </label>
          <button id="btn-save-lib-item" class="btn btn-gold btn-block" type="submit">حفظ عنصر المكتبة</button>
        </form>
      </div>
    </section>

    <section class="stack-md">
      <div class="panel glass-card">
        <div class="panel-header-row">
          <h2 class="panel-title">🗂️ أقسام المكتبة المسجّلة</h2>
          <span id="lib-sec-count" class="badge-pill">0</span>
        </div>
        <div id="lib-sections-list" class="items-list compact-list"></div>
      </div>
      <div class="panel glass-card">
        <div class="panel-header-row">
          <h2 class="panel-title">📄 عناصر المكتبة السحابية</h2>
          <select id="lib-filter-section" class="input compact-select">
            <option value="">كل الأقسام</option>
          </select>
        </div>
        <div id="lib-items-list" class="items-list"></div>
      </div>
    </section>
  `;
}

export function renderLibrarySectionsHtml(sections) {
  if (!sections.length) return '<p class="muted-text">لا توجد أقسام مكتبة.</p>';
  return sections
    .map((sec) => {
      const vis = sec.is_visible !== false;
      const hex = safeHexColor(sec.color_hex, '#D4AF37');
      return `
        <article class="record-card" style="border-right:3px solid ${hex};">
          <div class="record-top">
            <div class="record-actions">
              <strong>${escapeHtml(sec.title)}</strong>
              <span class="code-tag">${escapeHtml(sec.id)}</span>
              <span class="muted-text">• ${escapeHtml(sec.items_count ?? 0)} عنصر</span>
            </div>
            <div class="record-actions">
              <span class="${vis ? 'badge-visible' : 'badge-hidden'}">${vis ? 'مرئي' : 'مخفي'}</span>
              <button class="btn btn-outline btn-sm" type="button" data-edit-lib-sec="${escapeHtml(sec.id)}">تعديل</button>
              <label class="switch">
                <input type="checkbox" data-vis-lib-sec="${escapeHtml(sec.id)}" ${vis ? 'checked' : ''} />
                <span class="slider"></span>
              </label>
            </div>
          </div>
        </article>
      `;
    })
    .join('');
}

export function renderLibraryItemsHtml(items) {
  if (!items.length) return '<p class="muted-text">لا توجد عناصر سحابية مضافة في هذا القسم بعد.</p>';
  return items
    .map((item) => {
      const vis = item.is_visible !== false;
      const preview = (item.content || '').slice(0, 140);
      return `
        <article class="record-card">
          <div class="record-top">
            <div class="record-actions">
              <span class="badge-pill">${escapeHtml(item.section_id)}</span>
              <strong>${escapeHtml(item.title)}</strong>
            </div>
            <div class="record-actions">
              <span class="${vis ? 'badge-visible' : 'badge-hidden'}">${vis ? 'مرئي' : 'مخفي'}</span>
              <button class="btn btn-outline btn-sm" type="button" data-edit-lib-item="${escapeHtml(item.id)}">تعديل</button>
              <label class="switch">
                <input type="checkbox" data-vis-lib-item="${escapeHtml(item.id)}" ${vis ? 'checked' : ''} />
                <span class="slider"></span>
              </label>
            </div>
          </div>
          ${item.subtitle ? `<div class="gold-text muted-text">${escapeHtml(item.subtitle)}</div>` : ''}
          <p class="muted-text">${escapeHtml(preview)}${(item.content || '').length > 140 ? '…' : ''}</p>
          ${item.source_ref ? `<span class="muted-text">📚 المصدر: ${escapeHtml(item.source_ref)}</span>` : ''}
        </article>
      `;
    })
    .join('');
}
