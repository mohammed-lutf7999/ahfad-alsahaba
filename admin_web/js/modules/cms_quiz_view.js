import { escapeHtml, safeHexColor } from '../core/ui_utils.js';

export function buildQuizTemplate() {
  return `
    <section class="stack-md">
      <div class="panel glass-card">
        <div class="panel-header-row">
          <h2 id="quiz-cat-heading" class="panel-title">🏆 قسم مسابقة (إضافة / تعديل)</h2>
          <button id="btn-reset-quiz-cat" class="btn btn-outline btn-sm" type="button">قسم جديد</button>
        </div>
        <form id="quiz-category-form" class="stack-sm">
          <div class="form-row">
            <div class="form-group">
              <label class="field-label" for="qz-cat-id">معرّف القسم (ID)</label>
              <input id="qz-cat-id" class="input ltr-input" type="text" placeholder="quran أو sahaba_women" pattern="[a-z0-9_]{2,48}" required />
            </div>
            <div class="form-group">
              <label class="field-label" for="qz-cat-name">اسم القسم</label>
              <input id="qz-cat-name" class="input" type="text" placeholder="مثال: أمهات المؤمنين والصحابيات" required />
            </div>
          </div>
          <div class="form-group">
            <label class="field-label" for="qz-cat-desc">وصف القسم</label>
            <input id="qz-cat-desc" class="input" type="text" placeholder="اختبر معلوماتك في..." />
          </div>
          <div class="form-row-3">
            <div class="form-group">
              <label class="field-label" for="qz-cat-levels">عدد المراحل (1..100)</label>
              <input id="qz-cat-levels" class="input" type="number" min="1" max="100" value="10" />
            </div>
            <div class="form-group">
              <label class="field-label" for="qz-cat-icon">الأيقونة</label>
              <select id="qz-cat-icon" class="input">
                <option value="quiz_rounded">سؤال (quiz)</option>
                <option value="menu_book_rounded">القرآن والكتاب</option>
                <option value="mosque_rounded">مسجد</option>
                <option value="military_tech_rounded">غزوات</option>
                <option value="shield_rounded">عقيدة وفقه</option>
                <option value="groups_rounded">الصحابة</option>
                <option value="auto_awesome_rounded">مميز</option>
              </select>
            </div>
            <div class="form-group">
              <label class="field-label" for="qz-cat-color">اللون</label>
              <div class="color-row">
                <input id="qz-cat-color" class="input ltr-input" type="text" value="#1B5E20" />
                <input id="qz-cat-color-picker" class="color-swatch" type="color" value="#1b5e20" />
              </div>
            </div>
          </div>
          <div class="form-row">
            <div class="form-group">
              <label class="field-label" for="qz-cat-sort">الترتيب</label>
              <input id="qz-cat-sort" class="input" type="number" value="10" />
            </div>
            <div class="stack-sm">
              <label class="inline-check">
                <input id="qz-cat-visible" type="checkbox" checked />
                <span>مرئي في الشاشة</span>
              </label>
              <label class="inline-check">
                <input id="qz-cat-locked" type="checkbox" />
                <span>مقفل مؤقتاً <code class="code-tag">is_locked</code></span>
              </label>
            </div>
          </div>
          <button id="btn-save-quiz-cat" class="btn btn-outline btn-block" type="submit">حفظ قسم المسابقة</button>
        </form>
      </div>

      <div class="panel glass-card">
        <div class="panel-header-row">
          <h2 id="quiz-q-heading" class="panel-title">❓ إضافة / تعديل سؤال سحابي</h2>
          <button id="btn-reset-quiz-q" class="btn btn-outline btn-sm" type="button">سؤال جديد</button>
        </div>
        <form id="quiz-question-form" class="stack-sm">
          <input id="qz-q-id" type="hidden" />
          <div class="form-row-3">
            <div class="form-group">
              <label class="field-label" for="qz-q-cat">القسم</label>
              <select id="qz-q-cat" class="input"></select>
            </div>
            <div class="form-group">
              <label class="field-label" for="qz-q-level">المستوى (1..100)</label>
              <input id="qz-q-level" class="input" type="number" min="1" max="100" value="1" required />
            </div>
            <div class="form-group">
              <label class="field-label" for="qz-q-scope">نطاق التزامن</label>
              <select id="qz-q-scope" class="input">
                <option value="solo_only">فردي فقط (الأكثر أماناً)</option>
                <option value="all_with_fallback">شامل (solo + multiplayer)</option>
              </select>
            </div>
          </div>
          <div class="form-group">
            <label class="field-label" for="qz-q-text">نص السؤال</label>
            <textarea id="qz-q-text" class="input" rows="2" placeholder="اكتب السؤال بوضوح..." required></textarea>
          </div>
          <div class="form-row">
            <div class="form-group">
              <label class="field-label" for="qz-opt-0">الخيار الأول (0)</label>
              <input id="qz-opt-0" class="input" type="text" required />
            </div>
            <div class="form-group">
              <label class="field-label" for="qz-opt-1">الخيار الثاني (1)</label>
              <input id="qz-opt-1" class="input" type="text" required />
            </div>
          </div>
          <div class="form-row">
            <div class="form-group">
              <label class="field-label" for="qz-opt-2">الخيار الثالث (2)</label>
              <input id="qz-opt-2" class="input" type="text" required />
            </div>
            <div class="form-group">
              <label class="field-label" for="qz-opt-3">الخيار الرابع (3)</label>
              <input id="qz-opt-3" class="input" type="text" required />
            </div>
          </div>
          <div class="form-row">
            <div class="form-group">
              <label class="field-label" for="qz-q-correct">الإجابة الصحيحة</label>
              <select id="qz-q-correct" class="input">
                <option value="0">الخيار الأول (0)</option>
                <option value="1">الخيار الثاني (1)</option>
                <option value="2">الخيار الثالث (2)</option>
                <option value="3">الخيار الرابع (3)</option>
              </select>
            </div>
            <div class="form-group">
              <label class="field-label" for="qz-q-sort">الترتيب</label>
              <input id="qz-q-sort" class="input" type="number" value="10" />
            </div>
          </div>
          <div class="form-group">
            <label class="field-label" for="qz-q-exp">الشرح والفائدة العلمية (يظهر بعد الإجابة)</label>
            <textarea id="qz-q-exp" class="input" rows="2" placeholder="شرح مختصر ومصدر المعلومة..."></textarea>
          </div>
          <label class="inline-check">
            <input id="qz-q-visible" type="checkbox" checked />
            <span>السؤال مرئي ومفعّل</span>
          </label>
          <button id="btn-save-quiz-q" class="btn btn-gold btn-block" type="submit">حفظ السؤال السحابي</button>
        </form>
      </div>
    </section>

    <section class="stack-md">
      <div id="bulk-json-importer-mount"></div>
      <div class="panel glass-card">
        <div class="panel-header-row">
          <h2 class="panel-title">🏆 أقسام المسابقات</h2>
          <span id="quiz-cat-count" class="badge-pill">0</span>
        </div>
        <div id="quiz-categories-list" class="items-list compact-list"></div>
      </div>
      <div class="panel glass-card">
        <div class="panel-header-row">
          <h2 class="panel-title">❓ الأسئلة السحابية المضافة</h2>
          <div class="record-actions">
            <select id="quiz-filter-cat" class="input compact-select">
              <option value="">كل الأقسام</option>
            </select>
            <input id="quiz-filter-level" class="input compact-input" type="number" min="1" max="100" placeholder="مستوى" />
          </div>
        </div>
        <div id="quiz-questions-list" class="items-list"></div>
      </div>
    </section>
  `;
}

export function renderQuizCategoriesHtml(categories) {
  if (!categories.length) return '<p class="muted-text">لا توجد أقسام مسابقات.</p>';
  return categories
    .map((cat) => {
      const vis = cat.is_visible !== false;
      const hex = safeHexColor(cat.color_hex, '#1B5E20');
      return `
        <article class="record-card" style="border-right:3px solid ${hex};">
          <div class="record-top">
            <div class="record-actions">
              <strong>${escapeHtml(cat.name)}</strong>
              <span class="code-tag">${escapeHtml(cat.id)}</span>
              <span class="muted-text">• ${escapeHtml(cat.total_levels ?? 10)} مستوى</span>
              <span class="muted-text">• ${escapeHtml(cat.custom_questions_count ?? 0)} سؤال سحابي</span>
              ${cat.is_locked ? '<span class="badge-hidden">مقفل</span>' : ''}
            </div>
            <div class="record-actions">
              <span class="${vis ? 'badge-visible' : 'badge-hidden'}">${vis ? 'مرئي' : 'مخفي'}</span>
              <button class="btn btn-outline btn-sm" type="button" data-edit-qz-cat="${escapeHtml(cat.id)}">تعديل</button>
              <label class="switch">
                <input type="checkbox" data-vis-qz-cat="${escapeHtml(cat.id)}" ${vis ? 'checked' : ''} />
                <span class="slider"></span>
              </label>
            </div>
          </div>
        </article>
      `;
    })
    .join('');
}

export function renderQuizQuestionsHtml(questions) {
  if (!questions.length) return '<p class="muted-text">لا توجد أسئلة سحابية مطابقة للتصفية الحالية.</p>';
  return questions
    .map((q) => {
      const vis = q.is_visible !== false;
      const opts = Array.isArray(q.options) ? q.options : [];
      const ansText = opts[q.correct_index] ?? '';
      return `
        <article class="record-card">
          <div class="record-top">
            <div class="record-actions">
              <span class="badge-pill">${escapeHtml(q.category_id)} • م${escapeHtml(q.level_number)}</span>
              <span class="code-tag">${escapeHtml(q.sync_scope || 'solo_only')}</span>
            </div>
            <div class="record-actions">
              <span class="${vis ? 'badge-visible' : 'badge-hidden'}">${vis ? 'مرئي' : 'مخفي'}</span>
              <button class="btn btn-outline btn-sm" type="button" data-edit-qz-q="${escapeHtml(q.id)}">تعديل</button>
              <label class="switch">
                <input type="checkbox" data-vis-qz-q="${escapeHtml(q.id)}" ${vis ? 'checked' : ''} />
                <span class="slider"></span>
              </label>
            </div>
          </div>
          <strong>${escapeHtml(q.question_text)}</strong>
          <div class="muted-text">✅ الصحيح (${escapeHtml(q.correct_index)}): ${escapeHtml(ansText)}</div>
        </article>
      `;
    })
    .join('');
}
