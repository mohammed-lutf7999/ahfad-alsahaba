export function escapeHtml(raw) {
  return String(raw ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

export function safeHexColor(rawHex, fallback = '#D4AF37') {
  const cleaned = String(rawHex ?? '').trim();
  return /^#[0-9a-fA-F]{6}$/.test(cleaned) ? cleaned : fallback;
}

export function isValidPlayerCode(code) {
  return /^SAH-[A-Z0-9]{4,8}$/.test(String(code ?? '').trim().toUpperCase());
}

export function isValidHttpUrl(rawUrl) {
  const cleaned = String(rawUrl ?? '').trim();
  const lower = cleaned.toLowerCase();
  if (!lower.startsWith('https://') && !lower.startsWith('http://')) {
    return false;
  }
  try {
    const parsed = new URL(cleaned);
    return Boolean(parsed.hostname);
  } catch {
    return false;
  }
}

export function setAuthWarning(message) {
  const el = document.getElementById('auth-warning');
  if (!el) return;
  if (!message) {
    el.textContent = '';
    el.classList.add('hidden');
    return;
  }
  el.textContent = message;
  el.classList.remove('hidden');
}

export function toIsoOrNull(localDateTimeValue) {
  const trimmed = String(localDateTimeValue ?? '').trim();
  if (!trimmed) return null;
  const parsed = new Date(trimmed);
  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
}

export function toLocalInputValue(isoString) {
  if (!isoString) return '';
  const d = new Date(isoString);
  if (Number.isNaN(d.getTime())) return '';
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export function formatDateDisplay(isoString) {
  if (!isoString) return 'غير محدد';
  const d = new Date(isoString);
  if (Number.isNaN(d.getTime())) return 'غير محدد';
  return d.toLocaleString('ar-EG', { dateStyle: 'medium', timeStyle: 'short' });
}

export function showToast(message, isError = false) {
  const container = document.getElementById('toast-container');
  if (!container) return;
  const el = document.createElement('div');
  el.className = `toast ${isError ? 'error' : ''}`;
  el.textContent = message;
  container.appendChild(el);
  window.setTimeout(() => el.remove(), 4200);
}

export function safeCsvCell(raw) {
  let s = String(raw ?? '').replaceAll('\r', ' ').replaceAll('\n', ' ');
  if (/^\s*[=+\-@\t]/.test(s)) {
    s = `'${s}`;
  }
  return `"${s.replaceAll('"', '""')}"`;
}
