import 'package:flutter/material.dart';

void showAdminFeedback(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
        ),
        backgroundColor:
            isError ? const Color(0xFFB91C1C) : const Color(0xFF0F766E),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

String formatAdminDateTime(DateTime? dt) {
  if (dt == null) return 'غير محدد';
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}

Future<DateTime?> pickAdminDateTime(
  BuildContext context, {
  DateTime? initial,
}) async {
  final now = DateTime.now();
  final base = (initial ?? now.add(const Duration(hours: 24))).toLocal();
  final minBound = now.subtract(const Duration(days: 30));
  final firstDate = base.isBefore(minBound) ? base : minBound;
  final date = await showDatePicker(
    context: context,
    initialDate: base,
    firstDate: firstDate,
    lastDate: now.add(const Duration(days: 730)),
  );
  if (date == null || !context.mounted) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(base),
  );
  if (time == null) return DateTime(date.year, date.month, date.day, 23, 59);
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
