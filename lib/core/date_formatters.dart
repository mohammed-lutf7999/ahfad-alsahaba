/// Unified Arabic/short date, time, and countdown formatters across the app.
class DateFormatters {
  DateFormatters._();

  /// Formats `dd/MM/yyyy` (unpadded day/month as used in achievements).
  static String formatShortDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  /// Formats `HH:mm` in local time (e.g. `14:05`).
  static String formatHourMinute(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// Formats `dd/MM • HH:mm` in local time, or empty string when [dt] is null.
  static String formatDayMonthTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$d/$m • $hh:$mm';
  }

  /// Formats `yyyy-MM-dd HH:mm` in local time for admin audit logs and panels.
  static String formatAdminTimestamp(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    final y = local.year.toString();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  /// Formats countdown seconds as `MM:SS` (e.g. `01:30`).
  static String formatCountdown(int totalSeconds) {
    final safe = totalSeconds < 0 ? 0 : totalSeconds;
    final mins = (safe ~/ 60).toString().padLeft(2, '0');
    final secs = (safe % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}
