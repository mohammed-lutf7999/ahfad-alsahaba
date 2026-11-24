import { escapeHtml } from '../core/ui_utils.js';

export function buildStoreTemplate() {
  return `
    <div class="two-col-grid">
      <section class="panel glass-card">
        <div class="panel-header-row">
          <h2 id="store-form-heading" class="panel-title">🛒 إضافة / تعديل عنصر متجر</h2>
          <button id="btn-reset-store-form" class="btn btn-outline btn-sm" type="button">عنصر جديد</button>
        </div>
        <p class="muted-text mb-md">يمكنك إخفاء العناصر غير المرغوبة بزر «إظهار/إخفاء»؛ ويبقى العنصر المخفي متاحاً لمن اشتراه فقط لحماية مقتنيات اللاعبين.</p>
        <form id="store-cms-form" class="stack-sm">
          <div class="form-row">
            <div class="form-group">
              <label class="field-label" for="st-id">المعرّف البرمجي (ID: أحرف/أرقام/_)</label>
              <input id="st-id" class="input ltr-input" type="text" placeholder="theme_andalusia_gold" pattern="[a-z0-9_]{3,64}" required />
            </div>
            <div class="form-group">
              <label class="field-label" for="st-category">التصنيف</label>
              <select id="st-category" class="input">
                <option value="title">لقب فارس (title)</option>
                <option value="theme">ثيم ملكي (theme)</option>
                <option value="frame">إطار متوهج (frame)</option>
                <option value="powerup">وسيلة مساعدة (powerup)</option>
              </select>
            </div>
          </div>
          <div class="form-group">
            <label class="field-label" for="st-title">الاسم المعروض للاعبين</label>
            <input id="st-title" class="input" type="text" placeholder="مثال: فارس النخبة أو إشراقة قرطبة" required />
          </div>
          <div class="form-group">
            <label class="field-label" for="st-desc">الوصف</label>
            <textarea id="st-desc" class="input" rows="2" placeholder="وصف مختصر يظهر داخل سوق الفرسان..."></textarea>
          </div>
          <div class="form-row-3">
            <div class="form-group">
              <label class="field-label" for="st-coins">السعر (دنانير)</label>
              <input id="st-coins" class="input" type="number" min="0" max="1000000" value="500" />
            </div>
            <div class="form-group">
              <label class="field-label" for="st-gems">السعر (ياقوت)</label>
              <input id="st-gems" class="input" type="number" min="0" max="100000" value="0" />
            </div>
            <div class="form-group">
              <label class="field-label" for="st-min-level">أدنى مستوى</label>
              <input id="st-min-level" class="input" type="number" min="1" max="100" value="1" />
            </div>
          </div>
          <div class="form-row">
            <div class="form-group">
              <label class="field-label" for="st-asset-key">مفتاح الأصل / النص الفعلي</label>
              <input id="st-asset-key" class="input" type="text" placeholder="يملأ تلقائياً إذا ترك فارغاً" />
            </div>
            <div class="form-group">
              <label class="field-label" for="st-sort">الترتيب (Sort)</label>
              <input id="st-sort" class="input" type="number" value="100" />
            </div>
          </div>

          <div id="store-meta-theme" class="sub-box hidden">
            <strong class="field-label">🎨 ألوان الثيم الديناميكي (5 ألوان)</strong>
            <div class="color-grid mt-xs">
              <label class="mini-color"><span>خلفية أساسية</span><input id="st-th-bg1" type="color" value="#1a0b2e" /></label>
              <label class="mini-color"><span>خلفية ثانوية</span><input id="st-th-bg2" type="color" value="#2d1b4e" /></label>
              <label class="mini-color"><span>بطاقة السطح</span><input id="st-th-card" type="color" value="#24143d" /></label>
              <label class="mini-color"><span>ذهبي سيادي</span><input id="st-th-gold" type="color" value="#f3c644" /></label>
              <label class="mini-color"><span>لون ثانوي</span><input id="st-th-sec" type="color" value="#38bdf8" /></label>
            </div>
          </div>

          <div id="store-meta-frame" class="sub-box hidden">
            <strong class="field-label">🖼️ خصائص الإطار الإجرائي</strong>
            <div class="color-grid mt-xs">
              <label class="mini-color"><span>اللون الأساسي</span><input id="st-fr-c1" type="color" value="#f3c644" /></label>
              <label class="mini-color"><span>اللون الثانوي</span><input id="st-fr-c2" type="color" value="#10b981" /></label>
              <label class="mini-color"><span>توهج الهالة</span><input id="st-fr-glow" type="color" value="#f3c644" /></label>
            </div>
            <div class="form-row mt-xs">
              <div class="form-group">
                <label class="field-label" for="st-fr-pattern">النمط</label>
                <select id="st-fr-pattern" class="input">
                  <option value="aurora">شفق (aurora)</option>
                  <option value="emerald">زمردي (emerald)</option>
                  <option value="imperial">إمبراطوري (imperial)</option>
                  <option value="celestial">سماوي (celestial)</option>
                  <option value="classic">كلاسيكي (classic)</option>
                </select>
              </div>
              <label class="inline-check mt-md">
                <input id="st-fr-gems" type="checkbox" checked />
                <span>ترصيع بجواهر زوايا</span>
              </label>
            </div>
          </div>

          <div id="store-meta-badge" class="sub-box">
            <div class="form-row">
              <div class="form-group">
                <label class="field-label" for="st-badge-color">لون الوسام / القدرة</label>
                <input id="st-badge-color" class="color-swatch" type="color" value="#f3c644" />
              </div>
              <div class="form-group">
                <label class="field-label" for="st-powerup-qty">الكمية / الوصف الرقمي (اختياري)</label>
                <input id="st-powerup-qty" class="input" type="number" min="1" placeholder="مثال: 1" />
              </div>
            </div>
          </div>

          <label class="inline-check">
            <input id="st-visible" type="checkbox" checked />
            <span>مرئي للجميع في المتجر فور الحفظ <code class="code-tag">is_visible</code></span>
          </label>
          <button id="btn-save-store-item" class="btn btn-gold btn-block" type="submit">
            <span>💾</span>
            <span>حفظ العنصر وتحديث المتجر</span>
          </button>
        </form>
      </section>

      <section class="stack-md">
        <div class="panel glass-card">
          <h2 class="panel-title">👁️ معاينة عنصر المتجر على الهاتف</h2>
          <div id="store-live-preview" class="preview-dialog"></div>
        </div>
        <div class="panel glass-card">
          <div class="panel-header-row">
            <h2 class="panel-title">🏪 قائمة عناصر المتجر السحابية</h2>
            <span id="store-count-pill" class="badge-pill">0</span>
          </div>
          <div class="quick-chips mb-md" id="store-filter-chips">
            <button class="chip-btn active" data-store-filter="all" type="button">الكل</button>
            <button class="chip-btn" data-store-filter="title" type="button">الألقاب</button>
            <button class="chip-btn" data-store-filter="theme" type="button">الثيمات</button>
            <button class="chip-btn" data-store-filter="frame" type="button">الأطر</button>
            <button class="chip-btn" data-store-filter="powerup" type="button">القدرات</button>
          </div>
          <div id="store-items-list" class="items-list"></div>
        </div>
      </section>
    </div>
  `;
}

export function renderStorePreviewHtml({ cat, title, desc, coins, gems, visible, meta }) {
  let visualHtml = '<div style="font-size:2rem;">🎖️</div>';
  let cardStyle = '';
  if (cat === 'theme') {
    cardStyle = `background:linear-gradient(145deg, ${meta.bg_primary}, ${meta.bg_secondary});border-color:${meta.sovereignAccent};`;
    visualHtml = `<span class="preview-badge" style="background:${meta.surfaceCard};color:${meta.sovereignAccent};border:1px solid ${meta.secondaryAccent};">معاينة الثيم الملكي</span>`;
  } else if (cat === 'frame') {
    visualHtml = `
      <div class="preview-frame-ring" style="border:3px solid ${meta.primaryColor};box-shadow:0 0 18px ${meta.highlightColor};background:linear-gradient(135deg, ${meta.primaryColor}22, ${meta.secondaryColor}33);">
        ${meta.hasCornerGems ? '💎' : '⚔️'}
      </div>
    `;
  } else {
    visualHtml = `<span class="preview-badge" style="background:${meta.previewColor}25;color:${meta.previewColor};border:1px solid ${meta.previewColor};">${cat === 'powerup' ? '⚡ قدرة' : '👑 وسام'}</span>`;
  }
  const priceTag = gems > 0 ? `💎 ${gems} ياقوتة` : `🪙 ${coins} دينار`;
  return `
    <div class="preview-dialog" style="${cardStyle}">
      ${visualHtml}
      <h3 style="margin:6px 0 4px;">${escapeHtml(title)}</h3>
      <p class="muted-text">${escapeHtml(desc)}</p>
      <div style="margin-top:10px;display:flex;justify-content:center;gap:8px;flex-wrap:wrap;">
        <span class="badge-pill">${priceTag}</span>
        <span class="${visible ? 'badge-visible' : 'badge-hidden'}">${visible ? 'مرئي بالمتجر' : 'مخفي عن الشراء'}</span>
      </div>
    </div>
  `;
}

export function renderStoreItemsHtml(items) {
  if (!items.length) {
    return '<p class="muted-text">لا توجد عناصر في هذا التصنيف حالياً.</p>';
  }
  return items
    .map((item) => {
      const vis = item.is_visible !== false;
      const priceStr =
        Number(item.price_gems || 0) > 0
          ? `💎 ${escapeHtml(item.price_gems)}`
          : `🪙 ${escapeHtml(item.price_coins ?? 0)}`;
      return `
        <article class="record-card">
          <div class="record-top">
            <div class="record-actions">
              <span class="badge-pill">${escapeHtml(item.category)}</span>
              <strong>${escapeHtml(item.title)}</strong>
              <span class="code-tag">${escapeHtml(item.id)}</span>
            </div>
            <div class="record-actions">
              <span class="${vis ? 'badge-visible' : 'badge-hidden'}">${vis ? 'مرئي' : 'مخفي'}</span>
              <button class="btn btn-outline btn-sm" type="button" data-edit-store="${escapeHtml(item.id)}">تعديل</button>
              <label class="switch" title="إظهار / إخفاء">
                <input type="checkbox" data-vis-store="${escapeHtml(item.id)}" ${vis ? 'checked' : ''} />
                <span class="slider"></span>
              </label>
            </div>
          </div>
          <p class="muted-text">${escapeHtml(item.description || '')}</p>
          <div class="record-actions muted-text">
            <span>${priceStr}</span>
            <span>المستوى: ${escapeHtml(item.min_level ?? 1)}</span>
            <span>مراجعة #${escapeHtml(item.cms_revision ?? 1)}</span>
          </div>
        </article>
      `;
    })
    .join('');
}
