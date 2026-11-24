// Public project URL and publishable anon key only (from lib/core/supabase_config.dart).
// NEVER place any service_role key or management token in client/web code.
export const SUPABASE_URL = 'https://khatzzpqxaiwuoodgcst.supabase.co';
export const SUPABASE_ANON_KEY = 'sb_publishable_Zp9URQMtw71oyhZztDGsmg_hT9FfyIv';
export const QUESTION_PACKS_BUCKET = 'question-packs';
export const BULK_CHUNK_SIZE = 200;

export const SUPABASE_UNAVAILABLE_MSG =
  'تعذر تحميل مكتبة الاتصال السحابي (Supabase SDK). تأكد من اتصال الإنترنت ثم أعد تحميل الصفحة (Ctrl+F5).';

export const ICON_EMOJI_MAP = Object.freeze({
  auto_awesome: '✨',
  mosque: '🕌',
  stars: '🌟',
  celebration: '🎉',
  military_tech: '🎖️',
  emoji_events: '🏆',
  campaign: '📣',
  bolt: '⚡',
  castle: '🏰',
  menu_book: '📖',
  shield: '🛡️',
});
