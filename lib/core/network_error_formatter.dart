/// أداة مركزية لصياغة وترجمة أخطاء الشبكة والاتصال إلى رسائل عربية واضحة للمستخدم
class NetworkErrorFormatter {
  /// تحويل رسالة الخطأ الخام إلى رسالة مفهومة ومهذبة
  static String format(dynamic rawError) {
    if (rawError == null) return 'حدث خطأ غير معروف في الاتصال';
    final str = rawError.toString();

    if (str.contains('SocketException') ||
        str.contains('Failed host lookup') ||
        str.contains('errno = 7') ||
        str.contains('ClientException') ||
        str.contains('Network is unreachable') ||
        str.contains('Connection refused')) {
      return 'تعذر الاتصال بالخادم. يرجى التحقق من اتصالك بالإنترنت والمحاولة مجدداً.';
    }

    if (str.contains('timedOut') ||
        str.contains('Timeout') ||
        str.contains('TimeoutException') ||
        str.contains('RealtimeSubscribeException')) {
      return 'انتهت مهلة البحث. لم يتم العثور على منافس متاح حالياً.';
    }

    if (str.contains('User not logged in') || str.contains('AuthException')) {
      return 'يرجى تسجيل الدخول أولاً لتتمكن من المنافسة عبر الإنترنت.';
    }

    if (str.contains('42702') || str.contains('ambiguous')) {
      return 'حدث تعارض في استجابة الخادم، يرجى إعادة المحاولة.';
    }

    return 'حدث خطأ في الاتصال: $str';
  }

  /// هل الخطأ يتعلق بانقطاع الإنترنت الفعلي
  static bool isOfflineError(dynamic rawError) {
    if (rawError == null) return false;
    final str = rawError.toString();
    return str.contains('SocketException') ||
        str.contains('Failed host lookup') ||
        str.contains('errno = 7') ||
        str.contains('Network is unreachable');
  }
}
