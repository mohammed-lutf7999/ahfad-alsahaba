import { refreshOverview } from '../core/app_bus.js';
import { ICON_EMOJI_MAP } from '../core/config.js';
import { broadcastWebControlPing } from '../core/rest_broadcast.js';
import { getSupabase } from '../core/supabase_client.js';
import {
  isValidHttpUrl,
  safeHexColor,
  showToast,
  toIsoOrNull,
  toLocalInputValue,
} from '../core/ui_utils.js';
import {
  buildEventsTemplate,
  renderEventPreviewHtml,
  renderEventsListHtml,
} from './tab_events_view.js';

const state = { mounted: false, events: [], editingEventId: null };

function syncTargetVisibility() {
  const actionType = document.getElementById('ev-action-type').value;
  document.getElementById('ev-target-wrap').classList.toggle('hidden', actionType === 'none');
}

function updatePreview() {
  document.getElementById('event-live-preview').innerHTML = renderEventPreviewHtml({
    badge: document.getElementById('ev-badge').value.trim() || 'حدث نشط',
    title: document.getElementById('ev-title').value.trim() || 'معاينة عنوان الحدث الديناميكي',
    subtitle: document.getElementById('ev-subtitle').value.trim() || 'يظهر هذا البانر في الشاشة الرئيسية للاعبين',
    cta: document.getElementById('ev-cta-label').value.trim() || 'اكتشف الآن',
    actionType: document.getElementById('ev-action-type').value,
    hex: safeHexColor(document.getElementById('ev-color').value),
    icon: ICON_EMOJI_MAP[document.getElementById('ev-icon').value] ?? '✨',
  });
}

function resetForm() {
  state.editingEventId = null;
  document.getElementById('event-form').reset();
  document.getElementById('ev-badge').value = 'موسم نشط الآن';
  document.getElementById('ev-priority').value = '100';
  document.getElementById('ev-cta-label').value = 'اكتشف الآن';
  document.getElementById('ev-color').value = '#D4AF37';
  document.getElementById('ev-color-picker').value = '#d4af37';
  document.getElementById('ev-is-active').checked = true;
  document.getElementById('event-form-heading').textContent = '🌟 إنشاء حدث ديناميكي جديد';
  document.getElementById('btn-save-event-text').textContent = 'نشر الحدث الآن';
  document.getElementById('btn-cancel-event-edit').classList.add('hidden');
  syncTargetVisibility();
  updatePreview();
}

function startEditing(id) {
  const ev = state.events.find((item) => item.id === id);
  if (!ev) return;
  state.editingEventId = ev.id;
  document.getElementById('event-form-heading').textContent = '✏️ تعديل الحدث المحدد';
  document.getElementById('btn-save-event-text').textContent = 'حفظ تعديلات الحدث';
  document.getElementById('btn-cancel-event-edit').classList.remove('hidden');
  document.getElementById('ev-badge').value = ev.badge_text ?? 'حدث نشط';
  document.getElementById('ev-priority').value = ev.priority ?? 100;
  document.getElementById('ev-title').value = ev.title ?? '';
  document.getElementById('ev-subtitle').value = ev.subtitle ?? '';
  document.getElementById('ev-body').value = ev.body ?? '';
  document.getElementById('ev-action-type').value = ev.action_type ?? 'open_event_screen';
  document.getElementById('ev-cta-label').value = ev.cta_label ?? 'اكتشف الآن';
  document.getElementById('ev-action-target').value = ev.action_target ?? '';
  const hex = safeHexColor(ev.theme_color_hex);
  document.getElementById('ev-color').value = hex;
  document.getElementById('ev-color-picker').value = hex.toLowerCase();
  document.getElementById('ev-icon').value = ev.icon_name ?? 'auto_awesome';
  document.getElementById('ev-starts-at').value = toLocalInputValue(ev.starts_at);
  document.getElementById('ev-ends-at').value = toLocalInputValue(ev.ends_at);
  document.getElementById('ev-is-active').checked = Boolean(ev.is_active);
  syncTargetVisibility();
  updatePreview();
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function renderList() {
  const container = document.getElementById('events-list');
  document.getElementById('ev-count-pill').textContent = state.events.length;
  container.innerHTML = renderEventsListHtml(state.events);

  container.querySelectorAll('input[data-toggle-event]').forEach((el) =>
    el.addEventListener('change', () => toggleEvent(el.dataset.toggleEvent, el.checked)),
  );
  container.querySelectorAll('button[data-edit-event]').forEach((btn) =>
    btn.addEventListener('click', () => startEditing(btn.dataset.editEvent)),
  );
  container.querySelectorAll('button[data-delete-event]').forEach((btn) =>
    btn.addEventListener('click', () => deleteEvent(btn.dataset.deleteEvent)),
  );
}

async function handleSave(e) {
  e.preventDefault();
  const supabase = getSupabase();
  if (!supabase) return;
  const title = document.getElementById('ev-title').value.trim();
  const actionType = document.getElementById('ev-action-type').value;
  const actionTarget = actionType === 'none' ? '' : document.getElementById('ev-action-target').value.trim();
  const rawHex = document.getElementById('ev-color').value.trim();
  const parsedPriority = Number.parseInt(document.getElementById('ev-priority').value, 10);
  const startsAt = toIsoOrNull(document.getElementById('ev-starts-at').value);
  const endsAt = toIsoOrNull(document.getElementById('ev-ends-at').value);

  if (!title) return showToast('عنوان الحدث مطلوب ولا يمكن أن يكون فارغاً.', true);
  if (!/^#[0-9a-fA-F]{6}$/.test(rawHex)) return showToast('أدخل كود لون Hex صحيح مكوناً من 6 خانات مثل #D4AF37.', true);
  if ((actionType === 'navigate_route' || actionType === 'open_url') && !actionTarget) {
    return showToast('أدخل المسار أو الرابط المستهدف لهذا الإجراء.', true);
  }
  if (actionType === 'open_url' && !isValidHttpUrl(actionTarget)) {
    return showToast('يجب أن يبدأ الرابط الخارجي بـ https:// أو http://', true);
  }
  if (startsAt && endsAt && new Date(endsAt).getTime() <= new Date(startsAt).getTime()) {
    return showToast('وقت انتهاء الحدث يجب أن يكون بعد وقت بدئه.', true);
  }

  const btn = document.getElementById('btn-save-event');
  btn.disabled = true;
  try {
    const { error } = await supabase.rpc('admin_upsert_dynamic_event', {
      p_id: state.editingEventId,
      p_badge_text: document.getElementById('ev-badge').value.trim() || 'حدث نشط',
      p_title: title,
      p_subtitle: document.getElementById('ev-subtitle').value.trim(),
      p_body: document.getElementById('ev-body').value.trim(),
      p_cta_label: document.getElementById('ev-cta-label').value.trim() || 'اكتشف الآن',
      p_action_type: actionType,
      p_action_target: actionTarget,
      p_theme_color_hex: safeHexColor(rawHex),
      p_icon_name: document.getElementById('ev-icon').value,
      p_priority: Number.isFinite(parsedPriority) ? parsedPriority : 100,
      p_is_active: document.getElementById('ev-is-active').checked,
      p_starts_at: startsAt,
      p_ends_at: endsAt,
    });
    if (error) throw error;
    const wasEditing = Boolean(state.editingEventId);
    resetForm();
    broadcastWebControlPing('ALL');
    showToast(wasEditing ? 'تم تحديث الحدث بنجاح ✅' : 'تم نشر الحدث الجديد 🎉');
    await Promise.all([load(), refreshOverview()]);
  } catch (err) {
    showToast(`فشل حفظ الحدث: ${err.message}`, true);
  } finally {
    btn.disabled = false;
  }
}

async function toggleEvent(id, nextActive) {
  const supabase = getSupabase();
  if (!supabase) return;
  const { error } = await supabase.rpc('admin_toggle_dynamic_event', { p_event_id: id, p_is_active: nextActive });
  if (error) {
    showToast(`تعذر تغيير حالة الحدث: ${error.message}`, true);
    await load();
    return;
  }
  broadcastWebControlPing('ALL');
  showToast(nextActive ? 'تم تفعيل الحدث ✅' : 'تم إيقاف الحدث ⏸️');
  await Promise.all([load(), refreshOverview()]);
}

async function deleteEvent(id) {
  const supabase = getSupabase();
  const ev = state.events.find((item) => item.id === id);
  if (!supabase || !window.confirm(`حذف الحدث «${ev?.title ?? ''}» نهائياً؟`)) return;
  const { data, error } = await supabase.rpc('admin_delete_dynamic_event', { p_event_id: id });
  if (error || data !== true) {
    showToast(`تعذر حذف الحدث: ${error?.message ?? ''}`, true);
    return;
  }
  if (state.editingEventId === id) resetForm();
  broadcastWebControlPing('ALL');
  showToast('تم حذف الحدث بنجاح 🗑️');
  await Promise.all([load(), refreshOverview()]);
}

export function mount(container) {
  if (state.mounted || !container) return;
  container.innerHTML = buildEventsTemplate();
  state.mounted = true;

  document.getElementById('event-form').addEventListener('submit', handleSave);
  document.getElementById('btn-cancel-event-edit').addEventListener('click', resetForm);
  document.getElementById('ev-color-picker').addEventListener('input', (e) => {
    document.getElementById('ev-color').value = e.target.value.toUpperCase();
    updatePreview();
  });
  document.getElementById('ev-color').addEventListener('input', (e) => {
    const valid = safeHexColor(e.target.value, '');
    if (valid) document.getElementById('ev-color-picker').value = valid.toLowerCase();
    updatePreview();
  });
  ['ev-badge', 'ev-title', 'ev-subtitle', 'ev-cta-label', 'ev-action-type', 'ev-icon'].forEach((id) => {
    const el = document.getElementById(id);
    el.addEventListener('input', updatePreview);
    el.addEventListener('change', updatePreview);
  });
  document.getElementById('ev-action-type').addEventListener('change', syncTargetVisibility);
  syncTargetVisibility();
  updatePreview();
}

export async function load() {
  const supabase = getSupabase();
  if (!supabase) return;
  const { data, error } = await supabase.rpc('admin_list_dynamic_events');
  if (error) {
    showToast(`تعذر تحميل الأحداث: ${error.message}`, true);
    return;
  }
  state.events = Array.isArray(data) ? data : [];
  renderList();
}
