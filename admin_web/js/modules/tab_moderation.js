import { refreshAudit } from '../core/app_bus.js';
import {
  broadcastLiveArenaFinish,
  broadcastWebControlPing,
} from '../core/rest_broadcast.js';
import { getSupabase } from '../core/supabase_client.js';
import { escapeHtml, showToast } from '../core/ui_utils.js';

let mounted = false;

function buildTemplate() {
  return `
    <div class="two-col-grid">
      <section class="stack-md">
        <div class="panel glass-card">
          <div class="panel-header-row">
            <h2 class="panel-title">🚨 بلاغات الديوان المعلقة</h2>
            <span id="diwan-reports-count-pill" class="badge-pill">0</span>
          </div>
          <div id="diwan-reports-list" class="items-list"></div>
        </div>
        <div class="panel glass-card">
          <div class="panel-header-row">
            <h2 class="panel-title">🔇 اللاعبون المكتومون حالياً</h2>
            <span id="diwan-muted-count-pill" class="badge-pill">0</span>
          </div>
          <div id="diwan-muted-list" class="items-list"></div>
        </div>
      </section>

      <section class="stack-md">
        <div class="panel glass-card">
          <div class="panel-header-row">
            <h2 class="panel-title">🏟️ ساحات البطولات الحية</h2>
            <span id="arenas-count-pill" class="badge-pill">0</span>
          </div>
          <div id="admin-live-arenas-list" class="items-list"></div>
        </div>
        <div class="panel glass-card">
          <div class="panel-header-row">
            <h2 class="panel-title">🛡️ كتائب الفرسان المسجلة</h2>
            <span id="guilds-count-pill" class="badge-pill">0</span>
          </div>
          <div id="admin-guilds-list" class="items-list"></div>
        </div>
      </section>
    </div>
  `;
}

async function moderateDiwan(action, messageId = null, targetUserId = null, reason = '', muteHours = 24) {
  const client = getSupabase();
  if (!client) return;
  try {
    const { data, error } = await client.rpc('admin_moderate_diwan', {
      p_action: action,
      p_message_id: messageId,
      p_target_user_id: targetUserId,
      p_mute_hours: muteHours,
      p_reason: reason,
    });
    if (error) throw error;
    showToast('تم تنفيذ إجراء إشراف الديوان بنجاح ✅');
    if (action === 'mute_user' || action === 'unmute_user') {
      broadcastWebControlPing(data?.player_code || 'SINGLE', targetUserId);
    }
    await Promise.all([loadDiwanQueue(), refreshAudit()]);
  } catch (err) {
    showToast(`فشل الإجراء: ${err.message}`, true);
  }
}

function renderDiwanReports(reports) {
  const el = document.getElementById('diwan-reports-list');
  if (!reports.length) {
    el.innerHTML = '<p class="muted-text">طابور البلاغات نظيف ✨ لا توجد بلاغات معلقة.</p>';
    return;
  }
  el.innerHTML = reports
    .map((r) => `
      <article class="record-card danger-tint">
        <div class="record-top">
          <div>
            <strong>${escapeHtml(r.sender_name || 'فارس')} (${escapeHtml(r.sender_code || (r.sender_id || '').slice(0, 8))})</strong>
            <div class="muted-text">السبب: ${escapeHtml(r.latest_reason)} • ${escapeHtml(r.reports_count)} بلاغات</div>
          </div>
          <span class="badge-pill danger-pill">${escapeHtml(r.reports_count)} ⚠️</span>
        </div>
        <div class="quote-box mt-xs">"${escapeHtml(r.content)}"</div>
        <div class="record-actions mt-xs">
          <button class="btn btn-outline btn-sm" type="button" data-diwan-dismiss="${escapeHtml(r.message_id)}">تجاهل</button>
          <button class="btn btn-danger-outline btn-sm" type="button" data-diwan-delete="${escapeHtml(r.message_id)}">حذف الرسالة</button>
          <button class="btn btn-gold btn-sm" type="button" data-diwan-mute="${escapeHtml(r.sender_id)}" data-reason="${escapeHtml(r.latest_reason)}">كتم 24 ساعة</button>
        </div>
      </article>
    `)
    .join('');

  el.querySelectorAll('button[data-diwan-dismiss]').forEach((b) =>
    b.addEventListener('click', () => moderateDiwan('dismiss_reports', b.dataset.diwanDismiss)),
  );
  el.querySelectorAll('button[data-diwan-delete]').forEach((b) =>
    b.addEventListener('click', () => moderateDiwan('delete_message', b.dataset.diwanDelete, null, 'حذف عبر الإدارة')),
  );
  el.querySelectorAll('button[data-diwan-mute]').forEach((b) =>
    b.addEventListener('click', () => moderateDiwan('mute_user', null, b.dataset.diwanMute, b.dataset.reason, 24)),
  );
}

function renderDiwanMuted(muted) {
  const el = document.getElementById('diwan-muted-list');
  if (!muted.length) {
    el.innerHTML = '<p class="muted-text">لا يوجد لاعبون مكتومون حالياً 🕊️</p>';
    return;
  }
  el.innerHTML = muted
    .map((u) => {
      const remainingHours = u.muted_until
        ? Math.max(0, Math.round((new Date(u.muted_until).getTime() - Date.now()) / (1000 * 3600)))
        : 0;
      return `
        <article class="record-card">
          <div class="record-top">
            <div>
              <strong>${escapeHtml(u.display_name || 'لاعب')} (${escapeHtml(u.player_code || (u.user_id || '').slice(0, 8))})</strong>
              <div class="muted-text">متبقي: ${remainingHours > 0 ? `${remainingHours} ساعة` : 'أقل من ساعة'} • السبب: ${escapeHtml(u.reason || 'مخالفة')}</div>
            </div>
            <button class="btn btn-gold btn-sm" type="button" data-unmute-uid="${escapeHtml(u.user_id)}">فك الكتم 🕊️</button>
          </div>
        </article>
      `;
    })
    .join('');

  el.querySelectorAll('button[data-unmute-uid]').forEach((b) =>
    b.addEventListener('click', () => moderateDiwan('unmute_user', null, b.dataset.unmuteUid, 'فك الكتم بقرار إداري')),
  );
}

async function loadDiwanQueue() {
  const client = getSupabase();
  if (!client) return;
  try {
    const { data, error } = await client.rpc('admin_list_diwan_moderation_queue', { p_limit: 50 });
    if (error) throw error;
    const reports = Array.isArray(data?.reports) ? data.reports : [];
    const muted = Array.isArray(data?.muted_users) ? data.muted_users : [];
    document.getElementById('diwan-reports-count-pill').textContent = reports.length;
    document.getElementById('diwan-muted-count-pill').textContent = muted.length;
    renderDiwanReports(reports);
    renderDiwanMuted(muted);
  } catch (err) {
    showToast(`تعذر جلب طابور إشراف الديوان: ${err.message}`, true);
  }
}

async function moderateGuildOrArena(action, targetId, reason = '') {
  const client = getSupabase();
  if (!client || !targetId) return;
  try {
    const { data, error } = await client.rpc('admin_moderate_guild_or_arena', {
      p_action: action,
      p_target_id: targetId,
      p_reason: reason,
    });
    if (error) throw error;
    showToast('تم تنفيذ الإجراء بنجاح ✅');
    if (action === 'force_finish_session') {
      const lb = Array.isArray(data?.leaderboard) ? data.leaderboard : [];
      await broadcastLiveArenaFinish(targetId, lb);
    }
    await Promise.all([loadGuildsAndArenas(), refreshAudit()]);
  } catch (err) {
    showToast(`فشل الإجراء: ${err.message}`, true);
  }
}

function renderArenas(arenas) {
  const el = document.getElementById('admin-live-arenas-list');
  if (!arenas.length) {
    el.innerHTML = '<p class="muted-text">لا توجد ساحات بطولات حية نشطة حالياً.</p>';
    return;
  }
  el.innerHTML = arenas
    .map((a) => {
      const isActive = a.status === 'active' || a.status === 'waiting';
      return `
        <article class="record-card">
          <div class="record-top">
            <div>
              <strong>PIN: ${escapeHtml(a.pin_code)} • ${escapeHtml(a.title)}</strong>
              <div class="muted-text">المضيف: ${escapeHtml(a.host_name)} • ${escapeHtml(a.participants_count)} فرسان • الحالة: ${escapeHtml(a.status)}</div>
            </div>
            <span class="badge-pill ${a.status === 'active' ? 'emerald-text' : ''}">${escapeHtml(a.status)}</span>
          </div>
          <div class="record-actions mt-xs">
            ${isActive ? `<button class="btn btn-danger-outline btn-sm" type="button" data-force-finish-arena="${escapeHtml(a.id)}">🛑 إنهاء فوري وبث النتيجة</button>` : ''}
            <button class="btn btn-outline btn-sm" type="button" data-delete-arena="${escapeHtml(a.id)}">حذف الجلسة</button>
          </div>
        </article>
      `;
    })
    .join('');

  el.querySelectorAll('button[data-force-finish-arena]').forEach((b) =>
    b.addEventListener('click', () => moderateGuildOrArena('force_finish_session', b.dataset.forceFinishArena, 'إنهاء إداري للساحة')),
  );
  el.querySelectorAll('button[data-delete-arena]').forEach((b) =>
    b.addEventListener('click', () => moderateGuildOrArena('delete_session', b.dataset.deleteArena)),
  );
}

function renderGuilds(guilds) {
  const el = document.getElementById('admin-guilds-list');
  if (!guilds.length) {
    el.innerHTML = '<p class="muted-text">لا توجد كتائب مسجلة حتى الآن.</p>';
    return;
  }
  el.innerHTML = guilds
    .map((g) => `
      <article class="record-card">
        <div class="record-top">
          <div>
            <strong>${escapeHtml(g.name)}</strong>
            <div class="muted-text">القائد: ${escapeHtml(g.leader_name)} • ${escapeHtml(g.members_count)}/${escapeHtml(g.max_members)} عضو • رصيد: ${escapeHtml(g.weekly_score)}</div>
          </div>
          <span class="badge-pill">${escapeHtml(g.total_score)} إجمالي</span>
        </div>
        <div class="record-actions mt-xs">
          <button class="btn btn-outline btn-sm" type="button" data-reset-guild="${escapeHtml(g.id)}">تصفير رصيد الكتيبة</button>
          <button class="btn btn-danger-outline btn-sm" type="button" data-delete-guild="${escapeHtml(g.id)}">حل وحذف الكتيبة</button>
        </div>
      </article>
    `)
    .join('');

  el.querySelectorAll('button[data-reset-guild]').forEach((b) =>
    b.addEventListener('click', () => {
      if (window.confirm('هل أنت متأكد من تصفير رصيد هذه الكتيبة؟')) {
        moderateGuildOrArena('reset_single_guild_score', b.dataset.resetGuild, 'تصفير رصيد الكتيبة إدارياً');
      }
    }),
  );
  el.querySelectorAll('button[data-delete-guild]').forEach((b) =>
    b.addEventListener('click', () => {
      if (window.confirm('هل أنت متأكد من حل هذه الكتيبة وحذفها نهائياً؟')) {
        moderateGuildOrArena('delete_guild', b.dataset.deleteGuild, 'حل الكتيبة بقرار إداري');
      }
    }),
  );
}

async function loadGuildsAndArenas() {
  const client = getSupabase();
  if (!client) return;
  try {
    const { data, error } = await client.rpc('admin_list_guilds_and_arenas', { p_limit: 50 });
    if (error) throw error;
    const guilds = Array.isArray(data?.guilds) ? data.guilds : [];
    const arenas = Array.isArray(data?.live_sessions) ? data.live_sessions : [];
    document.getElementById('guilds-count-pill').textContent = guilds.length;
    document.getElementById('arenas-count-pill').textContent = arenas.length;
    renderGuilds(guilds);
    renderArenas(arenas);
  } catch (err) {
    showToast(`تعذر جلب الكتائب والساحات: ${err.message}`, true);
  }
}

export function mount(container) {
  if (mounted || !container) return;
  container.innerHTML = buildTemplate();
  mounted = true;
}

export async function load() {
  await Promise.all([loadDiwanQueue(), loadGuildsAndArenas()]);
}
