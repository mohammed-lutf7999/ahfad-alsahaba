import { ICON_EMOJI_MAP } from '../core/config.js';
import { escapeHtml, safeHexColor } from '../core/ui_utils.js';

const EVENT_ICONS = [
  ['auto_awesome', 'نجم متلألئ (auto_awesome)'],
  ['mosque', 'مسجد (mosque)'],
  ['stars', 'نجوم (stars)'],
  ['celebration', 'احتفال (celebration)'],
  ['military_tech', 'وسام (military_tech)'],
  ['emoji_events', 'كأس (emoji_events)'],
  ['campaign', 'مكبر إعلان (campaign)'],
  ['bolt', 'صاعقة (bolt)'],
  ['castle', 'قلعة (castle)'],
  ['menu_book', 'كتاب (menu_book)'],
  ['shield', 'درع (shield)'],
];

export function buildEventsTemplate() {
  const iconOptions = EVENT_ICONS.map(([v, label]) => `<option value="${v}">${label}</option>`).join('');
  return `
    <div class="two-col-grid">
      <section class="panel glass-card">
        <div class="panel-header-row">
          <h2 id="event-form-heading" class="panel-title">🌟 إنشاء حدث ديناميكي جديد</h2>
          <button id="btn-cancel-event-edit" class="btn btn-outline btn-sm hidden" type="button">إلغاء التعديل</button>
        </div>
        <form id="event-form" class="stack-sm">
          <div class="form-row">
            <div class="form-group">
              <label class="field-label" for="ev-badge">نص الشارة</label>
              <input id="ev-badge" class="input" type="text" value="موسم نشط الآن" required />
            </div>
            <div class="form-group">
              <label class="field-label" for="ev-priority">الأولوية (الأعلى أولاً)</label>
              <input id="ev-priority" class="input" type="number" value="100" required />
            </div>
          </div>
          <div class="form-group">
            <label class="field-label" for="ev-title">عنوان الحدث</label>
            <input id="ev-title" class="input" type="text" placeholder="مثال: موسم غزوات بدر والفتح" required />
          </div>
          <div class="form-group">
            <label class="field-label" for="ev-subtitle">العنوان الفرعي (اختياري)</label>
            <input id="ev-subtitle" class="input" type="text" placeholder="سطر تعريفي يظهر أسفل العنوان..." />
          </div>
          <div class="form-group">
            <label class="field-label" for="ev-body">النص التفصيلي في صفحة الحدث</label>
            <textarea id="ev-body" class="input" rows="3" placeholder="تفاصيل الفعالية وجوائزها..."></textarea>
          </div>
          <div class="form-row">
            <div class="form-group">
              <label class="field-label" for="ev-action-type">نوع الإجراء عند النقر</label>
              <select id="ev-action-type" class="input">
                <option value="open_event_screen">فتح صفحة الحدث (open_event_screen)</option>
                <option value="navigate_route">مسار داخلي (navigate_route)</option>
                <option value="open_url">رابط خارجي (open_url)</option>
                <option value="none">عرض فقط (none)</option>
              </select>
            </div>
            <div class="form-group">
              <label class="field-label" for="ev-cta-label">نص الزر</label>
              <input id="ev-cta-label" class="input" type="text" value="اكتشف الآن" />
            </div>
          </div>
          <div class="form-group" id="ev-target-wrap">
            <label class="field-label" for="ev-action-target">الهدف (مسار داخلي مثل /challenge أو رابط https://)</label>
            <input id="ev-action-target" class="input" type="text" placeholder="/challenge أو https://..." />
          </div>
          <div class="form-row">
            <div class="form-group">
              <label class="field-label" for="ev-color">اللون السداسي (Hex)</label>
              <div class="color-row">
                <input id="ev-color" class="input" type="text" value="#D4AF37" />
                <input id="ev-color-picker" class="color-swatch" type="color" value="#d4af37" />
              </div>
            </div>
            <div class="form-group">
              <label class="field-label" for="ev-icon">أيقونة الحدث</label>
              <select id="ev-icon" class="input">${iconOptions}</select>
            </div>
          </div>
          <div class="form-row">
            <div class="form-group">
              <label class="field-label" for="ev-starts-at">وقت البدء (اختياري)</label>
              <input id="ev-starts-at" class="input" type="datetime-local" />
            </div>
            <div class="form-group">
              <label class="field-label" for="ev-ends-at">وقت الانتهاء (اختياري)</label>
              <input id="ev-ends-at" class="input" type="datetime-local" />
            </div>
          </div>
          <label class="inline-check">
            <input id="ev-is-active" type="checkbox" checked />
            <span>تفعيل الحدث فور النشر <code class="code-tag">is_active</code></span>
          </label>
          <button id="btn-save-event" class="btn btn-gold btn-block" type="submit">
            <span>🎉</span>
            <span id="btn-save-event-text">نشر الحدث الآن</span>
          </button>
        </form>
      </section>

      <section class="stack-md">
        <div class="panel glass-card">
          <h2 class="panel-title">👁️ معاينة شريط الحدث على الشاشة الرئيسية</h2>
          <div id="event-live-preview"></div>
        </div>
        <div class="panel glass-card">
          <div class="panel-header-row">
            <h2 class="panel-title">📅 قائمة الأحداث المسجّلة</h2>
            <span id="ev-count-pill" class="badge-pill">0</span>
          </div>
          <div id="events-list" class="items-list"></div>
        </div>
      </section>
    </div>
  `;
}

export function renderEventPreviewHtml({ badge, title, subtitle, cta, actionType, hex, icon }) {
  return `
    <div class="preview-banner" style="border-color:${hex};background:linear-gradient(90deg, ${hex}33, rgba(0,0,0,0.45));">
      <div style="display:flex;align-items:center;gap:10px;min-width:0;">
        <div style="width:40px;height:40px;border-radius:12px;display:grid;place-items:center;background:${hex}2e;border:1px solid ${hex}88;flex-shrink:0;">${icon}</div>
        <div style="min-width:0;">
          <span class="preview-badge" style="color:${hex};background:${hex}2e;margin-bottom:2px;">${escapeHtml(badge)}</span>
          <div style="font-weight:800;font-size:0.92rem;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${escapeHtml(title)}</div>
          <div class="muted-text" style="white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${escapeHtml(subtitle)}</div>
        </div>
      </div>
      ${actionType !== 'none' ? `<span class="btn btn-sm" style="background:${hex};color:#0d061a;flex-shrink:0;">${escapeHtml(cta)}</span>` : ''}
    </div>
  `;
}

export function renderEventsListHtml(events) {
  if (!events.length) return '<p class="muted-text">لا توجد أحداث ديناميكية حالياً.</p>';
  const now = Date.now();
  return events
    .map((ev) => {
      const hex = safeHexColor(ev.theme_color_hex);
      const startOk = !ev.starts_at || new Date(ev.starts_at).getTime() <= now;
      const endOk = !ev.ends_at || new Date(ev.ends_at).getTime() > now;
      const statusLabel = !ev.is_active ? 'متوقف ⏸️' : startOk && endOk ? 'مباشر الآن 🟢' : !startOk ? 'مجدول ⏳' : 'منتهٍ ⛔';
      return `
        <article class="record-card" style="border-color:${hex};">
          <div class="record-top">
            <div>
              <strong>${ICON_EMOJI_MAP[ev.icon_name] ?? '✨'} ${escapeHtml(ev.title)}</strong>
              <div class="muted-text">${statusLabel} • أولوية ${escapeHtml(ev.priority ?? 100)}</div>
            </div>
            <label class="switch">
              <input type="checkbox" data-toggle-event="${escapeHtml(ev.id)}" ${ev.is_active ? 'checked' : ''} />
              <span class="slider"></span>
            </label>
          </div>
          <div class="record-actions">
            <button class="btn btn-outline btn-sm" data-edit-event="${escapeHtml(ev.id)}" type="button">✏️ تعديل</button>
            <button class="btn btn-danger-outline btn-sm" data-delete-event="${escapeHtml(ev.id)}" type="button">🗑️ حذف</button>
          </div>
        </article>
      `;
    })
    .join('');
}
