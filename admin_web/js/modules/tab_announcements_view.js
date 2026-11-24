import { escapeHtml, formatDateDisplay, isValidPlayerCode } from '../core/ui_utils.js';

const QUICK_ROUTES = [
  { route: '/knights-store', cta: 'افتح المتجر', label: 'المتجر (/knights-store)' },
  { route: '/challenge', cta: 'ادخل الميدان', label: 'التحدي (/challenge)' },
  { route: '/glory-road', cta: 'طريق المجد', label: 'المجد (/glory-road)' },
  { route: '/library', cta: 'افتح المكتبة', label: 'المكتبة (/library)' },
  { route: '/inbox', cta: 'صندوق البريد', label: 'البريد (/inbox)' },
  { route: '/diwan', cta: 'ديوان الأحفاد', label: 'الديوان (/diwan)' },
  { route: '/guilds', cta: 'كتائب الفرسان', label: 'الكتائب (/guilds)' },
  { route: '/live-arena', cta: 'البطولات الحية', label: 'الساحات (/live-arena)' },
];

export const ANNOUNCEMENT_BADGE_STYLES = {
  normal: { label: 'إشعار 📢', color: '#38bdf8', bg: 'rgba(56,189,248,0.2)' },
  mandatory: { label: 'إشعار إلزامي ⚠️', color: '#e11d48', bg: 'rgba(225,29,72,0.24)' },
  admin: { label: 'رسالة إدارية 🛡️', color: '#f3c644', bg: 'rgba(243,198,68,0.18)' },
  motivational: { label: 'رسالة تحفيزية ✨', color: '#10b981', bg: 'rgba(16,185,129,0.2)' },
};

export function buildAnnouncementsTemplate() {
  const chipsHtml = QUICK_ROUTES.map(
    (r) => `<button class="chip-btn" data-ann-route="${r.route}" data-ann-cta="${r.cta}" type="button">${r.label}</button>`,
  ).join('');

  return `
    <div class="two-col-grid">
      <section class="panel glass-card">
        <h2 class="panel-title">✉️ إنشاء رسالة موجّهة</h2>
        <form id="announcement-form" class="stack-sm">
          <div class="form-row">
            <div class="form-group">
              <label class="field-label" for="ann-type">نوع الرسالة</label>
              <select id="ann-type" class="input">
                <option value="normal">عادية (normal)</option>
                <option value="mandatory">إجبارية مقفلة (mandatory)</option>
                <option value="admin">إدارية (admin)</option>
                <option value="motivational">تحفيزية (motivational)</option>
              </select>
            </div>
            <div class="form-group">
              <label class="field-label" for="ann-scope">نطاق الاستهداف</label>
              <select id="ann-scope" class="input">
                <option value="all">جميع اللاعبين (all)</option>
                <option value="single_user">لاعب محدد 🎯 (single_user)</option>
              </select>
            </div>
          </div>

          <div id="single-user-box" class="sub-box hidden">
            <label class="field-label" for="user-search-input">ابحث بالاسم أو البريد أو كود الضيف (SAH-XXXX)</label>
            <div class="search-row">
              <input id="user-search-input" class="input" type="text" placeholder="مثال: SAH-7K9M أو اسم اللاعب..." />
              <button id="btn-search-users" class="btn btn-outline btn-sm" type="button">بحث</button>
            </div>
            <label class="field-label mt-xs" for="manual-player-code">أو أدخل كود الضيف يدوياً (SAH-XXXX)</label>
            <input id="manual-player-code" class="input" type="text" placeholder="SAH-XXXX" />
            <div id="selected-player-banner" class="selected-pill hidden"></div>
            <div id="user-search-results" class="search-results"></div>
          </div>

          <div class="form-group">
            <label class="field-label" for="ann-title">عنوان الرسالة</label>
            <input id="ann-title" class="input" type="text" placeholder="عنوان واضح وجذاب..." required />
          </div>
          <div class="form-group">
            <label class="field-label" for="ann-body">نص الرسالة</label>
            <textarea id="ann-body" class="input" rows="3" placeholder="اكتب تفاصيل الرسالة هنا..." required></textarea>
          </div>
          <div class="form-row">
            <div class="form-group">
              <label class="field-label" for="ann-cta-label">نص زر الإجراء (اختياري)</label>
              <input id="ann-cta-label" class="input" type="text" placeholder="مثال: افتح المتجر" />
            </div>
            <div class="form-group">
              <label class="field-label" for="ann-cta-route">المسار أو الرابط (اختياري)</label>
              <input id="ann-cta-route" class="input" type="text" placeholder="/knights-store أو https://..." />
            </div>
          </div>
          <div class="quick-chips">${chipsHtml}</div>
          <div class="form-row">
            <div class="form-group">
              <label class="field-label" for="ann-min-ver">من رقم بناء (اختياري)</label>
              <input id="ann-min-ver" class="input" type="number" min="1" placeholder="مثال: 18" />
            </div>
            <div class="form-group">
              <label class="field-label" for="ann-max-ver">إلى رقم بناء (اختياري)</label>
              <input id="ann-max-ver" class="input" type="number" min="1" placeholder="مثال: 20" />
            </div>
          </div>
          <div class="form-row align-center">
            <div class="form-group">
              <label class="field-label" for="ann-expires-at">تاريخ انتهاء الصلاحية (اختياري)</label>
              <input id="ann-expires-at" class="input" type="datetime-local" />
            </div>
            <label class="inline-check">
              <input id="ann-locked" type="checkbox" />
              <span>منع الإغلاق العادي (قفل التخطي)</span>
            </label>
          </div>
          <button id="btn-publish-announcement" class="btn btn-gold btn-block" type="submit">
            <span>🚀</span>
            <span>إرسال ونشر الرسالة</span>
          </button>
        </form>
      </section>

      <section class="stack-md">
        <div class="panel glass-card">
          <h2 class="panel-title">👁️ معاينة نافذة الرسالة على هاتف اللاعب</h2>
          <div id="ann-live-preview" class="preview-dialog"></div>
        </div>
        <div class="panel glass-card">
          <div class="panel-header-row">
            <h2 class="panel-title">📜 سجل الرسائل المنشورة</h2>
            <span id="ann-count-pill" class="badge-pill">0</span>
          </div>
          <div id="announcements-list" class="items-list"></div>
        </div>
      </section>
    </div>
  `;
}

export function renderAnnouncementPreviewHtml({ type, scope, title, body, ctaLabel, ctaRoute, isLocked }) {
  const style = ANNOUNCEMENT_BADGE_STYLES[type] || ANNOUNCEMENT_BADGE_STYLES.normal;
  return {
    borderColor: style.color,
    html: `
      <span class="preview-badge" style="color:${style.color};background:${style.bg};">
        ${escapeHtml(style.label)}${scope === 'single_user' ? ' • موجهة لك' : ''}
      </span>
      <h3 style="margin:4px 0 6px;font-size:1.05rem;">${escapeHtml(title)}</h3>
      <p class="muted-text" style="margin-bottom:14px;">${escapeHtml(body)}</p>
      ${ctaLabel && ctaRoute ? `<div class="btn btn-gold btn-block btn-sm" style="margin-bottom:8px;">${escapeHtml(ctaLabel)}</div>` : ''}
      <div class="btn btn-outline btn-block btn-sm">${isLocked ? 'فهمت وأوافق' : 'حسناً'}</div>
    `,
  };
}

export function renderUserSearchResultsHtml(results) {
  if (!results.length) return '<p class="muted-text">لم يُعثر على لاعبين مطابقين.</p>';
  return results
    .map((p, idx) => {
      const targetable = Boolean(p.user_id) || isValidPlayerCode(p.player_code);
      const roleLabel = p.is_guest ? 'ضيف 🎭' : escapeHtml(p.email || 'حساب Google');
      const codeLabel = p.player_code ? ` • ${escapeHtml(p.player_code)}` : '';
      return `
        <button type="button" class="search-item" data-pick-index="${idx}" ${targetable ? '' : 'disabled'}>
          <div>
            <strong>${escapeHtml(p.display_name || 'لاعب')}</strong>
            <div class="muted-text">${roleLabel}${codeLabel} • 🏆 ${escapeHtml(p.trophies ?? 1000)}</div>
          </div>
          <span class="gold-text">${targetable ? 'اختيار' : 'بلا معرّف'}</span>
        </button>
      `;
    })
    .join('');
}

export function renderAnnouncementsListHtml(announcements) {
  if (!announcements.length) return '<p class="muted-text">لا توجد رسائل منشورة حالياً.</p>';
  return announcements
    .map((ann) => {
      const targetText =
        ann.target_scope === 'single_user'
          ? `موجهة: ${escapeHtml(ann.target_player_code || ann.target_user_id || 'لاعب')}`
          : 'للجميع';
      const versionMeta =
        ann.min_version_code || ann.max_version_code
          ? `<span>البناء: ${escapeHtml(ann.min_version_code ?? 1)}..${escapeHtml(ann.max_version_code ?? '∞')}</span>`
          : '';
      const expiryMeta = ann.expires_at
        ? `<span class="gold-text">ينتهي: ${escapeHtml(formatDateDisplay(ann.expires_at))}</span>`
        : '';
      const routeMeta = ann.cta_route ? `<span class="sky-text">المسار: ${escapeHtml(ann.cta_route)}</span>` : '';
      return `
        <article class="record-card">
          <div class="record-top">
            <div class="record-actions">
              <span class="badge-pill">${escapeHtml(ann.message_type)}</span>
              <span class="muted-text">${targetText}</span>
            </div>
            <div class="record-actions">
              <span class="muted-text">👁️ ${escapeHtml(ann.receipt_count ?? 0)}</span>
              <label class="switch">
                <input type="checkbox" data-toggle-ann="${escapeHtml(ann.id)}" ${ann.is_active ? 'checked' : ''} />
                <span class="slider"></span>
              </label>
            </div>
          </div>
          <strong>${escapeHtml(ann.title)}</strong>
          <p class="muted-text">${escapeHtml(ann.body)}</p>
          <div class="record-actions muted-text">${versionMeta} ${expiryMeta} ${routeMeta}</div>
        </article>
      `;
    })
    .join('');
}
