import { escapeHtml } from '../core/ui_utils.js';

export function buildLevelManagerTemplate() {
  return `
    <section class="stack-md">
      <div class="panel glass-card">
        <div class="panel-header-row">
          <h2 class="panel-title">⏳ حالة توفر القسم بالكامل</h2>
          <select id="lvl-mgr-cat" class="input compact-select"></select>
        </div>

        <div id="lvl-mgr-republish-banner" class="warning-banner hidden">
          <span>⚠️ الحزمة السحابية لهذا القسم بحاجة لإعادة نشر Gzip CDN بعد التعديلات الأخيرة.</span>
          <button id="btn-lvl-jump-publish" class="btn btn-gold btn-sm" type="button">انتقال لنشر الحزمة</button>
        </div>

        <form id="lvl-mgr-cat-form" class="stack-sm">
          <div class="form-row">
            <div class="form-group">
              <label class="field-label" for="lvl-mgr-cat-status">حالة القسم</label>
              <select id="lvl-mgr-cat-status" class="input">
                <option value="open">🟢 مفتوح للعب (open)</option>
                <option value="coming_soon">⏳ قريباً (coming_soon)</option>
                <option value="hidden">🚫 مخفي تماماً (hidden)</option>
              </select>
            </div>
            <div class="form-group">
              <label class="field-label" for="lvl-mgr-cat-msg">رسالة تشويقية (اختياري عند قريباً)</label>
              <input id="lvl-mgr-cat-msg" class="input" type="text" maxlength="180" placeholder="مثال: قسم جديد يُطلق مطلع رمضان بإذن الله ⏳" />
            </div>
          </div>
          <button id="btn-lvl-save-cat" class="btn btn-gold btn-block" type="submit">حفظ حالة القسم</button>
        </form>
      </div>

      <div class="panel glass-card">
        <div class="panel-header-row">
          <h2 class="panel-title">🎚️ تحديث نطاق مستويات دفعة واحدة</h2>
          <span id="lvl-mgr-range-hint" class="badge-pill">1..10</span>
        </div>
        <form id="lvl-mgr-range-form" class="stack-sm">
          <div class="form-row-3">
            <div class="form-group">
              <label class="field-label" for="lvl-mgr-from">من مستوى</label>
              <input id="lvl-mgr-from" class="input" type="number" min="1" max="100" value="1" required />
            </div>
            <div class="form-group">
              <label class="field-label" for="lvl-mgr-to">إلى مستوى</label>
              <input id="lvl-mgr-to" class="input" type="number" min="1" max="100" value="10" required />
            </div>
            <div class="form-group">
              <label class="field-label" for="lvl-mgr-range-status">الحالة المطلوبة</label>
              <select id="lvl-mgr-range-status" class="input">
                <option value="open">🟢 مفتوح (open)</option>
                <option value="coming_soon">⏳ قريباً (coming_soon)</option>
                <option value="hidden">🚫 مخفي (hidden)</option>
              </select>
            </div>
          </div>
          <div class="form-group">
            <label class="field-label" for="lvl-mgr-range-msg">رسالة تشويقية للمستويات (اختياري)</label>
            <input id="lvl-mgr-range-msg" class="input" type="text" maxlength="160" placeholder="تظهر عند النقر على المستوى الموسوم قريباً ⏳" />
          </div>
          <button id="btn-lvl-apply-range" class="btn btn-outline btn-block" type="submit">تطبيق على النطاق المحدد</button>
        </form>
      </div>
    </section>

    <section class="stack-md">
      <div class="panel glass-card">
        <div class="panel-header-row">
          <h2 class="panel-title">🗺️ شبكة المستويات التفاعلية</h2>
          <span id="lvl-mgr-summary" class="badge-pill">0 مستوى</span>
        </div>
        <p class="muted-text mb-sm">
          انقر على أي مستوى للتبديل السريع بين: <strong>مفتوح 🟢</strong> ← <strong>قريباً ⏳</strong> ← <strong>مخفي 🚫</strong>.
        </p>
        <div id="lvl-mgr-grid" class="level-pills-grid"></div>
      </div>
    </section>
  `;
}

export function renderLevelGridHtml(category) {
  if (!category) {
    return '<p class="muted-text">اختر قسماً لعرض مستوياته وإدارة حالتها.</p>';
  }
  const baseTotal = Math.max(1, Math.min(100, Number(category.total_levels || 10)));
  const overrides = category.level_overrides && typeof category.level_overrides === 'object'
    ? category.level_overrides
    : {};
  let maxOverrideLevel = 0;
  Object.keys(overrides).forEach((k) => {
    const lv = Number.parseInt(k, 10);
    if (Number.isFinite(lv) && lv > maxOverrideLevel) maxOverrideLevel = lv;
  });
  const total = Math.max(baseTotal, Math.min(100, maxOverrideLevel));

  const items = [];
  for (let lv = 1; lv <= total; lv += 1) {
    const ov = overrides[String(lv)] || {};
    const status = ov.status === 'coming_soon' || ov.status === 'hidden' ? ov.status : 'open';
    const msg = ov.message ? ` — ${ov.message}` : '';
    const icon = status === 'coming_soon' ? '⏳' : status === 'hidden' ? '🚫' : '🟢';
    const label = status === 'coming_soon' ? 'قريباً' : status === 'hidden' ? 'مخفي' : 'مفتوح';
    items.push(`
      <button
        type="button"
        class="level-pill level-pill-${status}"
        data-level-num="${lv}"
        data-level-status="${status}"
        title="المستوى ${lv}: ${label}${escapeHtml(msg)}"
      >
        <span class="level-pill-num">${lv}</span>
        <span class="level-pill-state">${icon} ${label}</span>
      </button>
    `);
  }
  return items.join('');
}
