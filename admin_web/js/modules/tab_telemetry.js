import { refreshOverview } from '../core/app_bus.js';
import { getSupabase } from '../core/supabase_client.js';
import { escapeHtml, formatDateDisplay, showToast } from '../core/ui_utils.js';

const CLEANUP_ACTIONS = [
  { id: 'btn-cleanup-matches', action: 'finished_matches', label: '🧹 تنظيف مباريات +30 يوماً', confirm: 'هل تريد حذف المباريات المنتهية الأقدم من 30 يوماً؟' },
  { id: 'btn-cleanup-receipts', action: 'expired_receipts', label: '✉️ تنظيف إيصالات منتهية', confirm: 'هل تريد حذف إيصالات الإعلانات المنتهية؟' },
  { id: 'btn-cleanup-sessions', action: 'expired_live_sessions', label: '🎓 تنظيف جلسات البطولات المنتهية', confirm: 'هل تريد حذف جلسات البطولات الحية المنتهية؟' },
  { id: 'btn-cleanup-chat', action: 'old_chat_messages', label: '💬 تنظيف رسائل الديوان (+24س)', confirm: 'هل تريد حذف رسائل الديوان الأقدم من 24 ساعة؟' },
  { id: 'btn-reset-guild-week', action: 'reset_guild_week', label: '🛡️ تصفير أسبوع معركة الجمعة', confirm: 'هل تريد تصفير النقاط الأسبوعية لبدء جولة معركة الجمعة الكبرى؟' },
];

let mounted = false;

function buildTemplate() {
  const cleanupButtons = CLEANUP_ACTIONS.map(
    (c) => `<button id="${c.id}" class="btn btn-outline btn-sm" type="button">${c.label}</button>`,
  ).join('');

  return `
    <section class="panel glass-card mb-md">
      <div class="panel-header-row">
        <h2 class="panel-title">🎛️ مراقبة وإدارة موارد Supabase</h2>
        <div class="record-actions">
          <span id="res-usage-pill" class="badge-pill">0 / 500 MB</span>
          <button id="btn-refresh-resources" class="btn btn-outline btn-sm" type="button">تحديث الموارد</button>
        </div>
      </div>
      <div id="resource-health-summary" class="muted-text mb-md">افتح التبويب لتحميل قياسات قاعدة البيانات والنشاط الحي...</div>
      <div class="record-actions">
        ${cleanupButtons}
        <a class="btn btn-outline btn-sm" href="https://supabase.com/dashboard/project/khatzzpqxaiwuoodgcst/settings/billing/usage" target="_blank" rel="noopener">📊 لوحة Supabase Usage</a>
      </div>
    </section>

    <div class="two-col-grid">
      <section class="panel glass-card">
        <div class="panel-header-row">
          <h2 class="panel-title">👻 مراقب أشباح الصحابة</h2>
          <span id="ghosts-count-pill" class="badge-pill">0</span>
        </div>
        <div id="ghosts-list" class="items-list"></div>
      </section>

      <section class="stack-md">
        <div class="panel glass-card">
          <div class="panel-header-row">
            <h2 class="panel-title">🛡️ إدارة طاقم المشرفين <code class="code-tag">owner-only</code></h2>
            <span id="admins-role-pill" class="badge-pill">—</span>
          </div>
          <div id="admins-owner-note" class="muted-text mb-md"></div>
          <form id="admin-manage-form" class="search-row mb-md hidden">
            <input id="new-admin-email" class="input ltr-input" type="email" placeholder="admin@gmail.com" required />
            <select id="new-admin-role" class="input compact-select">
              <option value="admin">admin</option>
              <option value="owner">owner</option>
            </select>
            <button id="btn-add-admin" class="btn btn-gold btn-sm" type="submit">إضافة / ترقية</button>
          </form>
          <div id="admins-list" class="items-list compact-list"></div>
        </div>

        <div class="panel glass-card">
          <div class="panel-header-row">
            <h2 class="panel-title">📒 سجل التدقيق الرقابي غير القابل للتعديل</h2>
            <span id="audit-count-pill" class="badge-pill">0</span>
          </div>
          <div id="audit-logs-list" class="items-list"></div>
        </div>
      </section>
    </div>
  `;
}

async function loadResourceHealth() {
  const client = getSupabase();
  const box = document.getElementById('resource-health-summary');
  const pill = document.getElementById('res-usage-pill');
  if (!client || !box || !pill) return;
  const { data, error } = await client.rpc('admin_get_resource_health');
  if (error) {
    box.textContent = `تعذر تحميل مؤشرات الموارد: ${error.message}`;
    return;
  }
  const usedMb = (Number(data?.db_size_bytes || 0) / (1024 * 1024)).toFixed(1);
  const limitMb = (Number(data?.db_limit_bytes || 524288000) / (1024 * 1024)).toFixed(0);
  pill.textContent = `${usedMb} / ${limitMb} MB (${data?.db_usage_percent ?? 0}%)`;
  const tables = Array.isArray(data?.tables) ? data.tables.slice(0, 6) : [];
  const tablesHtml = tables
    .map((t) => `<span class="code-tag">${escapeHtml(t.table_name)}: ${(Number(t.size_bytes || 0) / (1024 * 1024)).toFixed(2)} MB (${escapeHtml(t.row_estimate ?? 0)})</span>`)
    .join(' ');
  box.innerHTML = `
    <div class="record-actions mb-xs">
      <span>⚔️ تحديات الآن: <strong>${escapeHtml(data?.active_matches_now ?? 0)}</strong></span>
      <span>🟢 نشطون (5د): <strong>${escapeHtml(data?.active_players_5m ?? 0)}</strong></span>
      <span>🕒 نشطون (24س): <strong>${escapeHtml(data?.active_players_24h ?? 0)}</strong></span>
      <span>🧹 قابل للتنظيف: <strong>${escapeHtml((data?.cleanable_old_matches ?? 0) + (data?.cleanable_expired_receipts ?? 0))}</strong></span>
    </div>
    <div class="record-actions">${tablesHtml}</div>
  `;
}

async function runResourceCleanup(action, confirmMsg) {
  const client = getSupabase();
  if (!client || !window.confirm(confirmMsg)) return;
  const { data, error } = await client.rpc('admin_cleanup_stale_resources', {
    p_action: action,
    p_older_than_days: 30,
  });
  if (error) {
    showToast(`فشل التنظيف: ${error.message}`, true);
    return;
  }
  showToast(`تم تنظيف ${data?.deleted_count ?? 0} سجل قديم ✅`);
  await Promise.all([loadResourceHealth(), loadAuditLogs()]);
}

async function loadGhosts() {
  const client = getSupabase();
  if (!client) return;
  const { data, error } = await client.rpc('admin_list_ghosts', { p_limit: 50 });
  if (error) {
    showToast(`تعذر تحميل الأشباح: ${error.message}`, true);
    return;
  }
  const ghosts = Array.isArray(data) ? data : [];
  document.getElementById('ghosts-count-pill').textContent = ghosts.length;
  const listEl = document.getElementById('ghosts-list');
  if (!ghosts.length) {
    listEl.innerHTML = '<p class="muted-text">لا توجد تسجيلات أشباح بعد.</p>';
    return;
  }
  listEl.innerHTML = ghosts
    .map((g) => `
      <article class="record-card">
        <div class="record-top">
          <div class="record-actions">
            <span class="badge-pill">${g.is_human ? 'شبح لاعب بشري 👤' : 'شبح اصطناعي 🤖'}</span>
            <strong>${escapeHtml(g.display_name || 'شبح')}</strong>
          </div>
          <label class="switch">
            <input type="checkbox" data-toggle-ghost="${escapeHtml(g.id)}" ${g.is_active !== false ? 'checked' : ''} />
            <span class="slider"></span>
          </label>
        </div>
        <div class="record-actions muted-text">
          <span>م${escapeHtml(g.player_level ?? 1)}</span>
          <span>🏆 ${escapeHtml(g.trophies ?? 1000)}</span>
          <span>نقاط ${escapeHtml(g.total_score ?? 0)}</span>
          <span>استخدامات: ${escapeHtml(g.use_count ?? 0)}</span>
        </div>
      </article>
    `)
    .join('');

  listEl.querySelectorAll('input[data-toggle-ghost]').forEach((input) => {
    input.addEventListener('change', async () => {
      const { error: tErr } = await client.rpc('admin_toggle_ghost', {
        p_ghost_id: input.dataset.toggleGhost,
        p_is_active: input.checked,
      });
      if (tErr) {
        showToast(`تعذر تحديث الشبح: ${tErr.message}`, true);
        await loadGhosts();
        return;
      }
      showToast(input.checked ? 'تم تفعيل الشبح ✅' : 'تم إيقاف الشبح ⏸️');
      await Promise.all([loadGhosts(), refreshOverview(), loadAuditLogs()]);
    });
  });
}

export async function loadAuditLogs() {
  if (!mounted) return;
  const client = getSupabase();
  if (!client) return;
  const { data, error } = await client.rpc('admin_list_audit_logs', { p_limit: 60 });
  if (error) {
    showToast(`تعذر تحميل سجل التدقيق: ${error.message}`, true);
    return;
  }
  const logs = Array.isArray(data) ? data : [];
  document.getElementById('audit-count-pill').textContent = logs.length;
  const listEl = document.getElementById('audit-logs-list');
  if (!logs.length) {
    listEl.innerHTML = '<p class="muted-text">سجل التدقيق نظيف ولم تُسجّل إجراءات CMS بعد.</p>';
    return;
  }
  listEl.innerHTML = logs
    .map((log) => `
      <article class="record-card">
        <div class="record-top">
          <div class="record-actions">
            <span class="badge-pill">${escapeHtml(log.action)}</span>
            <span class="code-tag">${escapeHtml(log.target_type)}: ${escapeHtml(log.target_id)}</span>
          </div>
          <span class="muted-text">${escapeHtml(formatDateDisplay(log.created_at))}</span>
        </div>
        <div>${escapeHtml(log.reason || '—')}</div>
        <div class="muted-text">المنفّذ: ${escapeHtml(log.admin_email || 'system')}</div>
      </article>
    `)
    .join('');
}

async function loadAdminsRoster() {
  const client = getSupabase();
  if (!client) return;
  const { data, error } = await client.rpc('admin_list_admins');
  if (error) {
    showToast(`تعذر تحميل طاقم المشرفين: ${error.message}`, true);
    return;
  }
  const meta = data || { is_owner: false, admins: [] };
  const isOwner = Boolean(meta.is_owner);
  const admins = Array.isArray(meta.admins) ? meta.admins : [];

  document.getElementById('admins-role-pill').textContent = isOwner ? 'المالك (Owner)' : 'مشرف (Admin)';
  document.getElementById('admins-owner-note').textContent = isOwner
    ? 'بصفتك المالك، يمكنك إضافة المشرفين أو ترقيتهم أو سحب صلاحيتهم بأمان.'
    : 'وضع العرض فقط — إضافة أو إزالة المشرفين محصورة لصلاحية المالك (Owner).';
  document.getElementById('admin-manage-form').classList.toggle('hidden', !isOwner);

  const listEl = document.getElementById('admins-list');
  listEl.innerHTML = admins
    .map((a) => `
      <article class="record-card">
        <div class="record-top">
          <div>
            <strong>${escapeHtml(a.email)}</strong>
            <span class="badge-pill">${escapeHtml(a.role || 'admin')}</span>
          </div>
          ${isOwner ? `<button class="btn btn-danger-outline btn-sm" type="button" data-remove-admin="${escapeHtml(a.email)}">إزالة</button>` : ''}
        </div>
      </article>
    `)
    .join('');

  if (isOwner) {
    listEl.querySelectorAll('button[data-remove-admin]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        const email = btn.dataset.removeAdmin;
        if (!window.confirm(`هل تريد إزالة صلاحية الإشراف عن ${email}؟`)) return;
        const { error: rErr } = await client.rpc('admin_manage_admin', { p_action: 'remove', p_email: email });
        if (rErr) return showToast(`تعذر الإزالة: ${rErr.message}`, true);
        showToast('تم تحديث قائمة المشرفين ✅');
        await Promise.all([loadAdminsRoster(), loadAuditLogs()]);
      });
    });
  }
}

async function handleAddAdmin(e) {
  e.preventDefault();
  const client = getSupabase();
  if (!client) return;
  const email = document.getElementById('new-admin-email').value.trim().toLowerCase();
  const role = document.getElementById('new-admin-role').value;
  const btn = document.getElementById('btn-add-admin');
  btn.disabled = true;
  try {
    const { error } = await client.rpc('admin_manage_admin', { p_action: 'add', p_email: email, p_role: role });
    if (error) throw error;
    showToast('تم حفظ صلاحية المشرف ✅');
    document.getElementById('admin-manage-form').reset();
    await Promise.all([loadAdminsRoster(), loadAuditLogs()]);
  } catch (err) {
    showToast(`فشل تحديث المشرف: ${err.message}`, true);
  } finally {
    btn.disabled = false;
  }
}

export function mount(container) {
  if (mounted || !container) return;
  container.innerHTML = buildTemplate();
  mounted = true;

  document.getElementById('admin-manage-form').addEventListener('submit', handleAddAdmin);
  document.getElementById('btn-refresh-resources').addEventListener('click', loadResourceHealth);
  for (const c of CLEANUP_ACTIONS) {
    document.getElementById(c.id).addEventListener('click', () => runResourceCleanup(c.action, c.confirm));
  }
}

export async function load() {
  await Promise.all([loadResourceHealth(), loadGhosts(), loadAuditLogs(), loadAdminsRoster()]);
}
