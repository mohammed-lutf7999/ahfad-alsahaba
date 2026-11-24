import { refreshAudit } from '../core/app_bus.js';
import { broadcastWebControlPing } from '../core/rest_broadcast.js';
import { adminState, getSupabase } from '../core/supabase_client.js';
import { escapeHtml, isValidHttpUrl, showToast } from '../core/ui_utils.js';
import { updateTopbarReleaseStatus } from './overview_bar.js';

const FEATURE_FLAGS = [
  { id: 'flag-online-multiplayer', key: 'online_multiplayer', title: 'المباريات الأونلاين السريعة', code: 'online_multiplayer', desc: 'تشغيل أو إيقاف الميدان المباشر وزر الأونلاين السريع' },
  { id: 'flag-ghost-matches', key: 'ghost_matches', title: 'محرك معارك الأشباح', code: 'ghost_matches', desc: 'السقوط للبوت المحلي فقط عند الإيقاف' },
  { id: 'flag-private-rooms', key: 'private_rooms', title: 'غرف التحدي الخاصة', code: 'private_rooms', desc: 'إتاحة أو إغلاق إنشاء والانضمام للغرف السداسية' },
  { id: 'flag-knights-store', key: 'knights_store', title: 'سوق الفرسان', code: 'knights_store', desc: 'قفل أو فتح تبويب وشاشات المتجر الملكي' },
  { id: 'flag-show-event-banner', key: 'show_event_banner', title: 'بانر الأحداث الديناميكية', code: 'show_event_banner', desc: 'إظهار أو إخفاء شريط الموسم النشط في الشاشة الرئيسية' },
  { id: 'flag-daily-challenges', key: 'daily_challenges', title: 'التحدي اليومي المتجدد', code: 'daily_challenges', desc: 'إظهار أو إخفاء بطاقة الجولة اليومية في قائمة التحدي' },
  { id: 'flag-royal-inbox', key: 'royal_inbox', title: 'صندوق البريد الملكي 📬', code: 'royal_inbox', desc: 'إتاحة صندوق الرسائل والهدايا داخل قائمة اللاعب' },
  { id: 'flag-live-ping', key: 'live_announcement_ping', title: 'النبضة اللحظية للرسائل ⚡', code: 'live_announcement_ping', desc: 'تحديث فوري (<1ث) للمتصلين عند النشر أو إغلاقه لتوفير WebSockets' },
  { id: 'flag-wise-teacher', key: 'wise_teacher_mode', title: 'وضع المعلم الحكيم 🧠', code: 'wise_teacher_mode', desc: 'التحكم السحابي بميزة مراجعة الأخطاء والإضاءة التاريخية' },
  { id: 'flag-diwan-chat', key: 'diwan_chat', title: 'ديوان الأحفاد (الدردشة الحية) 💬', code: 'diwan_chat', desc: 'فتح أو إيقاف الدردشة العامة وتحديات الفرسان السريعة' },
  { id: 'flag-guilds-arenas', key: 'guilds_arenas', title: 'الكتائب والبطولات الجماعية 🛡️', code: 'guilds_arenas', desc: 'التحكم بنظام الكتائب وغرف البطولات الحية' },
  { id: 'flag-quick-phrases', key: 'quick_phrases', title: 'عبارات الفرسان السريعة في النزالات 💬', code: 'quick_phrases', desc: 'إتاحة إرسال واستقبال عبارات الفروسية في المعارك' },
  { id: 'flag-live-arena-host-restricted', key: 'live_arena_host_restricted', title: 'حصر إنشاء البطولات الحية بالمعلمين والمشرفين 🎓', code: 'live_arena_host_restricted', desc: 'قصر زر إنشاء البطولة على المشرفين أو المعلمين المفوّضين' },
];

let mounted = false;

function buildTemplate() {
  const flagsHtml = FEATURE_FLAGS.map(
    (f) => `
      <div class="switch-card">
        <div>
          <strong>${escapeHtml(f.title)} <code class="code-tag">${escapeHtml(f.code)}</code></strong>
          <p class="muted-text">${escapeHtml(f.desc)}</p>
        </div>
        <label class="switch">
          <input id="${f.id}" type="checkbox" checked />
          <span class="slider"></span>
        </label>
      </div>
    `,
  ).join('');

  return `
    <form id="release-form" class="two-col-grid">
      <section class="panel glass-card">
        <h2 class="panel-title">🛠️ وضع الصيانة والإصدارات</h2>

        <div class="switch-card danger-tint">
          <div>
            <strong>وضع الصيانة الطارئ (Maintenance Mode)</strong>
            <p class="muted-text">يُغلق التطبيق أمام جميع اللاعبين فوراً باستثناء المشرفين</p>
          </div>
          <label class="switch">
            <input id="rc-maintenance-mode" type="checkbox" />
            <span class="slider"></span>
          </label>
        </div>

        <div class="form-group">
          <label class="field-label" for="rc-maintenance-title">عنوان شاشة الصيانة</label>
          <input id="rc-maintenance-title" class="input" type="text" required />
        </div>

        <div class="form-group">
          <label class="field-label" for="rc-maintenance-message">رسالة الصيانة للاعبين</label>
          <textarea id="rc-maintenance-message" class="input" rows="3" required></textarea>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label class="field-label" for="rc-min-version">الحد الأدنى الإلزامي (versionCode)</label>
            <input id="rc-min-version" class="input" type="number" min="1" required />
          </div>
          <div class="form-group">
            <label class="field-label" for="rc-latest-version">أحدث بناء اختياري (versionCode)</label>
            <input id="rc-latest-version" class="input" type="number" min="1" required />
          </div>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label class="field-label" for="rc-latest-name">اسم الإصدار الأحدث (versionName)</label>
            <input id="rc-latest-name" class="input" type="text" required />
          </div>
          <div class="form-group">
            <label class="field-label" for="rc-update-url">رابط المتجر (https://)</label>
            <input id="rc-update-url" class="input" type="url" placeholder="https://play.google.com/..." />
          </div>
        </div>

        <div class="form-group">
          <label class="field-label" for="rc-update-title">عنوان نافذة التحديث</label>
          <input id="rc-update-title" class="input" type="text" required />
        </div>

        <div class="form-group">
          <label class="field-label" for="rc-update-message">رسالة ومحتوى التحديث</label>
          <textarea id="rc-update-message" class="input" rows="2" required></textarea>
        </div>
      </section>

      <section class="panel glass-card">
        <h2 class="panel-title">🎛️ أعلام الميزات الفورية (Feature Flags)</h2>
        <p class="muted-text mb-md">تتحكم هذه المفاتيح بظهور وتعطيل أوضاع اللعبة في كل الأجهزة بعد دورة المزامنة.</p>

        <div class="flags-list">${flagsHtml}</div>

        <button id="btn-save-release" class="btn btn-gold btn-block mt-md" type="submit">
          <span>☁️</span>
          <span>حفظ ونشر الإعدادات على الخادم</span>
        </button>
      </section>
    </form>
  `;
}

export function hydrateReleaseForm(rc) {
  if (!mounted || !rc) return;
  const maint = Boolean(rc.maintenance_mode);
  document.getElementById('rc-maintenance-mode').checked = maint;
  document.getElementById('rc-maintenance-title').value = rc.maintenance_title ?? 'صيانة وتحسينات مؤقتة';
  document.getElementById('rc-maintenance-message').value = rc.maintenance_message ?? '';
  document.getElementById('rc-min-version').value = rc.min_version_code ?? 1;
  document.getElementById('rc-latest-version').value = rc.latest_version_code ?? 20;
  document.getElementById('rc-latest-name').value = rc.latest_version_name ?? '1.0.19';
  document.getElementById('rc-update-url').value = rc.update_url ?? '';
  document.getElementById('rc-update-title').value = rc.update_title ?? 'تحديث جديد متاح';
  document.getElementById('rc-update-message').value = rc.update_message ?? '';

  const flags = rc.feature_flags ?? {};
  for (const f of FEATURE_FLAGS) {
    const el = document.getElementById(f.id);
    if (el) el.checked = flags[f.key] ?? true;
  }
  updateTopbarReleaseStatus(rc);
}

async function handleSaveRelease(e) {
  e.preventDefault();
  const supabase = getSupabase();
  if (!supabase) return;

  const minVer = Number.parseInt(document.getElementById('rc-min-version').value, 10);
  const latestVer = Number.parseInt(document.getElementById('rc-latest-version').value, 10);
  const latestName = document.getElementById('rc-latest-name').value.trim();
  const updateTitle = document.getElementById('rc-update-title').value.trim();
  const updateMessage = document.getElementById('rc-update-message').value.trim();
  const maintTitle = document.getElementById('rc-maintenance-title').value.trim();
  const maintMessage = document.getElementById('rc-maintenance-message').value.trim();
  const updateUrl = document.getElementById('rc-update-url').value.trim();

  if (!maintTitle || !maintMessage || !latestName || !updateTitle || !updateMessage) {
    showToast('تأكد من ملء جميع نصوص الصيانة والإصدار دون الاقتصار على مسافات.', true);
    return;
  }
  if (!Number.isFinite(minVer) || minVer < 1 || !Number.isFinite(latestVer) || latestVer < minVer) {
    showToast('يجب أن يكون أحدث رقم بناء >= الحد الأدنى الإلزامي.', true);
    return;
  }
  if (updateUrl && !isValidHttpUrl(updateUrl)) {
    showToast('يجب أن يبدأ رابط المتجر بـ https:// أو http://', true);
    return;
  }

  const maint = document.getElementById('rc-maintenance-mode').checked;
  if (maint && !window.confirm('هل أنت متأكد من تفعيل وضع الصيانة الشامل لجميع اللاعبين؟')) {
    return;
  }

  const featureFlags = {};
  for (const f of FEATURE_FLAGS) {
    featureFlags[f.key] = document.getElementById(f.id).checked;
  }

  const btn = document.getElementById('btn-save-release');
  btn.disabled = true;
  try {
    const { data, error } = await supabase.rpc('admin_upsert_release_config', {
      p_platform: 'android',
      p_min_version_code: minVer,
      p_latest_version_code: latestVer,
      p_latest_version_name: latestName,
      p_update_title: updateTitle,
      p_update_message: updateMessage,
      p_update_url: updateUrl || null,
      p_maintenance_mode: maint,
      p_maintenance_title: maintTitle,
      p_maintenance_message: maintMessage,
      p_feature_flags: featureFlags,
    });
    if (error) throw error;
    if (data) hydrateReleaseForm(data);
    broadcastWebControlPing('ALL');
    showToast('تم حفظ ونشر إعدادات الإصدار والأعلام ✅');
    await refreshAudit();
  } catch (err) {
    showToast(`فشل الحفظ: ${err.message}`, true);
  } finally {
    btn.disabled = false;
  }
}

export function mount(container) {
  if (mounted || !container) return;
  container.innerHTML = buildTemplate();
  document.getElementById('release-form').addEventListener('submit', handleSaveRelease);
  mounted = true;
  if (adminState.lastOverview?.release_config) {
    hydrateReleaseForm(adminState.lastOverview.release_config);
  }
}

export async function load() {
  if (adminState.lastOverview?.release_config) {
    hydrateReleaseForm(adminState.lastOverview.release_config);
  }
}
