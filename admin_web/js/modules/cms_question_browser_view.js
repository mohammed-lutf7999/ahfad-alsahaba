import { escapeHtml } from '../core/ui_utils.js';

export function buildQuestionBrowserTemplate() {
  return `
    <section class="stack-md">
      <div class="panel glass-card">
        <div class="panel-header-row">
          <h2 class="panel-title">🔍 متصفح الأسئلة السحابية والإدارة الجماعية</h2>
          <span id="qb-total-badge" class="badge-pill">0 سؤال</span>
        </div>

        <div class="info-banner mb-sm">
          ℹ️ تعرض هذه القائمة الأسئلة السحابية المحفوظة في جدول <code class="code-tag">quiz_questions</code>.
          الأسئلة المدمجة في أصول التطبيق (المستويات 1–10) يمكن إخفاؤها أو إظهارها فورياً بالمعرّف من الأداة الجانبية دون استيراد.
        </div>

        <div id="qb-republish-banner" class="warning-banner hidden mb-sm">
          <span>⚠️ الحزمة السحابية لهذا القسم بحاجة لإعادة نشر Gzip CDN بعد التعديلات الأخيرة.</span>
          <button id="btn-qb-jump-publish" class="btn btn-gold btn-sm" type="button">نشر الحزمة الآن</button>
        </div>

        <div class="form-row-3 mb-sm">
          <div class="form-group">
            <label class="field-label" for="qb-filter-cat">القسم</label>
            <select id="qb-filter-cat" class="input"></select>
          </div>
          <div class="form-group">
            <label class="field-label" for="qb-filter-level">المستوى (اختياري)</label>
            <input id="qb-filter-level" class="input" type="number" min="1" max="100" placeholder="كل المستويات" />
          </div>
          <div class="form-group">
            <label class="field-label" for="qb-filter-vis">الحالة</label>
            <select id="qb-filter-vis" class="input">
              <option value="all">الكل (مرئي + مخفي)</option>
              <option value="visible">المرئية فقط</option>
              <option value="hidden">المخفية فقط</option>
            </select>
          </div>
        </div>

        <div class="form-row mb-sm">
          <div class="form-group">
            <label class="field-label" for="qb-filter-search">بحث في نص السؤال أو الشرح</label>
            <input id="qb-filter-search" class="input" type="text" placeholder="ابحث بكلمة مفتاحية..." />
          </div>
          <div class="form-group" style="align-self:end;">
            <button id="btn-qb-search" class="btn btn-gold btn-block" type="button">بحث وتحديث</button>
          </div>
        </div>

        <div class="sub-box stack-sm mb-sm">
          <div class="panel-header-row">
            <strong>⚡ إجراءات جماعية (على المحدد أو نطاق مستويات)</strong>
            <span id="qb-selected-count" class="code-tag">المحدد: 0</span>
          </div>
          <div class="form-row-3">
            <div class="form-group">
              <label class="field-label" for="qb-bulk-action">الإجراء</label>
              <select id="qb-bulk-action" class="input">
                <option value="hide">إخفاء الأسئلة (hide)</option>
                <option value="show">إظهار الأسئلة (show)</option>
                <option value="move_level">نقل إلى مستوى آخر (move_level)</option>
                <option value="delete">حذف نهائي (delete)</option>
              </select>
            </div>
            <div class="form-group">
              <label class="field-label" for="qb-bulk-from">نطاق: من مستوى</label>
              <input id="qb-bulk-from" class="input" type="number" min="1" max="100" placeholder="اختياري" />
            </div>
            <div class="form-group">
              <label class="field-label" for="qb-bulk-to">إلى مستوى</label>
              <input id="qb-bulk-to" class="input" type="number" min="1" max="100" placeholder="اختياري" />
            </div>
          </div>
          <div class="form-row">
            <div id="qb-target-level-wrap" class="form-group hidden">
              <label class="field-label" for="qb-bulk-target-level">المستوى الهدف للنقل</label>
              <input id="qb-bulk-target-level" class="input" type="number" min="1" max="100" value="1" />
            </div>
            <div class="record-actions" style="align-self:end;">
              <button id="btn-qb-select-all" class="btn btn-outline btn-sm" type="button">تحديد الصفحة</button>
              <button id="btn-qb-clear-sel" class="btn btn-outline btn-sm" type="button">إلغاء التحديد</button>
              <button id="btn-qb-run-bulk" class="btn btn-gold btn-sm" type="button">تنفيذ الإجراء الجماعي</button>
            </div>
          </div>
        </div>

        <div id="qb-list" class="items-list"></div>

        <div class="panel-header-row mt-sm">
          <button id="btn-qb-prev" class="btn btn-outline btn-sm" type="button">السابق</button>
          <span id="qb-page-info" class="muted-text">صفحة 1 من 1</span>
          <button id="btn-qb-next" class="btn btn-outline btn-sm" type="button">التالي</button>
        </div>
      </div>
    </section>

    <section class="stack-md">
      <div class="panel glass-card">
        <div class="panel-header-row">
          <h2 class="panel-title">🛡️ إخفاء / إظهار سؤال محلي بالمعرّف</h2>
          <span id="qb-local-count" class="badge-pill">0</span>
        </div>
        <p class="muted-text mb-sm">
          لإخفاء سؤال مدمج من المستويات (1–10) فورياً بـ 0ms عبر <code class="code-tag">hidden_question_ids</code>، أدخل معرّف السؤال (مثل <code class="code-tag">q1_1</code> أو <code class="code-tag">a1_3</code>) واختر القسم.
        </p>
        <form id="qb-local-hide-form" class="stack-sm">
          <div class="form-group">
            <label class="field-label" for="qb-local-id">معرّف السؤال المحلي</label>
            <input id="qb-local-id" class="input ltr-input" type="text" placeholder="مثال: q1_1 أو a1_3" required />
          </div>
          <button id="btn-qb-local-hide" class="btn btn-outline btn-block" type="submit">إخفاء هذا السؤال المحلي</button>
        </form>
        <div id="qb-local-list" class="items-list compact-list mt-sm"></div>
      </div>
    </section>
  `;
}

export function renderBrowserQuestionsHtml(questions, selectedSet) {
  if (!questions.length) {
    return '<p class="muted-text">لا توجد أسئلة سحابية مطابقة لمعايير البحث الحالية.</p>';
  }
  return questions
    .map((q) => {
      const vis = q.is_visible !== false;
      const checked = selectedSet.has(q.id) ? 'checked' : '';
      const opts = Array.isArray(q.options) ? q.options : [];
      const ans = opts[q.correct_index] ?? '';
      return `
        <article class="record-card">
          <div class="record-top">
            <div class="record-actions">
              <input type="checkbox" data-qb-select="${escapeHtml(q.id)}" ${checked} />
              <span class="badge-pill">${escapeHtml(q.category_id)} • م${escapeHtml(q.level_number)}</span>
              <span class="code-tag">${escapeHtml(q.id)}</span>
            </div>
            <div class="record-actions">
              <span class="${vis ? 'badge-visible' : 'badge-hidden'}">${vis ? 'مرئي' : 'مخفي'}</span>
              <button class="btn btn-outline btn-sm" type="button" data-qb-toggle="${escapeHtml(q.id)}" data-qb-next="${vis ? 'false' : 'true'}">${vis ? 'إخفاء' : 'إظهار'}</button>
              <button class="btn btn-danger btn-sm" type="button" data-qb-delete="${escapeHtml(q.id)}">حذف</button>
            </div>
          </div>
          <strong>${escapeHtml(q.question_text)}</strong>
          <div class="muted-text">✅ الصحيح (${escapeHtml(q.correct_index)}): ${escapeHtml(ans)}</div>
        </article>
      `;
    })
    .join('');
}

export function renderHiddenLocalIdsHtml(hiddenIds) {
  if (!hiddenIds.length) {
    return '<p class="muted-text">لا توجد أسئلة محلية مخفية في القسم المحدد.</p>';
  }
  return hiddenIds
    .map((id) => `
      <div class="record-card">
        <div class="record-top">
          <span class="code-tag">${escapeHtml(id)}</span>
          <button class="btn btn-outline btn-sm" type="button" data-qb-unhide-local="${escapeHtml(id)}">إظهار مجدداً</button>
        </div>
      </div>
    `)
    .join('');
}
