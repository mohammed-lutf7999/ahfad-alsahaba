import { escapeHtml, formatDateDisplay } from '../core/ui_utils.js';

export function buildPlayersTemplate() {
  return `
    <div class="two-col-grid">
      <section class="panel glass-card">
        <div class="panel-header-row">
          <h2 class="panel-title">🔍 البحث عن لاعب وتصدير السجل</h2>
          <button id="btn-export-players-csv" class="btn btn-outline btn-sm" type="button">📥 تصدير CSV</button>
        </div>
        <div class="search-row mb-md">
          <input id="player-inspector-query" class="input" type="text" placeholder="اسم، بريد إلكتروني، كود SAH-XXXX أو اتركه فارغاً لأحدث اللاعبين..." />
          <button id="btn-inspector-search" class="btn btn-gold btn-sm" type="button">بحث</button>
        </div>
        <div id="inspector-results-list" class="items-list"></div>
      </section>

      <section class="stack-md">
        <div class="panel glass-card">
          <div class="panel-header-row">
            <h2 class="panel-title">🪪 بطاقة ملف اللاعب التفصيلية</h2>
            <button id="btn-target-player-msg" class="btn btn-outline btn-sm hidden" type="button">✉️ مراسلة هذا اللاعب</button>
          </div>
          <div id="player-dossier-card" class="muted-text">اختر أي لاعب من قائمة البحث لعرض محفظته، مخزونه، وآخر 10 نزالات.</div>
        </div>

        <div class="panel glass-card">
          <h2 class="panel-title">🎁 منح تعويض آمن بسقف رقابي</h2>
          <p class="muted-text mb-md">الحدود القصوى للمعاملة الواحدة: 10,000 دينار، 100 ياقوتة، 5,000 نقطة خبرة مع توثيق السبب إلزامياً.</p>
          <form id="compensation-form" class="stack-sm">
            <input id="comp-user-id" type="hidden" />
            <div id="comp-target-label" class="selected-pill hidden"></div>
            <div class="form-row-3">
              <div class="form-group">
                <label class="field-label" for="comp-coins">دنانير (0..10000)</label>
                <input id="comp-coins" class="input" type="number" min="0" max="10000" value="0" />
              </div>
              <div class="form-group">
                <label class="field-label" for="comp-gems">ياقوت (0..100)</label>
                <input id="comp-gems" class="input" type="number" min="0" max="100" value="0" />
              </div>
              <div class="form-group">
                <label class="field-label" for="comp-xp">خبرة XP (0..5000)</label>
                <input id="comp-xp" class="input" type="number" min="0" max="5000" value="0" />
              </div>
            </div>
            <div class="form-group">
              <label class="field-label" for="comp-reason">سبب التعويض (إلزامي للتدقيق)</label>
              <input id="comp-reason" class="input" type="text" minlength="3" placeholder="مثال: تعويض عن انقطاع نزال أونلاين #..." required />
            </div>
            <button id="btn-grant-compensation" class="btn btn-gold btn-block" type="submit" disabled>منح التعويض وتسجيله في التدقيق</button>
          </form>
        </div>

        <div class="panel glass-card">
          <h2 class="panel-title">🛡️ الصلاحيات والحظر الفردي</h2>
          <p class="muted-text mb-md">التحكم في حظر اللاعب، منعه من الديوان/الكتائب/الأونلاين، أو تفويض استضافة البطولات.</p>
          <form id="player-permissions-form" class="stack-sm">
            <input id="perm-user-id" type="hidden" />
            <div class="switch-row">
              <div>
                <strong>حظر الحساب بالكامل 🚫</strong>
                <p class="muted-text">منع اللاعب من تسجيل الدخول والمشاركة</p>
              </div>
              <label class="switch">
                <input id="perm-is-banned" type="checkbox" />
                <span class="slider"></span>
              </label>
            </div>
            <div class="form-row">
              <div class="form-group">
                <label class="field-label" for="perm-ban-duration">مدة الحظر</label>
                <select id="perm-ban-duration" class="input">
                  <option value="24">24 ساعة (يوم)</option>
                  <option value="168">7 أيام (أسبوع)</option>
                  <option value="720">30 يوماً (شهر)</option>
                  <option value="permanent">حظر دائم ⛔</option>
                </select>
              </div>
              <div class="form-group">
                <label class="field-label" for="perm-ban-reason">سبب الحظر</label>
                <input id="perm-ban-reason" class="input" type="text" placeholder="سبب الحظر الظاهر للاعب..." />
              </div>
            </div>
            <div class="switch-row">
              <div><strong>المعارك الجماعية أونلاين ⚔️</strong></div>
              <label class="switch"><input id="perm-can-online" type="checkbox" checked /><span class="slider"></span></label>
            </div>
            <div class="switch-row">
              <div><strong>ديوان الأحفاد والمحادثة 💬</strong></div>
              <label class="switch"><input id="perm-can-diwan" type="checkbox" checked /><span class="slider"></span></label>
            </div>
            <div class="switch-row">
              <div><strong>الكتائب والمساهمة 🛡️</strong></div>
              <label class="switch"><input id="perm-can-guilds" type="checkbox" checked /><span class="slider"></span></label>
            </div>
            <div class="form-group">
              <label class="field-label" for="perm-host-arena">استضافة البطولات الحية (Live Arena)</label>
              <select id="perm-host-arena" class="input">
                <option value="inherit">حسب السياسة العامة (افتراضي)</option>
                <option value="allowed">تفويض معلم — مسموح دائماً 🎓</option>
                <option value="denied">ممنوع فردياً 🚫</option>
              </select>
            </div>
            <div id="player-diwan-mute-box" class="selected-pill hidden">
              <span>اللاعب مكتوم في الديوان</span>
              <button id="btn-quick-unmute-web" class="btn btn-outline btn-sm" type="button">فك الكتم 🕊️</button>
            </div>
            <div class="form-group">
              <label class="field-label" for="perm-notes">ملاحظات إدارية سرية</label>
              <input id="perm-notes" class="input" type="text" placeholder="ملاحظات المشرفين (لا تظهر للاعب)..." />
            </div>
            <button id="btn-save-player-perms" class="btn btn-gold btn-block" type="submit" disabled>حفظ الصلاحيات والحظر</button>
          </form>
        </div>
      </section>
    </div>
  `;
}

export function renderInspectorListHtml(rows) {
  if (!rows.length) return '<p class="muted-text">لا توجد نتائج مطابقة.</p>';
  return rows
    .map((p, idx) => {
      const badge = p.is_guest ? 'ضيف 🎭' : escapeHtml(p.email || 'Google');
      return `
        <article class="record-card">
          <div class="record-top">
            <div>
              <strong>${escapeHtml(p.display_name || 'لاعب')}</strong>
              <div class="muted-text">${badge} ${p.player_code ? `• ${escapeHtml(p.player_code)}` : ''}</div>
            </div>
            <button class="btn btn-outline btn-sm" type="button" data-open-dossier="${idx}">فحص الملف</button>
          </div>
          <div class="record-actions muted-text">
            <span>🏆 ${escapeHtml(p.trophies ?? 1000)}</span>
            <span>⭐ م${escapeHtml(p.player_level ?? 1)}</span>
            <span>نقاط ${escapeHtml(p.total_score ?? 0)}</span>
            <span>${escapeHtml(p.app_version || '—')}</span>
          </div>
        </article>
      `;
    })
    .join('');
}

export function renderPlayerDossierHtml(d, name) {
  const dir = d?.directory || {};
  const prog = d?.progress || {};
  const lb = d?.leaderboard || {};
  const inv = Array.isArray(d?.inventory) ? d.inventory : [];
  const matches = Array.isArray(d?.recent_matches) ? d.recent_matches : [];

  const invHtml = inv.length
    ? inv
        .map((i) => `<span class="code-tag">${escapeHtml(i.title || i.item_id)}${i.is_visible === false ? ' (مخفي)' : ''}</span>`)
        .join(' ')
    : '<span class="muted-text">لا توجد مقتنيات متجر مسجلة</span>';

  const matchesHtml = matches.length
    ? matches
        .slice(0, 5)
        .map(
          (m) =>
            `<div class="muted-text">• ${m.is_ghost_match ? '👻' : '⚔️'} نتيجة ${escapeHtml(m.my_score ?? 0)} (${escapeHtml(m.status)}) — ${escapeHtml(formatDateDisplay(m.created_at))}</div>`,
        )
        .join('')
    : '<div class="muted-text">لا توجد نزالات حديثة</div>';

  return `
    <div><strong>${escapeHtml(name)}</strong> ${d?.player_code ? `<span class="code-tag">${escapeHtml(d.player_code)}</span>` : ''}</div>
    <div class="muted-text">${escapeHtml(dir.email || lb.email || 'ضيف محلي')} • آخر ظهور: ${escapeHtml(formatDateDisplay(dir.last_seen_at))} • نسخة ${escapeHtml(dir.app_version || '—')} (b${escapeHtml(dir.version_code ?? '?')})</div>
    <div class="dossier-grid">
      <div class="stat-chip"><span class="muted-text">المستوى</span><strong>م${escapeHtml(prog.player_level ?? lb.player_level ?? 1)}</strong></div>
      <div class="stat-chip"><span class="muted-text">النقاط XP</span><strong>${escapeHtml(prog.total_score ?? lb.score ?? 0)}</strong></div>
      <div class="stat-chip"><span class="muted-text">الكؤوس</span><strong>🏆 ${escapeHtml(lb.trophies ?? dir.trophies ?? 1000)}</strong></div>
      <div class="stat-chip"><span class="muted-text">الدنانير</span><strong>🪙 ${escapeHtml(prog.coins ?? 0)}</strong></div>
      <div class="stat-chip"><span class="muted-text">الياقوت</span><strong>💎 ${escapeHtml(prog.gems ?? 0)}</strong></div>
      <div class="stat-chip"><span class="muted-text">السلسلة</span><strong>🔥 ${escapeHtml(prog.win_streak ?? 0)}</strong></div>
    </div>
    <div class="mb-md"><strong>المقتنيات (${inv.length}):</strong><div class="record-actions mt-xs">${invHtml}</div></div>
    <div><strong>آخر النزالات:</strong>${matchesHtml}</div>
  `;
}
