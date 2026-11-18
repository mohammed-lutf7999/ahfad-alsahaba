/// Local ethics & profanity guard matching the server-side filter in `018_diwan_live_chat.sql`.
class ProfanityFilter {
  ProfanityFilter._();

  static const List<String> _blockedRoots = [
    'كلب',
    'حمار',
    'غبي',
    'تافه',
    'حقير',
    'لعنة',
    'يلعن',
    'شرموط',
    'قحبة',
    'ابن الكلب',
    'منيك',
    'خنزير',
    'سافل',
    'منحط',
    'fuck',
    'shit',
    'bitch',
    'asshole',
    'bastard',
    'slut',
    'whore',
    'dick',
    'pussy',
  ];

  static final RegExp _linkRegex = RegExp(
    r'(https?://|www\.|t\.me/|discord\.gg)',
    caseSensitive: false,
  );

  static final RegExp _diacriticsAndSepRegex = RegExp(
    r'[ـ\u064B-\u065F\s._*|-]+',
  );

  /// Returns `true` if [input] contains banned profanity or external spam links.
  static bool containsInappropriateContent(String input) {
    final norm = input.trim().toLowerCase();
    if (norm.isEmpty) return false;
    if (_linkRegex.hasMatch(norm)) return true;

    final compact = norm.replaceAll(_diacriticsAndSepRegex, '');
    for (final root in _blockedRoots) {
      final cleanRoot = root.replaceAll(' ', '');
      if (norm.contains(root) || compact.contains(cleanRoot)) {
        return true;
      }
    }
    return false;
  }

  /// Validates a chat message before sending and returns an Arabic notice if invalid, or `null` if valid.
  static String? validateMessage(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return 'اكتب رسالة قصيرة أولاً';
    }
    if (trimmed.length > 250) {
      return 'الحد الأقصى للرسالة هو 250 حرفاً';
    }
    if (containsInappropriateContent(trimmed)) {
      return 'يرجى الالتزام بالآداب الإسلامية وتجنب الألفاظ أو الروابط المخالفة';
    }
    return null;
  }
}
