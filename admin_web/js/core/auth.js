import { SUPABASE_UNAVAILABLE_MSG } from './config.js';
import { adminState, getSupabase, requireSupabase } from './supabase_client.js';
import { setAuthWarning, showToast } from './ui_utils.js';

const authState = {
  dashboardHydrated: false,
  verifiedAccessToken: null,
  verifyPromise: null,
  onAuthenticated: null,
};

function resetAuthSession() {
  adminState.user = null;
  adminState.isAdmin = false;
  authState.dashboardHydrated = false;
  authState.verifiedAccessToken = null;
}

async function verifySessionAndLoad(session, eventName = '') {
  const authView = document.getElementById('auth-view');
  const dashView = document.getElementById('dashboard-view');
  const unauthorizedPanel = document.getElementById('unauthorized-panel');

  if (!session?.user) {
    resetAuthSession();
    dashView.classList.add('hidden');
    authView.classList.remove('hidden');
    return;
  }

  if (
    adminState.isAdmin &&
    adminState.user?.id === session.user.id &&
    authState.verifiedAccessToken === session.access_token
  ) {
    return;
  }

  if (authState.verifyPromise) {
    return authState.verifyPromise;
  }

  authState.verifyPromise = (async () => {
    const supabase = getSupabase();
    try {
      const sameAdminAlreadyOpen =
        adminState.isAdmin &&
        authState.dashboardHydrated &&
        adminState.user?.id === session.user.id &&
        eventName === 'TOKEN_REFRESHED';

      const { data, error } = await supabase.rpc('check_is_admin');
      if (error || data !== true) {
        await supabase.auth.signOut();
        resetAuthSession();
        dashView.classList.add('hidden');
        authView.classList.remove('hidden');
        unauthorizedPanel.classList.remove('hidden');
        document.getElementById('unauthorized-msg').textContent =
          `الحساب (${session.user.email ?? 'غير معروف'}) غير مسجل في قائمة المشرفين (app_admins). تم تسجيل الخروج فوراً.`;
        return;
      }

      setAuthWarning('');
      unauthorizedPanel.classList.add('hidden');
      adminState.user = session.user;
      adminState.isAdmin = true;
      authState.verifiedAccessToken = session.access_token;
      document.getElementById('admin-user-email').textContent = session.user.email ?? 'مشرف';
      authView.classList.add('hidden');
      dashView.classList.remove('hidden');

      if (!sameAdminAlreadyOpen) {
        await authState.onAuthenticated?.();
        authState.dashboardHydrated = true;
      }
    } catch (err) {
      setAuthWarning(`تعذر التحقق من صلاحيات الجلسة: ${err.message}`);
      showToast(`خطأ في التحقق من الصلاحيات: ${err.message}`, true);
    } finally {
      authState.verifyPromise = null;
    }
  })();

  return authState.verifyPromise;
}

async function loginWithGoogle() {
  const supabase = requireSupabase();
  if (!supabase) return;
  const redirectTo = `${window.location.origin}${window.location.pathname}`;
  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: { redirectTo },
  });
  if (error) showToast(`تعذر بدء تسجيل Google: ${error.message}`, true);
}

async function loginWithMagicLink(e) {
  e.preventDefault();
  const supabase = requireSupabase();
  if (!supabase) return;
  const email = document.getElementById('admin-email-input').value.trim();
  if (!email) return;

  const btn = document.getElementById('btn-magic-login');
  btn.disabled = true;
  try {
    const emailRedirectTo = `${window.location.origin}${window.location.pathname}`;
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: { emailRedirectTo },
    });
    if (error) throw error;
    document.getElementById('otp-verify-form').classList.remove('hidden');
    showToast(`تم إرسال رابط ورمز الدخول إلى ${email} ✅`);
  } catch (err) {
    showToast(`فشل إرسال رابط الدخول: ${err.message}`, true);
  } finally {
    btn.disabled = false;
  }
}

async function verifyOtpCode(e) {
  e.preventDefault();
  const supabase = requireSupabase();
  if (!supabase) return;
  const email = document.getElementById('admin-email-input').value.trim();
  const token = document.getElementById('admin-otp-input').value.trim();
  if (!email || !token) return;

  const btn = document.getElementById('btn-verify-otp');
  btn.disabled = true;
  try {
    const { data, error } = await supabase.auth.verifyOtp({
      email,
      token,
      type: 'email',
    });
    if (error) throw error;
    if (data?.session) {
      await verifySessionAndLoad(data.session);
    }
  } catch (err) {
    showToast(`رمز التحقق غير صحيح أو منتهي: ${err.message}`, true);
  } finally {
    btn.disabled = false;
  }
}

export async function logout() {
  const supabase = getSupabase();
  if (supabase) {
    await supabase.auth.signOut();
  }
  resetAuthSession();
  setAuthWarning('');
  document.getElementById('unauthorized-panel').classList.add('hidden');
  document.getElementById('dashboard-view').classList.add('hidden');
  document.getElementById('auth-view').classList.remove('hidden');
}

function checkUrlAuthError() {
  const searchParams = new URLSearchParams(window.location.search);
  const hashRaw = window.location.hash.startsWith('#') ? window.location.hash.slice(1) : '';
  const hashParams = new URLSearchParams(hashRaw);
  const errDesc =
    searchParams.get('error_description') ||
    hashParams.get('error_description') ||
    searchParams.get('error') ||
    hashParams.get('error');
  if (errDesc) {
    setAuthWarning(`تعذر إتمام تسجيل الدخول عبر OAuth: ${errDesc}`);
  }
}

export async function initAuth(onAuthenticated) {
  authState.onAuthenticated = onAuthenticated;

  document.getElementById('btn-google-login').addEventListener('click', loginWithGoogle);
  document.getElementById('magic-link-form').addEventListener('submit', loginWithMagicLink);
  document.getElementById('btn-toggle-otp-box').addEventListener('click', () => {
    document.getElementById('otp-verify-form').classList.toggle('hidden');
  });
  document.getElementById('otp-verify-form').addEventListener('submit', verifyOtpCode);

  checkUrlAuthError();
  const supabase = getSupabase();
  if (!supabase) {
    setAuthWarning(SUPABASE_UNAVAILABLE_MSG);
    return;
  }

  try {
    const { data } = await supabase.auth.getSession();
    await verifySessionAndLoad(data.session, 'INITIAL_SESSION');
    supabase.auth.onAuthStateChange((event, session) => {
      verifySessionAndLoad(session, event);
    });
  } catch (err) {
    setAuthWarning(`تعذر تهيئة الاتصال بـ Supabase: ${err?.message || err}`);
  }
}
